FROM centos:6

ARG NEW_RELIC_LICENSE_KEY 

ENV NEW_RELIC_LICENSE_KEY ${NEW_RELIC_LICENSE_KEY}

RUN yum -y install wget tar perl perl-Data-Dumper libaio sudo java
RUN groupadd mysql
RUN useradd -g mysql -s /bin/false mysql

RUN wget http://cdn.mysql.com//Downloads/MySQL-Cluster-7.4/mysql-cluster-gpl-7.4.12-linux-glibc2.5-x86_64.tar.gz
RUN tar -C /usr/local -zxvf mysql-cluster-gpl-7.4.12-linux-glibc2.5-x86_64.tar.gz
RUN rm -f /mysql-cluster*.tar.gz
RUN ln -s /usr/local/mysql-cluster-gpl-7.4.12-linux-glibc2.5-x86_64 /usr/local/mysql

RUN curl https://bootstrap.pypa.io/get-pip.py | python2.6
RUN echo "http://cdn.mysql.com//Downloads/MySQLGUITools/mysql-utilities-1.6.4.tar.gz" > /tmp/requirements.txt
RUN echo "http://cdn.mysql.com//Downloads/Connector-Python/mysql-connector-python-2.1.3.tar.gz" >> /tmp/requirements.txt

RUN pip install -r /tmp/requirements.txt
RUN rm -f /tmp/requirements.txt

# install newrelic agent
RUN UNATTENDED=true bash -c "$(curl -sSL https://download.newrelic.com/npi/release/install-npi-linux-debian-x64.sh)"

RUN mkdir -p /usr/local/mysql/mysql-cluster

RUN mkdir -p /var/lib/mysql/data

COPY entrypoint.sh /usr/local/bin/
RUN chmod u+x /usr/local/bin/entrypoint.sh

RUN ln -s /usr/local/mysql/bin/ndb_mgm /usr/local/bin/ndb_mgm
RUN ln -s /usr/local/mysql/bin/ndb_mgmd /usr/local/bin/ndb_mgmd 
RUN ln -s /usr/local/mysql/bin/ndbd /usr/local/bin/ndbd 
RUN ln -s /usr/local/mysql/bin/ndbmtd /usr/local/bin/ndbmtd 
RUN ln -s /usr/local/mysql/bin/mysqld /usr/local/bin/mysqld 
RUN ln -s /usr/local/mysql/bin/mysql /usr/local/bin/mysql
RUN ln -s /usr/local/mysql/bin/mysql_config_editor /usr/local/bin/mysql_config_editor

COPY refarch-cloudnative-mysql/scripts/load-data.sh /usr/local/bin/load-data.sh
RUN chmod u+x /usr/local/bin/load-data.sh

WORKDIR /usr/local/bin

VOLUME /var/lib/mysql
ENTRYPOINT [ "/usr/local/bin/entrypoint.sh" ]

