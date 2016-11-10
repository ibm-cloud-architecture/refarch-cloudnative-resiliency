# MySQL Cluster 

[MySQL Cluster](https://www.mysql.com/products/cluster/) provides a scale-out highly available distributed database.  This repository provides a Docker image for quickly building a MySQL cluster.  By default, the provisioned cluster contains 1 management node, 2 SQL nodes, and 3 Data Nodes.  Our example constructs two standalone clusters in two different datacenters and sets up bi-directional replication for maximum availability of data across two regions.

## VPN Setup

### Set up VPN Tunnel between BlueMix and On-Premise resources

In this section you will establish a secure peer to peer IPsec tunnel between the IBM VPN Service in Bluemix and the Vyatta Gateway Appliance in SoftLayer.  This must be performed for each of the BlueMix regions hosting the BlueCompute application.

See [VPN Instructions](../VPN.md) on how to proceed

# Cluster Creation

Create the MySQL Cluster nodes in one of the sites using the following steps to build the docker image and construct the configuration for each of the cluster roles.  

![MySQL Cluster](./mysql-cluster.png)


## Docker Setup

See [Docker Instructions](docker/README.md) on how to proceed with creating a MySQL cluster setup in docker containers

## Ansible Setup

See [Ansible Instructions](ansible/README.md) on how to proceed with using [Ansible](https://www.ansible.com/) to create a MySQL cluster in SoftLayer VMs.

#### Load Database Schema

Once the SQL nodes are up, the database schema for the inventory microservice can be loaded, which reuses the script from [MySQL repository](https://github.com/ibm-cloud-architecture/refarch-cloudnative-mysql).  In one of the SQL nodes, execute the following commands, which creates the table, and then moves it onto the datanodes so it can be served by any of the SQL nodes.

```
# /usr/local/bin/load-data.sh
# mysql -e 'alter table inventorydb.items engine=ndbcluster;'
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

![MySQL Cluster Replication](./mysql-cluster-replication.png)

### Create replication user

On the Master SQL nodes (SQL node 1 in both sites), create a user used for replication.

```
# mysql -e "create user '<repl-user>'@'%' identified by '<repl-password>';"
# mysql -e "grant replication slave on *.* to '<repl-user>'@'%';"
```

### Flush and lock tables

To prevent writes while configuring replication, flush all in-flight transactions and lock the tables for read only

```
# mysql -e 'FLUSH TABLES WITH READ LOCK;'
```

### Retrieve Master Parameters for Replication

Use the following command to show the binary log position on the master:
```
# mysql -e 'show master status\G;'
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

If using docker, use the `docker ps` output to discover the IP that the slave should connect to for replication:
```
# docker ps
CONTAINER ID        IMAGE               COMMAND                  CREATED             STATUS              PORTS                           NAMES
5f47b9bdf1ca        mysql-cluster       "/usr/local/bin/entry"   21 hours ago        Up 21 hours         10.121.163.234:3306->3306/tcp   mysql-dal09-sqlnode1
ee903d825ed9        209fd4758142        "/usr/local/bin/entry"   22 hours ago        Up 22 hours                                         mysql-dal09-datanode1
```


### Configure and start slave

On the remote slave hosts (SQL node 2), configure the slave host to connect to the master and begin replication at the specified binary log position

```
# mysql -e "stop slave;"
# mysql -e "change master to master_host='<master ip>', master_port=<master_port>, master_user='<repl-user>, master_password='<repl-password>', master_log_file='<log file name>', master_log_pos=<log position>;"
# mysql -e "start slave;"
```

Check the slave status:
```
# mysql -e "show slave status \G;"
```

### Unlock tables on Remote Master
Once the slave has caught up to the master, unlock the tables on the master host:
```
# mysql -e "unlock tables;"
```

### View slave host status on the remote master

ON REMOTE MASTER, see slaves:
```
# mysql -e "show slave hosts\G;"
*************************** 1. row ***************************
 Server_id: 21
      Host: 
      Port: 3306
 Master_id: 10
Slave_UUID: 6ac52a12-84c9-11e6-88c4-0242ac140004

```
