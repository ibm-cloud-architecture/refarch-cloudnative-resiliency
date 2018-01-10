#!/bin/bash

. ./env.sh

if [ -z "${MASTER_IP}" ]; then
    echo "MASTER_IP is not set"
    return 1
fi

if [ -z "${MASTER_PORT}" ]; then
    echo "MASTER_PORT is not set"
    return 1
fi

if [ -z "${MASTER_PASSWORD}" ]; then
    echo "MASTER_PASSWORD is not set"
    return 1
fi


if [ ! -d "./refarch-cloudnative-mysql" ]; then
    git clone https://github.com/ibm-cloud-architecture/refarch-cloudnative-mysql.git
fi

cd refarch-cloudnative-mysql; docker build -t cloudnative/mysql .; cd ..

${DOCKER_CMD} stop ${SLAVE_CONTAINER_NAME}
${DOCKER_CMD} rm ${SLAVE_CONTAINER_NAME}

docker volume rm $(docker volume ls -qf dangling=true)

slave_passwd=`cat /dev/urandom | tr -dc 'A-Za-z0-9' | head -c16`
repl_passwd=`cat /dev/urandom | tr -dc 'A-Za-z0-9' | head -c16`

# start a slave replica
${DOCKER_CMD} run -p 3306:3306 --name ${SLAVE_CONTAINER_NAME}  -e MYSQL_ROOT_PASSWORD=${slave_passwd} -e MYSQL_DATABASE=inventorydb -e SERVER_ID=${SLAVE_SERVER_ID} -w /root/scripts -d cloudnative/mysql

${DOCKER_CMD} ps

slave_port=`${DOCKER_CMD} inspect -f '{{with index .NetworkSettings.Ports "3306/tcp" 0}} {{.HostPort}} {{end}}' ${SLAVE_CONTAINER_NAME} | awk '{print $1;}'`
slave_ip=`hostname -i`

echo "export SLAVE_IP=${slave_ip}"
echo "export SLAVE_PORT=${slave_port}"
echo "export SLAVE_PASSWORD=${slave_passwd}"
echo "export REPL_PASSWORD=${repl_passwd}"

export SLAVE_IP=${slave_ip}
export SLAVE_PORT=${slave_port}
export SLAVE_PASSWORD=${slave_passwd}
export REPL_PASSWORD=${repl_passwd}

set -x

master_login_path=`./add_login.sh --host=${MASTER_IP} --password=${MASTER_PASSWORD} --container-name=${SLAVE_CONTAINER_NAME} --port=${MASTER_PORT}`

slave_login_path=`./add_login.sh --password=${slave_passwd} --container-name=${SLAVE_CONTAINER_NAME} --host=${slave_ip} --port=${slave_port}`

#repl_login_path=`./add_login.sh --password=${repl_passwd} --container-name=${SLAVE_CONTAINER_NAME} --user=slave-${SITE}`

./test_login.sh --container-name=${SLAVE_CONTAINER_NAME} --login-path=${master_login_path}
./test_login.sh --container-name=${SLAVE_CONTAINER_NAME} --login-path=${slave_login_path}
./test_login.sh --container-name=${SLAVE_CONTAINER_NAME} --login-path=${repl_login_path}

./start_replicate.sh --container-name=${SLAVE_CONTAINER_NAME} --master-login-path=${master_login_path} --slave-login-path=${slave_login_path} --repl-user=slave-${SITE} --repl-password=${repl_passwd}

${DOCKER_CMD} exec -it ${SLAVE_CONTAINER_NAME}  mysqlrpladmin --master=${master_login_path} --slaves=${slave_login_path}  health
