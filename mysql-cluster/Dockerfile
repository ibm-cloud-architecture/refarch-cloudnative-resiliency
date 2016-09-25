FROM centos:6

RUN yum -y install wget tar perl perl-Data-Dumper libaio
RUN groupadd mysql
RUN useradd -g mysql -s /bin/false mysql

RUN wget http://cdn.mysql.com//Downloads/MySQL-Cluster-7.4/mysql-cluster-gpl-7.4.12-linux-glibc2.5-x86_64.tar.gz
RUN tar -C /usr/local -zxvf mysql-cluster-gpl-7.4.12-linux-glibc2.5-x86_64.tar.gz
RUN rm -f /mysql-cluster*.tar.gz
RUN ln -s /usr/local/mysql-cluster-gpl-7.4.12-linux-glibc2.5-x86_64 /usr/local/mysql

RUN mkdir -p /usr/local/mysql/mysql-cluster

RUN mkdir -p /var/lib/mysql-cluster
RUN mkdir -p /var/lib/mysql/data

COPY entrypoint.sh /usr/local/bin/
RUN chmod u+x /usr/local/bin/entrypoint.sh

RUN ln -s /usr/local/mysql/bin/ndb_mgm /usr/local/bin/ndb_mgm
RUN ln -s /usr/local/mysql/bin/ndb_mgmd /usr/local/bin/ndb_mgmd 
RUN ln -s /usr/local/mysql/bin/ndbd /usr/local/bin/ndbd 
RUN ln -s /usr/local/mysql/bin/ndbmtd /usr/local/bin/ndbmtd 
RUN ln -s /usr/local/mysql/bin/mysqld /usr/local/bin/mysqld 

WORKDIR /usr/local/bin

VOLUME /var/lib/mysql
ENTRYPOINT [ "/usr/local/bin/entrypoint.sh" ]

