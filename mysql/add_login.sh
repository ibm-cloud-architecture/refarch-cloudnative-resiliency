#!/bin/bash


DOCKER_CMD="docker"

for param in $@; do

   case $param in
      --container-name=*)
          CONTAINER_NAME=`echo ${param}  | cut -d= -f2`
          ;;
      --password=*)
          PASSWORD=`echo ${param}  | cut -d= -f2`
          ;;
      --port=*)
          PORT=`echo ${param}  | cut -d= -f2`
          ;;

      --host=*)
          HOST=`echo ${param}  | cut -d= -f2`
          ;;
      --user=*)
          USERNAME=`echo ${param}  | cut -d= -f2`
          ;;

      *)
          echo "Ignored param: $param"
          ;;
   esac
done

if [ -z "${CONTAINER_NAME}" ]; then
    echo "--container-name is not set"
    return 1
fi

if [ -z "${PASSWORD}" ]; then
    echo "--password is not set"
    return 1
fi

if [ -z "${USERNAME}" ]; then
    USERNAME=root
fi

if [ -z "${PORT}" ]; then
    PORT=3306
fi

if [ ! -z "${HOST}" ]; then
    login_path=${USERNAME}_`echo ${HOST} | sed -e 's/\./-/g'`_${PORT}
    host_port="--host=${HOST} --port=${PORT}"
else
    login_path=${USERNAME}
fi

${DOCKER_CMD} exec -i ${CONTAINER_NAME} mysql_config_editor remove --login-path=${login_path} 
echo ${PASSWORD} | ${DOCKER_CMD} exec -i ${CONTAINER_NAME} mysql_config_editor set --login-path=${login_path} ${host_port} --user=${USERNAME} --password

echo "${login_path}"



