#!/bin/bash

DOCKER_CMD="docker"

for param in $@; do

   case $param in
      --container-name=*)
          CONTAINER_NAME=`echo ${param}  | cut -d= -f2`
          ;;
      --login-path=*)
          login_path=`echo ${param}  | cut -d= -f2`
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

if [ -z "${login_path}" ]; then
    echo "--login-path is not set"
    return 1
fi


${DOCKER_CMD} exec -it ${CONTAINER_NAME} mysqlserverinfo --server=${login_path} --format=vertical 

if [ $? -ne 0 ]; then
    exit 1
fi

