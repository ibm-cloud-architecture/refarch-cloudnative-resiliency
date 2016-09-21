#!/bin/bash

DOCKER_CMD="docker"
SITE_MASK=0
SITE="dal09"
MASTER_CONTAINER_NAME=mysql-master-${SITE}
SLAVE_CONTAINER_NAME=mysql-slave-${SITE}

MASTER_SERVER_ID=$((1 << $SITE_MASK))
SLAVE_SERVER_ID=$(((1 << $SITE_MASK) + 1))

docker build -t cloudnative/mysql .

${DOCKER_CMD} stop ${SLAVE_CONTAINER_NAME} ${MASTER_CONTAINER_NAME}
${DOCKER_CMD} rm ${SLAVE_CONTAINER_NAME} ${MASTER_CONTAINER_NAME}

docker volume rm $(docker volume ls -qf dangling=true)

master_passwd=`cat /dev/urandom | tr -dc 'A-Za-z0-9' | head -c16`
slave_passwd=`cat /dev/urandom | tr -dc 'A-Za-z0-9' | head -c16`
repl_passwd=`cat /dev/urandom | tr -dc 'A-Za-z0-9' | head -c16`

# start master
${DOCKER_CMD} run --name ${MASTER_CONTAINER_NAME} -e MYSQL_ROOT_PASSWORD=${master_passwd} -e MYSQL_DATABASE=inventorydb -e MYSQL_USER=dbuser -e MYSQL_PASSWORD=password -e SERVER_ID=${MASTER_SERVER_ID}  -w /root/scripts -d cloudnative/mysql

# start a slave replica
${DOCKER_CMD} run --name ${SLAVE_CONTAINER_NAME}  -e MYSQL_ROOT_PASSWORD=${slave_passwd} -e MYSQL_DATABASE=inventorydb -e SERVER_ID=${SLAVE_SERVER_ID} -w /root/scripts -d cloudnative/mysql

${DOCKER_CMD} ps

sleep 20
# load the database
${DOCKER_CMD} exec ${MASTER_CONTAINER_NAME} /root/scripts/load-data.sh

master_ip=`${DOCKER_CMD} inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' ${MASTER_CONTAINER_NAME}`
slave_ip=`${DOCKER_CMD} inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' ${SLAVE_CONTAINER_NAME}`


echo "export MASTER_IP=${master_ip}"
echo "export MASTER_PASSWORD=${master_passwd}"
echo "export SLAVE_IP=${slave_ip}"
echo "export SLAVE_PASSWORD=${slave_passwd}"
echo "export REPL_PASSWORD=${repl_passwd}"


echo ${master_passwd} | ${DOCKER_CMD} exec -i ${SLAVE_CONTAINER_NAME} mysql_config_editor set --login-path=master --host=${master_ip} --port=3306 --user=root --password

${DOCKER_CMD} exec -it ${SLAVE_CONTAINER_NAME} mysqlserverinfo --server=master --format=vertical

echo ${slave_passwd} | ${DOCKER_CMD} exec -i ${SLAVE_CONTAINER_NAME} mysql_config_editor set --login-path=slave --host=${slave_ip} --port=3306 --user=root --password

echo ${repl_passwd} | ${DOCKER_CMD} exec -i ${SLAVE_CONTAINER_NAME} mysql_config_editor set --login-path=repl-${SITE} --user=repl-${SITE} --password


${DOCKER_CMD} exec -it ${SLAVE_CONTAINER_NAME} mysqlserverinfo --server=slave --format=vertical

_rc=1
while [ ${_rc} -ne 0 ]; do
    ${DOCKER_CMD} exec -it ${SLAVE_CONTAINER_NAME} mysqlreplicate --master=master --slave=slave --rpl-user=repl-${SITE}
    _rc=$?
    sleep 5
done

${DOCKER_CMD} exec -it ${SLAVE_CONTAINER_NAME}  mysqlrpladmin --master=master --slaves=slave health
