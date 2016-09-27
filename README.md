# Making Microservices Resilient

## Introduction

This is a repository contains instructions for making the [reference applicaiotn] (https://github.com/ibm-cloud-architecture/refarch-cloudnative) Resilient.  It will cover topics on making this implementation Highly Available, able to failover, and how to handle disaster recovery.  

The Diagram below shows the topology for scaling the solution in Bluemix.  

 ![Architecture](MicroserviceResilient.png?raw=true)

Much of the guidance comes from this [article.](https://www.ibm.com/developerworks/cloud/library/cl-high-availability-and-disaster-recovery-in-bluemix-trs/index.html)

## Adding Load Balancing into the Solution

This section describes how to configure a Global Load Balancer for across 2 Bluemix Instances.  We will aim to provide several examples.  


### Using nginx as a Global Load Balancer

- [Configuring nginx load balancer across Bluemix Instances](https://github.com/ibm-cloud-architecture/refarch-cloudnative-nginx)




## HA and Failover Built into the Bluemix Platform



### Container Groups

The Bluemix Platform has built in clustering for Containers.  

In our example, we created Container Groups:


-  The Inventry Microservice runs in a Docker Containter.  

The command below shows how we create a Container Group, which provides multiple container instances.   You can use the tutorial [In Step 7, we created the container using a Container Group that creates Docker Cluster](https://github.com/ibm-cloud-architecture/refarch-cloudnative-micro-inventory) to execute.  

```
 cf ic group create -p 8080 -m 512 --min 1 --auto --name micro-inventory-group -e "spring.datasource.url=jdbc:mysql://{ipaddr-db-container}:3306/inventorydb" -e "spring.datasource.username={dbuser}" -e "spring.datasource.password={password}" -n inventoryservice -d mybluemix.net registry.ng.bluemix.net/$(cf ic namespace get)/inventoryservice:cloudnative

```

- The [Social Review Mircroservice also creates a Container Group](https://github.com/ibm-cloud-architecture/refarch-cloudnative-micro-socialreview).

```

cf ic group create -p 8080 -m 512 --min 1 --auto --name micro-socialreview-group -n socialreviewservice -d mybluemix.net registry.ng.bluemix.net/{yournamespace}/socialreviewservice

```

You can learn about [Container Groups here](https://new-console.ng.bluemix.net/docs/containers/container_ha.html).  

It is important that any container that needs to store data, should use volumes as described [here](https://new-console.ng.bluemix.net/docs/containers/container_volumes_ui.html).

### AutoScale  

For [our Node.JS based Cloud Foundry Applications](https://github.com/ibm-cloud-architecture/refarch-cloudnative-bff-inventory), we use AutoScaling built into the platform.   [Both Services](https://github.com/ibm-cloud-architecture/refarch-cloudnative-bff-socialreview) use this.  

```
 cf create-service Auto-Scaling free cloudnative-autoscale

```


## Replicating Databases

How you replicate databases across Cloud Instances is key to providing DR.  We have 2 examples for our reference implementation.  


- [Replicaing MySQL](https://github.com/ibm-cloud-architecture/refarch-cloudnative-resiliency/tree/master/mysql)


- [Replicating with Cloudant](https://github.com/ibm-cloud-architecture/refarch-cloudnative-resiliency/tree/master/cloudant)

