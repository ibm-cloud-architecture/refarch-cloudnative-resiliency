# Making Microservices Resilient

## Introduction
This repository contains instructions and tools to improve availability and performances of the BlueCompute sample application available at the following [link](https://github.com/ibm-cloud-architecture/refarch-cloudnative)

It's recommended to complete the deployment of all components of BlueCompute application at least on one Bluemix region before going ahead with instructions reported in this document.

If you are not interested on understanding aspects like Disaster Recovery or scalability at global level, you can ignore this sections.

## High Availability and Disaster Recovery
When dealing with improved resilience it important to make some distinctions between High Availability (HA) and Disaster Recovery (DR).

HA is mainly about keeping the service available to the end users when "ordinary" activities are performed on the system like deploying updates, rebooting the hosting Virtual Machines, applying security patches to the hosting OS, etc.  

HA usually doesn't deal with major unplanned (or planned) issues like complete site loss due to power outage, earthquakes, major hardware failures, full-site connectivity loss, etc.   

In such cases, if the availability of the service have strict Service Level Objective (SLO), you should make the whole application stack (made up by infrastructure, services and application components) redundant by relying on at least two different Bluemix regions. This is typically defined as DR Architecture.

There are many options to implement DR solutions, just for the sake of simplicity, we can group the different options in three major categories:

* Active/Passive
* Active/Stand by
* Active/Active

___Active/Passive___ is based on having the full application stack is active in one location, while another application stack is deployed in a different location, but kept idle (or shut down). In case of prolongated unavailability of the primary site, the application stack is activated in the backup site. Usually that requires the restoring of backups taken in the primary site. This approach is not recommended when loosing data can be a problem (RPO close to 0 ) or when the availability of the service is critical (RTO close to 0)

In the ___Active/Stand by___ case the full application stack is active in both primary and backup location, however users transactions are served only by the primary site. The backup site takes care of keeping a replica of the status of the main location though data replication (like DB replication or disk replication). In case of prolongated unavailability of the primary site, all client transactions are routed to the backup site. This approach provides quite good RPO and RTO (minutes), however it is significantly more expensive that Active/Passive because of the double deployment (there is waste of resources because the Stand by assets can't be used to improve scalability and throughput)  

In the ___Active/Active___ case both locations are active and client transactions are distributed according to predefined policies (like round-robin, load balancing, location, etc. ) to both regions.  In case of failures of one site the other site will serve all clients. It's possible to achieve RPO and RTO close to zero with this configuration. The drawback is that both regions must be sized to handle the full load, even if they are used at the half of their capabilities when both locations are available. In such case Bluemix Autoscaling service can help in keeping always resources allocated according to the needs (as it happens with BlueCompute sample application).

## Scalability and Performance considerations

Adding resilience usually implies having redundant deployments, such redundancy can be used also to improve performance and scalability. That is true for the Active/Active case, described in the above section.
In case of global applications, it is possible to redirect users' transactions to the closest location (to improve response time and latency) by using Global Routing solutions (like Akamai or Dyn).

## Resiliency in BlueCompute
BlueCompute sample application is designed to provide HA when running in single location, in fact both Inventory and Social Review Microservices are hosted in Docker groups. IBM Container services provides a continous monitoring of those groups and in case of problems (or increased demand) it will take care of standing up new containers in the group.

Something similar happens with Inventory-BFF and Scovial-BFF services through BlueMix Autoscaling Service.

More information about mechanism available in Bluemix for HA are available at this [link](BMX_HA.md)

For what concerns DR, we designed BlueCompute to provide __Active/Active__ capabilities because this is the most typical scenario for modern applications to which we demand 99.999% availability and extraordinary  levels of scalability.

The Diagram below shows the DR topology for BlueCompute solution in Bluemix.  

 ![Architecture](DR-Active-Active.png?raw=true)

Much of the guidance comes from this [article.](https://www.ibm.com/developerworks/cloud/library/cl-high-availability-and-disaster-recovery-in-bluemix-trs/index.html)


## Implementing Active/Active DR for BlueCompute
In this section you find the step by step guide that will help you in the implementation of the ACive/Active DR solution for BlueCompute.

The main steps are the following:  

1. __Deploy BlueCompute to a new Bluemix region__ Assuming you have already deployed BlueCompute to Bluemix US Central region, you can deploy a new instance in Bluemix EU-GB region by following instructions at this [link](https://github.com/ibm-cloud-architecture/refarch-cloudnative). It is strongly recommended to keep same naming conventions between the two deployments (Bluemix spaces, Application names, Docker container names, etc. ). Important: it's mandatory to keep the same Org name and the same Catalog name when configuring APIC catalog.  

2. __Configure Database Replication__  for both MySQL and Cloudant DB as the described in the documents available at the links below:

 * [Replicating MySQL](./mysql/README.md)

 * [Replicating with Cloudant](./cloudant/README.md)

3. __Configure load Balancer__ In order to have a reliable load balancing solution to route calls to IBM API Connect we recommend the usage of commercial solutions like Akamai Global Transaction Manager or Dyn for production environments. However for development (or Proof Of Concept) environments, it is also possible to use cheaper solutions like NGINX. Consider that in this case NGINX is a Single Point Of Failure (SPOF). In order to setup NGINX you have to:  
  * [Build NGINX Container](https://github.com/ibm-cloud-architecture/refarch-cloudnative-nginx)
  * Start the container in IBM Bluemix container service
  * Note down the IP address of BlueCompute NGINX Docker container
  * Optionally define a DNS for BlueCompute NGINX

4. Align APIC settings across sites
5. Configure BlueCompute Web Application and Mobile Application to point to the Load Balancer in front of the two APIC instances.
6. Test availability of the app. Test should include the bringing offline APIC service in one location.
  
