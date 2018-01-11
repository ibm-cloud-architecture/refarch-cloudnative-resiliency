#!/bin/bash

DOCKER_CMD="docker"

for param in $@; do

   case $param in
      --master-host=*)
          master_host=`echo ${param}  | cut -d= -f2`
          ;;
      --master-port=*)
          master_port=`echo ${param}  | cut -d= -f2`
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

if [ -z "${master_host}" ]; then
    echo "Missing param: --master-host=<host>"
    exit 1
fi

if [ -z "${master_port}" ]; then
    echo "Assuming master port on 3306"
    master_port=3306
fi

if [ ! -z "${repl_user}" -a ! -z "${repl_password}" ]; then
    _rc=1
    mysql  -e "STOP SLAVE;"
    mysql  -e "RESET SLAVE ALL;"

    while [ ${_rc} -ne 0 ]; do
        mysql -e "CHANGE MASTER TO MASTER_HOST='${master_host}', MASTER_USER='${repl_user}', MASTER_PASSWORD='${repl_password}', MASTER_PORT=${master_port};"
        _rc=$?
        sleep 5
    done

    mysql  -e "START SLAVE;"
    mysql  -e "SHOW SLAVE STATUS;"

    exit 0
fi


#_rc=1
#while [ ${_rc} -ne 0 ]; do
#    ${DOCKER_CMD} exec -it ${CONTAINER_NAME} mysqlreplicate -vv --master=${master_login_path} --master=${master_login_path} --rpl-user=${repl_login_path}
#    _rc=$?
#    sleep 5
#done
##${DOCKER_CMD} exec -it ${CONTAINER_NAME} mysqlreplicate -vv --master=${master_login_path} --master=${master_login_path} --rpl-user=${repl_login_path}
