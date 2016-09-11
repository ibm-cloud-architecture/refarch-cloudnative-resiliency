FROM mysql

ARG repl_user=repl
ARG repl_passwd=repl$user!p4sswd

ENV REPL_USER ${repl_user}
ENV REPL_PASSWD ${repl_passwd}

COPY etc/mysql/mysql.conf.d/binlog.cnf /etc/mysql/mysql.conf.d/binlog.cnf

ADD scripts /root/scripts
WORKDIR /root/scripts

RUN chmod u+x /root/scripts/*.sh

ENTRYPOINT ["/root/scripts/docker-entrypoint-wrapper.sh"]
CMD ["mysqld"]
