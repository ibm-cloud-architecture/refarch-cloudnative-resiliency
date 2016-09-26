#!/bin/bash

CMD="$@"

if [ "$1" == "mysqld" ]; then

    /usr/local/mysql/scripts/mysql_install_db --user=mysql --basedir=/usr/local/mysql --datadir=/var/lib/mysql



elif [ "$1" == "ndb_mgmd" ]; then
    ARGS="-f /etc/mysql-cluster.ini --nodaemon"
elif [ "$1" == "ndbd" ]; then
    ARGS="--nodaemon"
fi

exec "$CMD" $ARGS 


