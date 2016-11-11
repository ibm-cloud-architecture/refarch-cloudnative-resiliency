# MySQL Cluster Docker Setup

The code requires that at least three docker hosts are provided to distribute the various containers on to.  In this example, a fourth Docker host is used to host a Consul keystore and an overlay network is created so that containers on different hosts can communicate on a private subnet.

## Create a Consul keystore

### Install the Consul keystore in a Docker Container
Consul is used as to store the state of containers on the overlay network.  The keystore publishes port 8500 which all other Docker hosts connect to.

```
# docker run -d -p 8500:8500 -h consul --name consul progrium/consul -server -bootstrap
```

### Set up Docker daemon
On all hosts used to run containers for MySQL cluster, update the docker daemon to connect to Consul.  On CentOS 7 hosts, this can be found in `/etc/sysconfig/docker`:

```
OPTIONS='--selinux-enabled --log-driver=journald -H tcp://0.0.0.0:2375 -H unix://var/run/docker.sock --cluster-store=consul://<console-host>:8500 --cluster-advertise=eth0:2375'
```

Once the configuration is modified, restart docker:

```
# systemctl restart docker
```

### Create a Docker overlay network

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

## Define environment

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

## Create external volumes (optional)

The /var/lib/mysql directory in the container is configured as a volume and can be mounted as an external directory inside of the container.  This allows the volume to backed up separately and the data to be persisted the next time the container starts up with that data mounted.

In the reference architecture, since SoftLayer VMs are used to represent the on-premise resources, a second, third, and fourth SAN-provisioned disk are added to the VM.  These appear to the host operating system as `/dev/xvdc`, `/dev/xvdd`, and `/dev/xvde`.

To prepare these disks, use parted to prepare the partitions:

```
# parted
> select /dev/xvdc
> mklabel msdos
> mkpart primary ext4 0% 100%
> quit
```

Then, use mkfs.ext4 to create the filesystem:

```
# mkfs.ext4 /dev/xvdc1
```

Then, mount the filesystem to a mountpoint:
```
# mkdir -p /mnt/xvdc1
# mount /dev/xvdc1 /mnt/xvdc1
```

In the following script commands used to create nodes for each of the roles, you can optionally pass one of these directories so that data will be placed into these directories instead of in anonymous volumes.

## New Relic Agent installation (optional)

New Relic can be used to monitor the SQL nodes.  If a New Relic license key is available, it can be provided as an environment variable to the blow scripts as follows:

```
export NEW_RELIC_LICENSE_KEY=<license key>
```

If the above variable is in the environment during execution, the below scripts will capture the value and configure and start the New Relic Java Agent with the MySQL plugin as the SQL node containers are started.  Note that the MySQL plugin only supports monitoring InnoDB and not NDB so not all metrics regarding MySQL cluster are available.

## Build management node

The management node serves as a coordinator for the other cluster nodes to exchange configuration in order to organize itself as a cluster.  Our example builds one management node by default.  Note that the management node is not required for normal cluster operations, but scaling up the number of other node types will require a functional management node.

```
# ./build_mysql_cluster mgmt 1 [/mnt/xv<c|d|e>1]
```

## Build data nodes

The data node stores replica(s) of data.  The data node requires a management node to be operational before it will start correctly.  By default, all of the data nodes will join node group 0, which is sufficient for our example as there is just one database and one table in the inventory microservice.  Our example has three data nodes and  three separate replicas, so the data nodes are distributed on on each of the docker hosts in our example.

```
# ./build_mysql_cluster data <1|2|3> [/mnt/xv<c|d|e>1]
```

## Build SQL nodes

The SQL nodes (also called API nodes), serve up the data stored in the data nodes.  In MySQL Cluster, these nodes run the mysqld daemon which applications can connect to using the traditional MySQL JDBC driver.  Since there are two SQL nodes in our example, the application can connect to either of the SQL nodes for high availability.  The MySQL nodes publish port 3306 externally and so they are distributed one per docker host.

```
# ./build_mysql_cluster sql <1|2>  [/mnt/xv<c|d|e>1]
```


