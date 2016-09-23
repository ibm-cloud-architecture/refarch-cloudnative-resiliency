#!/bin/bash

DOCKER_CMD="docker"

for param in $@; do

   case $param in
      --container-name=*)
          CONTAINER_NAME=`echo ${param}  | cut -d= -f2`
          ;;
      --master-login-path=*)
          master_login_path=`echo ${param}  | cut -d= -f2`
          ;;
      --slave-login-path=*)
          slave_login_path=`echo ${param}  | cut -d= -f2`
          ;;
      --repl-login-path=*)
          repl_login_path=`echo ${param}  | cut -d= -f2`
          ;;
      --repl-user=*)
          repl_user=`echo ${param}  | cut -d= -f2`
          ;;
      --repl-password=*)
          repl_password=`echo ${param}  | cut -d= -f2`
          ;;

      *)
          echo "Ignored param: $param"
          ;;
   esac
done

if [ -z "${CONTAINER_NAME}" ]; then
    echo "--container-name is not set"
    exit 1
fi
if [ -z "${master_login_path}" ]; then
    echo "--master-login-path is not set"
    exit 1
fi
if [ -z "${slave_login_path}" ]; then
    echo "--slave-login-path is not set"
    exit 1
fi

if [ ! -z "${repl_user}" -a ! -z "${repl_password}" ]; then

    set -x

    ${DOCKER_CMD} exec -it ${CONTAINER_NAME} mysql --login-path=${master_login_path} -e "DROP USER '${repl_user}'@'%';"
    ${DOCKER_CMD} exec -it ${CONTAINER_NAME} mysql --login-path=${master_login_path} -e "CREATE USER '${repl_user}'@'%' IDENTIFIED BY '${repl_password}';"
    ${DOCKER_CMD} exec -it ${CONTAINER_NAME} mysql --login-path=${master_login_path} -e "GRANT REPLICATION SLAVE ON *.* TO '${repl_user}'@'%';"


master_host=`${DOCKER_CMD} exec -it ${CONTAINER_NAME} mysql_config_editor print --login-path=${master_login_path} | grep 'host = '  | sed -e 's/\s//g'| cut -d= -f2`
master_port=`${DOCKER_CMD} exec -it ${CONTAINER_NAME} mysql_config_editor print --login-path=${master_login_path} | grep 'port = '  | sed -e 's/\s//g'| cut -d= -f2`

    _rc=1
    while [ ${_rc} -ne 0 ]; do
        ${DOCKER_CMD} exec -it ${CONTAINER_NAME} mysql --login-path=${slave_login_path} -e "CHANGE MASTER TO MASTER_HOST='${master_host}', MASTER_USER='${repl_user}', MASTER_PASSWORD='${repl_password}', MASTER_PORT=${master_port};"
        _rc=$?
        sleep 5
    done

    ${DOCKER_CMD} exec -it ${CONTAINER_NAME} mysql --login-path=${slave_login_path} -e "START SLAVE;"

    exit 0
fi


#_rc=1
#while [ ${_rc} -ne 0 ]; do
#    ${DOCKER_CMD} exec -it ${CONTAINER_NAME} mysqlreplicate -vv --master=${master_login_path} --slave=${slave_login_path} --rpl-user=${repl_login_path}
#    _rc=$?
#    sleep 5
#done
##${DOCKER_CMD} exec -it ${CONTAINER_NAME} mysqlreplicate -vv --master=${master_login_path} --slave=${slave_login_path} --rpl-user=${repl_login_path}
