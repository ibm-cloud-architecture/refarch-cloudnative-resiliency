#!/bin/bash

CMD="$@"

mkdir -p /var/lib/mysql/data

if [ "$1" == "mysqld" ]; then

    /usr/local/mysql/scripts/mysql_install_db --user=mysql --basedir=/usr/local/mysql --datadir=/var/lib/mysql

    # temporarily start mysqld with no networking
    "$1" --skip-networking &
    pid="$!"

    if [ ! -z "${NEW_RELIC_LICENSE_KEY}" ]; then
        cd /root/newrelic-npi

        # install new relic mysql plugin
        ./npi install nrmysql --user=root --distro=redhat -n -y

        # generate the config
        cp /root/newrelic-npi/plugins/com.newrelic.plugins.mysql.instance/newrelic_mysql_plugin-2.0.0/config/plugin.template.json /root/newrelic-npi/plugins/com.newrelic.plugins.mysql.instance/newrelic_mysql_plugin-2.0.0/config/plugin.json

        sed -i -e 's/"name".*:.*/"name":"'${HOSTNAME}'",/' /root/newrelic-npi/plugins/com.newrelic.plugins.mysql.instance/newrelic_mysql_plugin-2.0.0/config/plugin.json
        sed -i -e 's/"user".*:.*/"user": "newrelic",/' /root/newrelic-npi/plugins/com.newrelic.plugins.mysql.instance/newrelic_mysql_plugin-2.0.0/config/plugin.json
        sed -i -e 's/"passwd".*:.*/"passwd": "newrelic"/' /root/newrelic-npi/plugins/com.newrelic.plugins.mysql.instance/newrelic_mysql_plugin-2.0.0/config/plugin.json

        # set the license key
        ./npi config set license_key ${NEW_RELIC_LICENSE_KEY}

        # create the newrelic user
	mysql --protocol=socket -uroot -e "GRANT PROCESS,REPLICATION CLIENT ON *.* TO 'newrelic'@'localhost' IDENTIFIED BY 'newrelic';"
	mysql --protocol=socket -uroot -e "GRANT PROCESS,REPLICATION CLIENT ON *.* TO 'newrelic'@'127.0.0.1' IDENTIFIED BY 'newrelic';"

        # generate rest of config
        ./npi prepare nrmysql -n
    
        # start the plugin
        ./npi add-service nrmysql --start --user=root --distro=redhat
    fi

    mysql --protocol=socket -uroot -e 'source /usr/local/mysql/share/ndb_dist_priv.sql'
    mysql --protocol=socket -uroot -e 'CALL mysql.mysql_cluster_move_privileges();'

    kill -s TERM ${pid}

elif [ "$1" == "ndb_mgmd" ]; then
    ARGS="-f /etc/mysql-cluster.ini --nodaemon"
elif [ "$1" == "ndbd" ]; then
    ARGS="--nodaemon"
fi

exec "$CMD" $ARGS 
