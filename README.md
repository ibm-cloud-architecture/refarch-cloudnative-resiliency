# Making Microservices Resilient

## Introduction
This repository contains instructions and tools to improve availability and performances of the BlueCompute sample application available at the following [link](https://github.com/ibm-cloud-architecture/refarch-cloudnative)

It's recommended to complete the deployment of all components of BlueCompute application at least on one Bluemix region before going ahead with instructions reported in this document to setup a resilient environment.

If you are not interested on understanding aspects like Disaster Recovery or scalability at global level, you can ignore this project.

## High Availability and Disaster Recovery
When dealing with improved resilience it important to make some distinctions between High Availability (HA) and Disaster Recovery (DR).

HA is mainly about keeping the service available to the end users when "ordinary" activities are performed on the system like deploying updates, rebooting the hosting Virtual Machines, applying security patches to the hosting OS, etc.  

HA usually doesn't deal with major unplanned (or planned) issues like complete site loss for instance due to major power outages, earthquakes, severe hardware failures, full-site connectivity loss, etc.   

In such cases, if the availability of the service have strict Service Level Objective (SLO), you should make the whole application stack (infrastructure, services and application components) redundant by relying on at least two different Bluemix regions. This is typically defined as DR Architecture.

There are many options to implement DR solutions, just for the sake of simplicity, we can group the different options in three major categories:

* __Active/Passive__
* __Active/Stand by__
* __Active/Active__

__Active/Passive__ is based on keeping the full application stack active in one location, while another application stack is deployed in a different location, but kept idle (or shut down). In case of prolongated unavailability of the primary site, the application stack is activated in the backup site. Usually that requires the restoring of backups taken in the primary site. This approach is not recommended when loosing data can be a problem (RPO less than few hours ) or when the availability of the service is critical (RTO less than few hours)

In the __Active/Stand by__ case the full application stack is active in both primary and backup location, however users transactions are served only by the primary site. The backup site takes care of keeping a replica of the status of the main location though data replication (like DB replication or disk replication). In case of prolongated unavailability of the primary site, all client transactions are routed to the backup site. This approach provides quite good RPO and RTO (minutes), however it is significantly more expensive that Active/Passive because of the double deployment (there is waste of resources because the Stand by assets can't be used to improve scalability and throughput)  

In the __Active/Active__ case both locations are active and client transactions are distributed according to predefined policies (like round-robin, load balancing, location, etc. ) to both regions.  In case of failures of one site the other site will serve all clients. It's possible to achieve RPO and RTO close to zero with this configuration. The drawback is that both regions must be sized to handle the full load, even if they are used at the half of their capabilities when both locations are available. In such case Bluemix Autoscaling service can help in keeping always resources allocated according to the needs (as it happens with BlueCompute sample application).

## Scalability and Performance considerations

Adding resilience usually implies having redundant deployments, such redundancy can be used also to improve performance and scalability. That is true for the Active/Active case, described in the above section.
In case of global applications, it is possible to redirect users' transactions to the closest location (to improve response time and latency) by using Global Routing solutions (like Akamai or Dyn).

## Resiliency in BlueCompute
BlueCompute sample application is designed to provide HA when running in a single location, in fact both Inventory and Social Review Microservices are hosted in Docker groups. IBM Container services provides a continous monitoring of those groups and in case of problems (or increased demand) it will take care of standing up new containers and of adding them to the group.

Something similar happens with Inventory-BFF and Scovial-BFF services through BlueMix Autoscaling Service.

More information about mechanism available in Bluemix for HA are available at this [link](BMX_HA.md)

For what concerns DR, we designed BlueCompute to provide __Active/Active__ capabilities because this is the most typical scenario for modern applications to which we demand 99.999% availability and extraordinary  levels of scalability.

The Diagram below shows the DR topology for BlueCompute solution in Bluemix.

***Please Note: the Diagram applies only to Bluemix Dedicated. IBM API Connector doesn'tprovide cross-site replication. In this case the solution we are describing (Bluemix Public) only APIC Gateway is behind the load balancer, while API Manager and API Developer Portal are  accessed directly***  

 ![Architecture](DR-Active-Active.png?raw=true)

Much of the guidance comes from this [article.](https://www.ibm.com/developerworks/cloud/library/cl-high-availability-and-disaster-recovery-in-bluemix-trs/index.html)


## Implementing Active/Active DR for BlueCompute
In this section you find the step by step guide that will help you in the implementation of the ACive/Active DR solution for BlueCompute.

The main steps are the following:  

1. __Deploy BlueCompute to a new Bluemix region__ Assuming you have already deployed BlueCompute to Bluemix US Central region, you can deploy a new instance in Bluemix EU-GB region by following instructions at this [link](https://github.com/ibm-cloud-architecture/refarch-cloudnative). It is strongly recommended to keep same naming conventions between the two deployments (Bluemix spaces, Application names, Docker container names, etc. ). ___Important: it's mandatory to keep the same Org name and the same Catalog name when configuring APIC catalog.___  

2. __Configure Database Replication__  for both MySQL and Cloudant DB as the described in the documents available at the links below:

 * [Replicating MySQL](./mysql/README.md)
 
 * [Replicating MySQL Cluster](./mysql-cluster/README.md)

 * [Replicating with Cloudant](./cloudant/README.md)

3. __Configure load Balancer__ In order to have a reliable load balancing solution to route calls to IBM API Connect we recommend the usage of commercial solutions like Akamai Global Transaction Manager or Dyn for production environments. However for development (or Proof Of Concept) environments, it is also possible to use cheaper solutions like NGINX. Also with NGINX is possible to experiment Location-based routing as documented [here](http://jamesthom.as/blog/2015/09/11/location-based-cloud-foundry-applications-with-nginx-and-docker/). However, consider that in this case NGINX is a Single Point Of Failure (SPOF). In order to setup NGINX you have to:  
  * [Build NGINX Container](https://github.com/ibm-cloud-architecture/refarch-cloudnative-nginx)
  * Start the container in IBM Bluemix container service
  * Note down the IP address of BlueCompute NGINX Docker container
  * Optionally define a DNS associated to the IP of BlueCompute NGINX (recommended)

4. __Align APIC settings across sites__ When BlueCompute is deployed to two separate Bluemix Public environments, it's important to keep aligned APIC configurations in both locations, so calls made to REST apis by clients can be routed seamless to one of the two locations by the front-end load-balancer. In order to make that possible both APIC deployments must have use the same Org name a and the same Catalog name. In addition to that both deployments must use the same Client ID. While it's possible to set Org name and Catalog name, it is not possible to set Client ID at deployment time. Client ID must be set by calling API Management APIs, because unfortunately such use case is not exposed in APIC management UI. Instructions to set Client ID are documented [here](./set_APIC_CLIENTID.md).

5. __Configure BlueCompute Web Application and Mobile Application__  to point to the Load Balancer in front of the two APIC instances instead of pointing directly to the APIC Gateway.
  * In order to configure BlueCompute Web Application you have to edit the file "config/default.json" and set the property "host" to the IP (or the associated DNS name) of NGINX Docker container that you have noted down in the step 3. Please refer to this [link](https://github.com/ibm-cloud-architecture/refarch-cloudnative-bluecompute-web) for instructions about how to configure BlueCompute web Application
  * In order to configure BlueCompute Mobile Application you have to edit the file "Config.plist" and set the value of the hostname in the properties ItemRestUrl, reviewRestUrl, oAuthBaseURl, oAuthRestUrl to the IP (or the associated DNS name) of NGINX Docker container that you have noted down in the step 3. Please refer to this [link](https://github.com/ibm-cloud-architecture/refarch-cloudnative-bluecompute-mobile) for instructions about how to configure BlueCompute Mobile Application

6. __Test availability of the app__  Test should include the bringing offline APIC service in one location.

At this point, it should be possible to use BlueCompute Mobile App and BlueCompute Web Application even when one of the two sites is unavailable.
