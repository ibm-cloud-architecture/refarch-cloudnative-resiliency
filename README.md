# Making Microservices Resilient

## Introduction
This repository contains instructions and tools to improve the availability and scalability of the BlueCompute sample application available at the following [link](https://github.com/ibm-cloud-architecture/refarch-cloudnative)

It's recommended to complete the deployment of all components of the BlueCompute application in at least one Bluemix region before going ahead with the instructions provided in this document to setup a resilient environment.

If you are not interested on understanding aspects like Disaster Recovery or scalability at a global level, you can ignore this project.

## High Availability and Disaster Recovery
When dealing with improved resilience it important to make some distinctions between High Availability (HA) and Disaster Recovery (DR).

HA is mainly about keeping the service available to the end users when "ordinary" activities are performed on the system like deploying updates, rebooting the hosting Virtual Machines, applying security patches to the hosting OS, etc.  For our purposes, High Availability within a single site can be achieved by eliminating single points of failure.  The Blue Compute sample application in its current form implements high availability.

HA usually doesn't deal with major unplanned (or planned) issues such as complete site loss due to major power outages, earthquakes, severe hardware failures, full-site connectivity loss, etc.   In such cases, if the service must meet strict Service Level Objectives (SLO), you should make the whole application stack (infrastructure, services and application components) redundant by deploying it in at least two different Bluemix regions. This is typically defined as a DR Architecture.

There are many options to implement DR solutions.  For the sake of simplicity, we can group the different options in three major categories:

* __Active/Passive__
  
  __Active/Passive__ options are based on keeping the full application stack active in one location, while another application stack is deployed in a different location, but kept idle (or shut down). In the case of prolonged unavailability of the primary site, the application stack is activated in the backup site. Often that requires the restoring of backups taken in the primary site. This approach is not recommended when loosing data can be a problem (e.g. when the Recovery Point Objective (RPO) is less than a few hours ) or when the availability of the service is critical (e.g. when the Return to Operations (RTO) objective is less than a few hours).
  
* __Active/Standby__

  In the __Active/Standby__ case the full application stack is active in both primary and backup location, however users transactions are served only by the primary site. The backup site takes care of keeping a replica of the status of the main location though data replication (such as DB replication or disk replication). In case of prolonged unavailability of the primary site, all client transactions are routed to the backup site. This approach provides quite good RPO and RTO (generally measured in minutes), however it is significantly more expensive than the Active/Passive options because of the double deployment (e.g., resources are wasted because the Stand by assets can't be used to improve scalability and throughput).  

* __Active/Active__

  In the __Active/Active__ case both locations are active and client transactions are distributed according to predefined policies (such as round-robin, geographical load balancing, etc. ) to both regions.  In the case of failure of one site the other site must be able to serve all clients. It's possible to achieve both an RPO and RTO close to zero with this configuration. The drawback is that both regions must be sized to handle the full load, even if they are used at the half of their capabilities when both locations are available. In such cases the Bluemix Autoscaling service can help in keeping always resources allocated according to the needs (as happens with the BlueCompute sample application).

## Scalability and Performance considerations

Adding resilience usually implies having redundant deployments, such redundancy can be used also to improve performance and scalability. That is true for the Active/Active case, described in the above section.
In case of global applications, it is possible to redirect users' transactions to the closest location (to improve response time and latency) by using Global Routing solutions (like Akamai or Dyn).

## Resiliency in BlueCompute
BlueCompute sample application is designed to provide HA when running in a single location; all services are deployed as redundant ReplicaSets in Kubernetes. Kubernetes continously monitors all containers and will redeploy failed containers in case of problems.

BlueCompute can be deployed in __Active/Active__ because this is the most typical scenario for modern applications to which we demand 99.999% availability and extraordinary levels of scalability.

The Diagram below shows the DR topology for BlueCompute solution in Bluemix.

 ![Architecture](DR-Active-Active.png?raw=true)

Much of the guidance comes from this [article.](https://www.ibm.com/developerworks/cloud/library/cl-high-availability-and-disaster-recovery-in-bluemix-trs/index.html)

## Implementing Active/Active DR for BlueCompute
In this section you find the step by step guide that will help you in the implementation of the Active/Active DR solution for BlueCompute.

The main steps are the following:  

1. __Deploy BlueCompute to a new Bluemix region__ Assuming you have already deployed BlueCompute to Bluemix US South region, you can deploy a new instance in Bluemix EU-DE region by re-following instructions at this [link](https://github.com/ibm-cloud-architecture/refarch-cloudnative-kubernetes). It is strongly recommended to keep same naming conventions between the two deployments (Bluemix spaces, Application names, Kubernetes service names, etc.).

2. __Configure Database Replication__  for both MySQL and Cloudant DB as the described in the documents available at the links below:

 * [Replicating MySQL](./mysql/README.md)
 
 * [Replicating MySQL Cluster](./mysql-cluster/README.md)

 * [Replicating with Cloudant](./cloudant/README.md)

3. __Configure Load Balancer__ In order to have a reliable load balancing solution to route calls to each instance, we recommend the usage of commercial solutions like Akamai Global Traffic Management or Dyn for production environments. However for development (or Proof Of Concept) environments, it is also possible to use cheaper solutions like NGINX. Also with NGINX is possible to experiment Location-based routing as documented [here](http://jamesthom.as/blog/2015/09/11/location-based-cloud-foundry-applications-with-nginx-and-docker/). However, consider that in this case NGINX is a Single Point Of Failure (SPOF). In order to setup NGINX you have to:  
  * [Build NGINX Container](https://github.com/ibm-cloud-architecture/refarch-cloudnative-nginx)
  * Start the container in one of the Kubernetes clusters to load-balance between the two clusters
  * Note down the IP address of BlueCompute NGINX Docker container
  * Optionally define a DNS associated to the IP of BlueCompute NGINX (recommended)
  
4. __Configure automated backup__ For disaster recovery, ensure that a site can recover using [automated backups](https://github.com/ibm-cloud-architecture/refarch-cloudnative-backup).

5. __Align shared secrets across sites__ When BlueCompute is deployed to two separate Bluemix Public environments, it's important to keep aligned shared secret configurations in both locations, so calls made to OAuth protected REST APIs by clients can be routed seamlessly to one of the two locations by the front-end load-balancer. For login protected pages and OAuth protected APIs, the same HS256 key must be used so that the same token can be used in either deployment.

6. __Configure BlueCompute Web Application and Mobile Application__  to point to the Load Balancer in front of the two deployments of BlueCompute.

7. __Test availability of the app__  Test should include the bringing offline individual worker nodes in one location, and an entire cluster.

At this point, it should be possible to use BlueCompute Mobile App and BlueCompute Web Application even when one of the two sites is unavailable.
