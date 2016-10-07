#!/bin/bash

. ./env.sh

NODE_TYPE=$1
NODE_IDX=$2
VOL_MOUNT=$3

function print_usage {
    echo "$0 <mgmt|sql|data> <idx> [<mountpoint>]"
    echo
    echo "configured cluster size:"
    echo "Mgmt nodes: ${num_mgmt_nodes}"
    echo "Sql nodes: ${num_sql_nodes}"
    echo "Data nodes: ${num_data_nodes}"
}

function get_ip4 {
    _subnet=$1
    _offset=$2

    _network=`echo ${_subnet} | cut -d/ -f1`
    IFS=. read -r _octet1 _octet2 _octet3 _octet4 <<< "${_network}"

    _cidr=`echo ${_subnet} | cut -d/ -f2`
    _long_network=`printf '%d\n' "$((_octet1 * 256 ** 3 + _octet2 * 256 ** 2 + _octet3 * 256 + _octet4))"`

    for i in `seq 1 ${_cidr}`; do
        _str="${_str}1"
    done
    
    for i in `seq ${_cidr} 32`; do
        _str="${_str}0"
    done
    
    _mask=$((2#${_str}))
    
    _long_ip=$(((${_long_network} & ${_mask}) + ${_offset}))
    
    for i in {3..0}; do
        ((octet = ${_long_ip} / (256 ** i) ))
        ((_long_ip -= octet * 256 ** i ))
        ip=${ip}${delim}${octet}
        delim=.
    done
    
    
    echo ${ip}
}


if [ -z "${NODE_TYPE}" ]; then
    echo "NODE_TYPE not set"
    print_usage
    exit 1
fi

if [ -z "${NODE_IDX}" ]; then
    echo "NODE_IDX not set"
    print_usage
    exit 1
fi

if [ "${NODE_TYPE}" != "mgmt" -a \
     "${NODE_TYPE}" != "sql" -a \
     "${NODE_TYPE}" != "data" ]; then
    echo "Invalid NODE_TYPE set: ${NODE_TYPE}"
    print_usage
    exit 1
fi

# get dependency scripts from mysql repo
if [ ! -d "./refarch-cloudnative-mysql" ]; then
    git clone https://github.com/ibm-cloud-architecture/refarch-cloudnative-mysql.git
fi

# build network
docker network inspect mynet
_rc=$?
if [ ${_rc} -ne 0 ]; then
    docker network create -d overlay --subnet=${MY_SUBNET} mynet
fi

# build docker image
docker build -t mysql-cluster .

# the IPs will be set up like this, mgmtnode is mynet+2, 
# sqlnode is mynet+3,mynet+4,
# and datanodes are mynet+5 and mynet+6 and mynet+7

_ip_idx=2
MGMT_NODE_IP=`get_ip4 ${MY_SUBNET} $((_ip_idx))`
SQL_NODE_IPS=""
DATA_NODE_IPS=""
_ip_idx=$((_ip_idx+1))

for i in `seq 1 ${num_sql_nodes}`; do
    SQL_NODE_IPS="${SQL_NODE_IPS};`get_ip4 ${MY_SUBNET} ${_ip_idx}`"
    _ip_idx=$((_ip_idx+1))
done

for i in `seq 1 ${num_data_nodes}`; do
    DATA_NODE_IPS="${DATA_NODE_IPS};`get_ip4 ${MY_SUBNET} ${_ip_idx}`"
    _ip_idx=$((_ip_idx+1))
done

# write out config.ini
cat > config.ini <<ENDCONFIGINI
[ndbd default]
NoOfReplicas=${num_data_nodes}
DataMemory=80M
IndexMemory=18M

[ndb_mgmd]
hostname=${MGMT_NODE_IP}
datadir=/var/lib/mysql

ENDCONFIGINI

for SQL_NODE_IP  in `echo ${SQL_NODE_IPS} | sed -e 's/;/ /g'`; do
    echo "[mysqld]" >> config.ini
    echo "hostname=${SQL_NODE_IP}" >> config.ini
    echo "" >> config.ini
done

for DATA_NODE_IP in `echo ${DATA_NODE_IPS} | sed -e 's/;/ /g'`; do
    echo "[ndbd]" >> config.ini
    echo "hostname=${DATA_NODE_IP}" >> config.ini
    echo "datadir=/var/lib/mysql/data" >> config.ini
    echo "" >> config.ini
done

cat > my.cnf <<ENDMYCNF
[client]
port=3306
socket=/var/lib/mysql/mysql.sock

[mysqld]
port=3306
datadir=/var/lib/mysql
socket=/var/lib/mysql/mysql.sock
user=mysql
# Disabling symbolic-links is recommended to prevent assorted security risks
symbolic-links=0
ndbcluster=1

log-bin=mysql-bin
binlog-format=row
server-id=${NODE_IDX}${SITE_MASK}
auto-increment-increment = 2
auto-increment-offset = $((SITE_MASK+1))
replicate-same-server-id = 0

[mysql_cluster]
ndb-connectstring=${MGMT_NODE_IP}

[mysqld_safe]
log-error=/var/log/mysqld.log
pid-file=/var/run/mysqld/mysqld.pid
ENDMYCNF

vol_mount_param=""
if [ ! -z "${VOL_MOUNT}" ]; then
    vol_mount_param="-v ${VOL_MOUNT}:/var/lib/mysql"
fi

if [ ! -z "${NEW_RELIC_LICENSE_KEY}" ]; then
    new_relic_license_key_param="-e NEW_RELIC_LICENSE_KEY=${NEW_RELIC_LICENSE_KEY}"
fi

if [ "${NODE_TYPE}" == "mgmt" ]; then
    # stop and delete any mgmt nodes
    docker stop mysql-${SITE_NAME}-mgmtnode${NODE_IDX}
    docker rm mysql-${SITE_NAME}-mgmtnode${NODE_IDX}

    # start mgmt node
    docker run -d --hostname mysql-${SITE_NAME}-mgmtnode${NODE_IDX} --net mynet --ip ${MGMT_NODE_IP} ${vol_mount_param} -v `pwd`/config.ini:/etc/mysql-cluster.ini --name mysql-${SITE_NAME}-mgmtnode${NODE_IDX} mysql-cluster ndb_mgmd
    
elif [ "${NODE_TYPE}" == "sql" ]; then
    # stop and delete any sql nodes
    _count=1
    for SQL_NODE_IP  in `echo ${SQL_NODE_IPS} | sed -e 's/;/ /g'`; do
        if [ ! -z "${NODE_IDX}" -a \
             "${NODE_IDX}" == "${_count}" ]; then
            docker stop mysql-${SITE_NAME}-sqlnode${_count}
            docker rm mysql-${SITE_NAME}-sqlnode${_count}

            node_ip=`hostname -i`
            docker run -d --hostname mysql-${SITE_NAME}-sqlnode${_count} --net mynet -p ${node_ip}:3306:3306 ${new_relic_license_key_param} --ip ${SQL_NODE_IP} ${vol_mount_param} -v `pwd`/my.cnf:/etc/my.cnf --name mysql-${SITE_NAME}-sqlnode${_count} mysql-cluster mysqld

        fi
        _count=$((_count+1))
    done
elif [ "${NODE_TYPE}" == "data" ]; then
    # stop and delete any data nodes
    _count=1
    for DATA_NODE_IP  in `echo ${DATA_NODE_IPS} | sed -e 's/;/ /g'`; do
        if [ ! -z "${NODE_IDX}" -a \
             "${NODE_IDX}" == "${_count}" ]; then

            docker stop mysql-${SITE_NAME}-datanode${_count}
            docker rm mysql-${SITE_NAME}-datanode${_count}

            docker run -d --hostname mysql-${SITE_NAME}-datanode${_count} --net mynet --ip ${DATA_NODE_IP} ${vol_mount_param} -v `pwd`/my.cnf:/etc/my.cnf --name mysql-${SITE_NAME}-datanode${_count} mysql-cluster ndbd
        fi
        _count=$((_count+1))
    done
fi


