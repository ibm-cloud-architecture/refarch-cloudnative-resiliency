# MySQL Cluster 

MySQL Cluster provides a scale-out highly available distributed database.  This repository provides a Docker image for quickly building a MySQL cluster.  By default, the cluster contains 1 management node, 2 SQL nodes, and 3 Data Nodes. 

## Docker Setup

The code requires that at least three docker hosts are provided to distribute the various containers on to.  In this example, a fourth Docker host is used to host a Consul keystore and an overlay network is created.

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

#### Create an overlay network

The included script will create the network `mynet` if it's missing, but it's worth trying to see if creating the network manually will result in the network distributed across all Docker hosts connected to Consul:

Run the following on one of the Docker hosts:
```
# docker network create -d overlay --subnet=172.20.0.0/16 mynet
```

Then on the other Docker hosts:
```
# docker network inspect mynet
```
