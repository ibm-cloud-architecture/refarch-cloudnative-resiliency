#!/bin/bash

. ./env.sh

if [ ! -d "./refarch-cloudnative-mysql" ]; then
    git clone https://github.com/ibm-cloud-architecture/refarch-cloudnative-mysql.git
fi

cd refarch-cloudnative-mysql; docker build -t cloudnative/mysql .; cd ..

${DOCKER_CMD} stop ${MASTER_CONTAINER_NAME}
${DOCKER_CMD} rm ${MASTER_CONTAINER_NAME}

docker volume rm $(docker volume ls -qf dangling=true)

master_passwd=`cat /dev/urandom | tr -dc 'A-Za-z0-9' | head -c16`

# start master
${DOCKER_CMD} run -p 3306:3306 --name ${MASTER_CONTAINER_NAME} -e MYSQL_ROOT_PASSWORD=${master_passwd} -e MYSQL_DATABASE=inventorydb -e MYSQL_USER=dbuser -e MYSQL_PASSWORD=password -e SERVER_ID=${MASTER_SERVER_ID}  -w /root/scripts -d cloudnative/mysql

${DOCKER_CMD} ps

# load the database
_rc=1
while [ ${_rc} -ne 0 ]; do
    ${DOCKER_CMD} exec ${MASTER_CONTAINER_NAME} /root/scripts/load-data.sh
    _rc=$?
done

master_port=`${DOCKER_CMD} inspect -f '{{with index .NetworkSettings.Ports "3306/tcp" 0}} {{.HostPort}} {{end}}' ${MASTER_CONTAINER_NAME} | awk '{print $1;}'`
master_ip=`hostname -i`

echo "export MASTER_IP=${master_ip}"
echo "export MASTER_PORT=${master_port}"
echo "export MASTER_PASSWORD=${master_passwd}"

export MASTER_IP=${master_ip}
export MASTER_PORT=${master_port}
export MASTER_PASSWORD=${master_passwd}
