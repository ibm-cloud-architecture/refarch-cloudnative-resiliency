#!/bin/bash

for param in $@; do
   case $param in
      --password=*)
          PASSWORD=`echo ${param}  | cut -d= -f2`
          ;;
      --remote-host=*)
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

if [ -z "${USERNAME}" ]; then
    USERNAME=repl
    echo "--user is not set; using \"${USERNAME}\""
fi

if [ -z "${PASSWORD}" ]; then
    PASSWORD=`cat /dev/urandom | env LC_CTYPE=C tr -dc 'a-zA-Z0-9' | fold -w 10 | head -n 1`
    echo "--password is not set; using \"${PASSWORD}\""
fi

if [ -z "${HOST}" ]; then
    HOST="%"
    echo "--remote-host is not set; using \"${HOST}\""
fi

mysql -e "DROP USER '${USERNAME}'@'${HOST}';"
mysql -e "CREATE USER '${USERNAME}'@'${HOST}' IDENTIFIED BY '${PASSWORD}';"
mysql -e "GRANT REPLICATION SLAVE ON *.* TO '${USERNAME}'@'${HOST}';"

echo "Created replication slave user '${USERNAME}'@'${HOST}'."
echo "Now on the remote container, execute the following MySQL statements:"
echo "kubectl exec \$(kubectl get pods -l chart=ibmcase-mysql-0.1.0 -o go-template --template '{{ (index .items 0).metadata.name }}') -- /scripts/start_replicate.sh --repl-user=repl --repl-password=replPassw0rd --master-host=<my ip> --master-port=<my port> "
