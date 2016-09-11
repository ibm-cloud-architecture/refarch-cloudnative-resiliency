#!/bin/bash


# some configuration

SLAVE_HOSTNAME=$1
SLAVE_IP_ADDR=$2
SLAVE_DB_USER=${REPL_USER}
SLAVE_DB_PASSWORD=${REPL_PASSWD}

# add to /etc/hosts
echo "${SLAVE_IP_ADDR} ${SLAVE_HOSTNAME}" >> /etc/hosts

# grant replication privileges to the host
mysql -uroot -p${MYSQL_ROOT_PASSWORD} -e "CREATE USER '${REPL_USER}'@'${SLAVE_IP_ADDR}' IDENTIFIED BY '${REPL_PASSWD}';"
mysql -uroot -p${MYSQL_ROOT_PASSWORD} -e "GRANT REPLICATION SLAVE ON *.* TO '${REPL_USER}'@'${SLAVE_IP_ADDR}';"

