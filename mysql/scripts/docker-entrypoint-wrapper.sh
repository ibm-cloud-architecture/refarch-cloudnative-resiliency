#!/bin/bash


sed -i -e 's/server-id=.*/server-id='${SERVER_ID}'/' /etc/mysql/mysql.conf.d/binlog.cnf

/usr/local/bin/docker-entrypoint.sh $@
