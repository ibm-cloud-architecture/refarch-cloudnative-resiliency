# Making Microservices Resilient

## Introduction

This is a repository contains instructions for making the [reference applicaiotn] (https://github.com/ibm-cloud-architecture/refarch-cloudnative) Resilient.  It will cover topics on making this implementation Highly Available, able to failover, and how to handle disaster recovery.  

The Diagram below shows the topology for scaling the solution in Bluemix.  

 ![Architecture](MicroserviceResilient.png?raw=true)

Much of the guidance comes from this [article.](https://www.ibm.com/developerworks/cloud/library/cl-high-availability-and-disaster-recovery-in-bluemix-trs/index.html)

## Load Balancing Topics

This section describes how to configure a Global Load Balancer for across 2 Bluemix Instances.  We will aim to provide several examples.  


### Configuring Global Load Balancers


- [Configuring nginx load balancer across Bluemix Instances](https://github.com/ibm-cloud-architecture/refarch-cloudnative-nginx)




### HA and Failover Built into the Platform

#### Container Groups

#### AutoScale  




## Replicating Databases


https://github.com/ibm-cloud-architecture/refarch-cloudnative-resiliency/tree/master/mysql


https://github.com/ibm-cloud-architecture/refarch-cloudnative-resiliency/tree/master/cloudant

