# MySQL Cluster 

[MySQL Cluster](https://www.mysql.com/products/cluster/) provides a scale-out highly available distributed database.  This repository provides a Docker image for quickly building a MySQL cluster.  By default, the provisioned cluster contains 1 management node, 2 SQL nodes, and 3 Data Nodes.  Our example constructs two standalone clusters in two different datacenters and sets up bi-directional replication for maximum availability of data across two regions.

## VPN Setup

### Set up VPN Tunnel between BlueMix and On-Premise resources

In this section you will establish a secure peer to peer IPsec tunnel between the IBM VPN Service in Bluemix and the Vyatta Gateway Appliance in SoftLayer.  This must be performed for each of the BlueMix regions hosting the BlueCompute application.

See [VPN Instructions](../VPN.md) on how to proceed

## Docker Setup

The code requires that at least three docker hosts are provided to distribute the various containers on to.  In this example, a fourth Docker host is used to host a Consul keystore and an overlay network is created so that containers on different hosts can communicate on a private subnet.

### Create a Consul keystore

#### Install the Consul keystore in a Docker Container
Consul is used as to store the state of containers on the overlay network.  The keystore publishes port 8500 which all other Docker hosts connect to.

```
# docker run -d -p 8500:8500 -h consul --name consul progrium/consul -server -bootstrap
```

#### Set up Docker daemon
On all hosts used to run containers for MySQL cluster, update the docker daemon to connect to Consul.  On CentOS 7 hosts, this can be found in `/etc/sysconfig/docker`:

```
OPTIONS='--selinux-enabled --log-driver=journald -H tcp://0.0.0.0:2375 -H unix://var/run/docker.sock --cluster-store=consul://<console-host>:8500 --cluster-advertise=eth0:2375'
```

Once the configuration is modified, restart docker:

```
# systemctl restart docker
```

#### Create a Docker overlay network

The included script will create the network `mynet` if it's missing, but it's worth trying to see if creating the network manually will result in the network distributed across all Docker hosts connected to Consul:

Run the following on one of the Docker hosts:
```
# docker network create -d overlay --subnet=172.20.0.0/16 mynet
```

Then on the other Docker hosts:
```
# docker network inspect mynet
```

This internal network is used for intra-cluster communications.  Only the SQL nodes will have their ports published externally for applications to connect to.

## Cluster Creation

Create the MySQL Cluster nodes in one of the sites using the following steps to build the docker image and construct the configuration for each of the cluster roles.  

![MySQL Cluster](mysql-cluster.png)

### Define environment

In `env.sh`, define the environment that the cluster will be created in.  For our example, `SITE_MASK` 0 is `dal09`, while `SITE_MASK` 1 is `lon02`.  Also, adjust the subnet if desired, and the number of SQL nodes and Data nodes as needed.

```
MY_SUBNET="172.20.0.0/16"

SITE_MASK=0
SITE_NAME=dal09

num_mgmt_nodes=1
num_sql_nodes=2
num_data_nodes=3
```

e.g., in the first site (dal09),
```
SITE_MASK=0
SITE_NAME="dal09"
```

the second site (lon02),
```
SITE_MASK=1
SITE_NAME="lon02"
```

### Build management node

The management node serves as a coordinator for the other cluster nodes to exchange configuration in order to organize itself as a cluster.  Our example builds one management node by default.  Note that the management node is not required for normal cluster operations, but scaling up the number of other node types will require a functional management node.

```
# ./build_mysql_cluster mgmt 1
```

### Build data nodes

The data node stores replica(s) of data.  The data node requires a management node to be operational before it will start correctly.  By default, all of the data nodes will join node group 0, which is sufficient for our example as there is just one database and one table in the inventory microservice.  Our example has three data nodes and  three separate replicas, so the data nodes are distributed on on each of the docker hosts in our example.

```
# ./build_mysql_cluster data <1|2|3>
```

### Build SQL nodes

The SQL nodes (also called API nodes), serve up the data stored in the data nodes.  In MySQL Cluster, these nodes run the mysqld daemon which applications can connect to using the traditional MySQL JDBC driver.  Since there are two SQL nodes in our example, the application can connect to either of the SQL nodes for high availability.  The MySQL nodes publish port 3306 externally and so they are distributed one per docker host.

```
# ./build_mysql_cluster sql <1|2>
```

#### Distributed privileges

In the provided Docker image, SQL nodes will execute the SQL script in `/usr/local/mysql/share/ndb_dist_priv.sql` and the stored procedure `mysql.mysql_cluster_move_privileges()` so that the MySQL user tables are stored in the data nodes instead of locally in each of the SQL nodes.  This means that a user created on one SQL node will be able to connect to any of the SQL nodes.

Once the SQL node(s) come up, use the following commands on *one* of the SQL nodes to create a user that can connect to the database.

*It is recommended to change the username and password specified here.*

```
# docker exec -it <sql_container_name> mysql -e 'create user 'dbuser'@'%' identified by 'password';
# docker exec -it <sql_container_name> mysql -e 'grant all on *.* to user 'dbuser'@'%';
# docker exec -it <sql_container_name> mysql mysql -e 'flush privileges;'
```

#### Load Database Schema

Once the SQL nodes are up, the database schema for the inventory microservice can be loaded, which reuses the script from https://github.com/ibm-cloud-architecture/refarch-cloudnative-mysql.  In one of the SQL nodes, execute the following commands, which creates the table, and then moves it onto the datanodes so it can be served by any of the SQL nodes.

```
docker exec -it <sqlnode container name> /usr/local/bin/load-data.sh
docker exec -it <sqlnode container name> mysql -e 'alter table inventorydb.items engine=ndbcluster;'
```

#### JDBC Connection from the Application

Follow the instructions at https://github.com/ibm-cloud-architecture/refarch-cloudnative-micro-inventory.  When creating the container group for the microservice, specify the URL as:
```
"spring.datasource.url=jdbc:mysql://<sql node 1 ip>:3306,<sql node 2 ip>:3306/inventorydb"
```

#### Test insert and query from application

Use the following curl command to insert data into the database via the inventory microservices REST API:

```
# echo '{ "name":"jkwong item 1","description":"jkwong item 1", "price": 100.0, "img": "item.jpg", "img_alt": "hotdog" }'  | curl -X POST  -H "Content-type: application/json" -d@- https://<app-url>/micro/inventory
```

Use the following command to read the data from the REST API:
```
# curl https://<app-url>/micro/inventory
```


## MySQL Cluster Replication Setup

Similar to [MySQL Standalone Replication](../mysql/README.md), the MySQL Cluster can be setup to replicate between themselves across regions for high availability and disaster recovery..  MySQL Cluster does not support Global Transaction IDs like the standalone replication case does, so the configuration is slightly different.

In the example application, the `items` table uses an auto-increment primary key column.  The script that generates the configuration will generate odd IDs for one site, and even IDs for the other site, to avoid primary key collisions.

In the example, we use SQL node 2 in dal09 to replicate from SQL node 1 in lon02, and SQL node 2 in lon02 to replicate from SQL node 1 in dal09.

### Create replication user

On the Master SQL nodes (SQL node 1 in both sites), create a user used for replication.

```
# docker exec -it $sqlnode mysql -e "create user '<repl-user>'@'%' identified by '<repl-password>';"
# docker exec -it $sqlnode mysql -e "grant replication slave on *.* to '<repl-user>'@'%';"
```

### Flush and lock tables

To prevent writes while configuring replication, flush all in-flight transactions and lock the tables for read only

```
# docker exec -it $sqlnode mysql -e 'FLUSH TABLES WITH READ LOCK;'
```

### Retrieve Master Parameters for Replication

Use the following command to show the binary log position on the master:
```
# docker exec -it $sqlnode mysql -e 'show master status\G;'
```

The output looks similar to:
```
*************************** 1. row ***************************
             File: 6938e0b122b3-bin.000004
         Position: 9502
     Binlog_Do_DB: 
 Binlog_Ignore_DB: 
Executed_Gtid_Set:
```

Use docker ps output to discover the IP that the slave should connect to for replication:
```
# docker ps
CONTAINER ID        IMAGE               COMMAND                  CREATED             STATUS              PORTS                           NAMES
5f47b9bdf1ca        mysql-cluster       "/usr/local/bin/entry"   21 hours ago        Up 21 hours         10.121.163.234:3306->3306/tcp   mysql-dal09-sqlnode1
ee903d825ed9        209fd4758142        "/usr/local/bin/entry"   22 hours ago        Up 22 hours                                         mysql-dal09-datanode1
```


### Configure and start slave

On the remote slave hosts (SQL node 2), configure the slave host to connect to the master and begin replication at the specified binary log position

```
# docker exec -it $sqlnode mysql -e "stop slave;"
# docker exec -it $sqlnode mysql -e "change master to master_host='<master ip>', master_port=<master_port>, master_user='<repl-user>, master_password='<repl-password>', master_log_file='<log file name>', master_log_pos=<log position>;"
# docker exec -it $sqlnode mysql -e "start slave;"
```

Check the slave status:
```
# docker exec -it $sqlnode mysql -e "show slave status \G;"
```

### Unlock tables on Remote Master
Once the slave has caught up to the master, unlock the tables on the master host:
```
# docker exec -it $sqlnode mysql -e "unlock tables;"
```

### View slave host status on the remote master

ON REMOTE MASTER, see slaves:
```
# docker exec -it $sqlnode mysql -e "show slave hosts\G;"
*************************** 1. row ***************************
 Server_id: 21
      Host: 
      Port: 3306
 Master_id: 10
Slave_UUID: 6ac52a12-84c9-11e6-88c4-0242ac140004

```
