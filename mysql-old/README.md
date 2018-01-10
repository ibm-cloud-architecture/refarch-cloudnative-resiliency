# MySQL Replication

A MySQL database is used by both [Orders](https://github.com/ibm-cloud-architecture/refarch-cloudnative-micro-orders/tree/kube-int) and [Inventory](https://github.com/ibm-cloud-architecture/refarch-cloudnative-micro-inventory/tree/kube-int) microservices.

MySQL is provisioned using master-master replication across regions.  In this example, we deploy the microservice from the BlueCompute reference application in Kubernetes clusters in two separate Bluemix regions.  We also deploy the associated MySQL databases provisioned in containers with persistent volumes in Kubernetes clusters in each region, dal10 and ams03.

### Setup Database Master-Master replication in IBM Cloud Datacenter(s)

1. Clone the repository

   ```
   # git clone https://github.com/ibm-cloud-architecture/refarch-cloudnative-resiliency
   ```

2. Change directory to the `mysql/chart` folder.

   ```
   # cd mysql/chart
   ```

3. Create a Persistent Volume Claim (PVC) for the MySQL data directory that the container will mount

   ```
   # kubectl create -f mysql-data.yaml
   ```
   
   This creates a Persistent Volume on Bluemix Infrastructure that gets bound to your Kubernetes cluster.  It may take a few minutes for the volume to be provisioned and bound.  You can monitor the progress using:
   
   ```
   # kubectl get pvc mysql-data
   ```
   
   Once it is complete, the status appears as `Bound`.

3. Install the MySQL chart using Helm:

   ```
   # helm init
   # helm install ibmcase-mysql \
       --set mysql.service.type=<service type> \
       --set mysql.dbname=<name of database to create> \
       --set mysql.server_id=<server ID> \
       --set mysql.existingPVCName=mysql-data
   ```
   
   Where:
   - `<service_type>` is one of `NodePort` or `LoadBalancer`.
     - `NodePort` exposes a high-port on the worker nodes that forwards traffic to port `3306` of the MySQL container
     - `LoadBalancer` exposes the MySQL service using an external IP that clients (and replicas) can use to connect to the MySQL container over port 3306.
   - `<server ID>` uniquely identifies the servers.  By default the chart supports up to 4 servers; specify `1`, `2`, `3`, or `4`.  In each region, ensure that the server ID is unique.

   When the chart is installed, the Service resource will be printed to the console which contains either the LoadBalancer IP and/or the exposed NodePort.
   
4. On one replica (e.g. dal10), run the script to create a MySQL account that has `REPLICATION SLAVE` privileges used to synchronize the instance with a remote slave host.

   ```
   # kubectl exec \
       $(kubectl get pods \
         -l chart=ibmcase-mysql-0.1.0 \
         -o go-template \
         --template '{{ (index .items 0).metadata.name }}') -- \
       /scripts/create_repl_user.sh \
       --user=repl \
       --password=replPassw0rd
   ```

	This example creates a user `repl` with password `replPassw0rd` that the remote slave uses to replicate itself.

5. On the other replica (e.g. ams03), run the script to set up the slave host for replication.  

   ```
   # kubectl exec \
       $(kubectl get pods \
         -l chart=ibmcase-mysql-0.1.0 \
         -o go-template \
         --template '{{ (index .items 0).metadata.name }}') -- \
       /scripts/start_replicate.sh \
       --master-host=<master IP> \
       --master-port=<master port> \
       --repl-user=repl \
       --repl-password=replPassw0rd
   ```

6. Reverse the steps to create a replica user (e.g. on ams03), and start the slave (e.g. on dal10).
