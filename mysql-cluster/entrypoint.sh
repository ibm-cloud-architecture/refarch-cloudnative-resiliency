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


sleep 10

if [ "$1" == "mysqld" ]; then
    # distribute the privileges
    mysql < /usr/local/mysql/share/ndb_dist_priv.sql
    mysql -e 'CALL mysq.mysql_cluster_move_privileges();'
fi
