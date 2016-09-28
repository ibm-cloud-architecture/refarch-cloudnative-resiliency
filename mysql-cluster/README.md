# MySQL Cluster 

MySQL Cluster provides a scale-out highly available distributed database.  This repository provides a Docker image for quickly building a MySQL cluster.  By default, the cluster contains 1 management node, 2 SQL nodes, and 3 Data Nodes.  Our example constructs two standalone clusters in two different datacenters and sets up bi-directional replication for maximum availability of data across two regions.

## VPN Setup

### Set up VPN Tunnel between BlueMix and On-Premise resources

In this section you will establish a secure peer to peer IPsec tunnel between the IBM VPN Service in Bluemix and the Vyatta Gateway Appliance in SoftLayer.  This must be performed for each of the BlueMix regions hosting the BlueCompute application.

#### Setup IBM VPN Service in Bluemix
1. Create a VPN service instance in Bluemix
   ```
   # cf create-service VPN_Service_Broker Standard My-VPNService
   ```

2. Go to the Bluemix Dashboard. From list of services double-click on `My-VPNService` service to launch the IBM Virtual Private Network dashboard.

3. Click on Create Gateway to create the default gateway. Note down the IP Address of the gateway. In SoftLayer Vyatta configuration when creating the IPsec peer, replace `<BMX-VPN-GW-IP>` with this value.

4. Also note down the Subnets for All Single Containers and All Scalable Groups. In SoftLayer Vyatta configuration when creating the IPsec peer, replace `<BMX-IC-Subnet>` with this value.

#### Setup Vyatta Gateway in SoftLayer
1. Log into the SoftLayer Portal. Place an Order for a Vyatta Gateway Appliance. Note the following hardware specifications are not recommended for a production grade setup, these are minimum specifications to run sample
workloads.

   | Item             | Value                                    |
   |------------------|------------------------------------------|
   | Server           | Single Intel Xeon E3-1270                |
   | RAM              | 4 GB                                     |
   | Operating System | Vyatta 6.x Subscription Edition (64 bit) |
   | Disk             | 1TB JBOD                                 |

2. Go to the Device Details for your MySQL Database server. Disconnect the Public interface, then click on VLAN of the Private interface and note down the VLAN Number.

3. Note down the Subnet at bottom of the page, replace `<Local-Subnet>` with this value in Vyatta configuration. Click on the subnet note down the Gateway address, replace `<vif-gateway>` in Vyatta configuration with this value. Also note down the Mask Bits of the subnet, it is the numeric value after the forward slash (for example /26).

4. SSH into MySQL server and add route to Containers network in Bluemix via
Vyatta Gateway.
    ```
    # ip route add default via <vif-gateway>
    ```

5. After the Vyatta is provisioned, connect to SoftLayer VPN and ssh to the Vyatta using it’s private IP address as user vyatta.

6. Switch to configuration mode and run following commands to add a virtual
interface to route to the VLAN containing MySQL server.
   ```
   $ configure 
   # set interfaces bonding bond0 vif <VLAN-Number> address '169.254.178.90/29' 
   # set interfaces bonding bond0 vif <VLAN-Number> vrrp vrrp-group 2 priority '254' 
   # set interfaces bonding bond0 vif <VLAN-Number> vrrp vrrp-group 2 sync-group 'vgroup1' 
   # set interfaces bonding bond0 vif <VLAN-Number> vrrp vrrp-group 2 virtual-address '<vif-gateway>/<Mask Bits>'
   ```

7. In configuration mode run the following commands to create the IPsec peer.
   ```
   # set vpn ipsec esp-group bmx-esp-default compression 'disable' 
   # set vpn ipsec esp-group bmx-esp-default lifetime '3600' 
   # set vpn ipsec esp-group bmx-esp-default mode 'tunnel' 
   # set vpn ipsec esp-group bmx-esp-default pfs 'dh-group2' 
   # set vpn ipsec esp-group bmx-esp-default proposal 1 encryption 'aes128' 
   # set vpn ipsec esp-group bmx-esp-default proposal 1 hash 'sha1' 
   # set vpn ipsec ike-group bmx-ike-default dead-peer-detection action 'restart' 
   # set vpn ipsec ike-group bmx-ike-default dead-peer-detection interval '20' 
   # set vpn ipsec ike-group bmx-ike-default dead-peer-detection timeout '120' 
   # set vpn ipsec ike-group bmx-ike-default lifetime '86400' 
   # set vpn ipsec ike-group bmx-ike-default proposal 1 dh-group '2' 
   # set vpn ipsec ike-group bmx-ike-default proposal 1 encryption 'aes128' 
   # set vpn ipsec ike-group bmx-ike-default proposal 1 hash 'sha1' 
   # set vpn ipsec ipsec-interfaces interface 'bond1' 
   # set vpn ipsec site-to-site peer <BMX-VPN-GW-IP> authentication mode 'pre-shared-secret' 
   # set vpn ipsec site-to-site peer <BMX-VPN-GW-IP> authentication pre-shared-secret 'sharedsecretstring'
   # set vpn ipsec site-to-site peer <BMX-VPN-GW-IP> connection-type 'initiate' 
   # set vpn ipsec site-to-site peer <BMX-VPN-GW-IP> default-esp-group 'bmx-esp-default' 
   # set vpn ipsec site-to-site peer <BMX-VPN-GW-IP> ike-group 'bmx-ike-default' 
   # set vpn ipsec site-to-site peer <BMX-VPN-GW-IP> local-address '<Vyatta-Public-Address>' 
   # set vpn ipsec site-to-site peer <BMX-VPN-GW-IP> tunnel 1 allow-nat-networks 'disable' 
   # set vpn ipsec site-to-site peer <BMX-VPN-GW-IP> tunnel 1 allow-public-networks 'disable' 
   # set vpn ipsec site-to-site peer <BMX-VPN-GW-IP> tunnel 1 local prefix '<Local-Subnet>' 
   # set vpn ipsec site-to-site peer <BMX-VPN-GW-IP> tunnel 1 remote prefix '<BMX-IC-Subnet>'
   ```

8. Commit and Save the configuration
   ```
   # commit 
   # save
   ```

9. Go to SoftLayer portal, browse to Network > Gateway Appliances. Click on the Vyatta Gateway configured for this setup to launch the Details page.

10. Under the Associate a VLAN, select the VLAN Number saved from step-2 and click on Associate. The VLAN will be added to Associated VLANs.

11.  Under Associated VLANs select the VLAN that was just added. Click on Actions and select Route VLAN. Give it a few minutes for the configuration change to take effect.


#### Create Site Connection in IBM VPN Service in Bluemix

1. Go to the Bluemix Dashboard. From list of services double-click on `My-VPNService` service to launch the IBM Virtual Private Network dashboard.

2. Click on Create Connection to create a new site-to-site connection with the Vyatta Gateway in SoftLayer. Use following values to create a new connection. Accept defaults for other input fields.

   | Name                 | Value                                    |
   |----------------------|------------------------------------------|
   | Preshared Key String | Sharedsecretstring                       |
   | Customer Gateway IP  | `<Vyatta-Public-Address>`                |
   | Customer Subnet      | `<Local-Subnet>` in Vyatta Configuration |

3. Connection should be created with Status ACTIVE.



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

## Cluster Creation

Create the MySQL Cluster nodes in one of the sites using the following steps to build the docker image and construct the configuration for each of the cluster roles.  

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

The SQL nodes (or also called API nodes), serve up the data stored in the data nodes.  In MySQL Cluster, these nodes run the mysqld daemon which applications can connect to using the traditional MySQL JDBC driver.  Since there are two SQL nodes in our example, the application can connect to either of the SQL nodes for high availability.  The MySQL nodes publish port 3306 externally and so they are distributed one per docker host.

```
# ./build_mysql_cluster sql <1|2>
```

#### Distributed privileges

By default, when MySQL nodes start up, they execute the SQL script in `/usr/local/mysql/share/ndb_dist_priv.sql` and the stored procedure `mysql.mysql_cluster_move_privileges()` so that the mysql user tables are stored in the data nodes instead of locally in each of the sql nodes.

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
