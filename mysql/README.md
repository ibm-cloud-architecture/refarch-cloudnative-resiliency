###### refarch-cloudnative-resiliency

This database will be managed by refarch-cloudnative-micro-inventory microservice.


### Set up VPN Service in two IBM Bluemix regions

1. Create VPN service in one IBM Bluemix region, for example, US South.

2. Under Manage, add a new Gateway Appliance.  Ensure that the destination consists of all single containers and all scalable groups.  Note the IP Address of the Gateway Appliance.

   If desired, the IKE and IPSec Policies can be updated, but the defaults should be fine.

3. Using the CF CLI, login to the other IBM Bluemix region, for example, United Kingdom (https://api.eu-gb.bluemix.net).
    ```
    # cf login -a <bluemix-api-endpoint> -u <your-bluemix-user-id>
    ```

4. Set target to use your Bluemix Org and Space.
    ```
    # cf target -o <your-bluemix-org> -s <your-bluemix-space>
    ```

5. Log in to IBM Containers plugin.
    ```
    # cf ic login
    ```

6. Remove the default container network and recreate it with a different subnet than the default 172.31.0.0/16 to avoid overlap with the subnet in the other bluemix region
    ```
    # cf ic network rm default
    # cf ic network create --name=default --subnet 172.32.0.0/16
    ```

7. In the bluemix console, create the VPN Service for the second Bluemix region.

8. Under Manage, add a new Gateway Appliance.  Ensure that the destination consists of all single containers and scalable groups, with the updated subnet 172.32.0.0/16.  Note the IP address of this gateway appliance.

   If the IKE and IPSec policies were modified in step 2, ensure that they match in the second Bluemix region.

9. In the first Bluemix region, under VPN Service, Create a Connection for the gateway appliance.  Enter a preshared key string, and ensure that Customer Gateway IP is the IP address of the Gateway Appliance of the second Bluemix region.  Ensure the Customer Subnet is the subnet created in the secondary Bluemix Region (172.32.0.0/16).  Expand the Advanced Settings and ensure "Action on dead peer" is "restart" so this side of the connection re-initiates the connection when it detects the dead peer.  The remaining settings can be left as default.

10. In the second Bluemix region, under VPN Service, Create a Connection for the gateway appliance.  Enter the same preshared key string as entered in the above step, and ensure the Customer Gateway IP is the IP address of the Gateway appliance in the first Bluemix region.  Ensure the Customer Subnet is the subnet of the first Bluemix region (172.31.0.0/16).  Expand the Advanced settings and ensure "Action on dead peer" is "restart-by-peer".  The remaining settings can be left as default.

11.  Verify that both sides of the connection appear as "ACTIVE".

### Setup Master Inventory Database in IBM Bluemix container in first IBM Bluemix region
1. Clone git repository.
    ```
    # git clone https://github.com/ibm-cloud-architecture/refarch-cloudnative-resiliency.git
    # cd refarch-cloudnative-resiliency/mysql
    ```

2. Build docker image using the Dockerfile from repo.
    ```
    # docker build -t cloudnative/mysql .
    ```

3. Log in to your Bluemix account.
    ```
    # cf login -a <bluemix-api-endpoint> -u <your-bluemix-user-id>
    ```

4. Set target to use your Bluemix Org and Space.
    ```
    # cf target -o <your-bluemix-org> -s <your-bluemix-space>
    ```

5. Log in to IBM Containers plugin.
    ```
    # cf ic login
    ```

6. Tag and push mysql database server image to your Bluemix private registry namespace.  In this example we deploy the master to US South region (registry.ng.bluemix.net).
    ```
    # docker tag cloudnative/mysql registry.ng.bluemix.net/$(cf ic namespace get)/mysql:cloudnative
    # docker push registry.ng.bluemix.net/$(cf ic namespace get)/mysql:cloudnative
    ```

7. Create MySQL container with database `inventorydb`.  This database can be connected at `<docker-host-ipaddr/hostname>:3306` as `dbuser` using `Pass4dbUs3R`.  Ensure that SERVER_ID is 1.
    
    _It is recommended to change the default passwords used here._
    ```
    # cf ic run -m 512 --name mysql -p 3306:3306 -e MYSQL_ROOT_PASSWORD=Pass4Admin123 -e MYSQL_USER=dbuser -e MYSQL_PASSWORD=Pass4dbUs3R -e MYSQL_DATABASE=inventorydb -e SERVER_ID=1 registry.ng.bluemix.net/$(cf ic namespace get)/mysql:cloudnative
    ```

8. Create `items` table and load sample data. You should see message _Data loaded to inventorydb.items._
    ```
    # cf ic exec -it mysql sh /root/scripts/load-data.sh
    ```

9. Verify, there should be 12 rows in the table.
    ```
    # cf ic exec -it mysql bash
    # mysql -u ${MYSQL_USER} -p${MYSQL_PASSWORD} ${MYSQL_DATABASE}
    mysql> select * from items;
    mysql> quit
    # exit
    ```
   
Master Inventory database is now setup in IBM Bluemix Container. 

### Setup Slave Inventory Database in IBM Bluemix container in second IBM Bluemix region
1. Log in to your Bluemix account to the second bluemix endpoint.  For example, United Kingdom is https://api.eu-gb.bluemix.net.
    ```
    # cf login -a <bluemix-api-endpoint> -u <your-bluemix-user-id>
    ```

2. Set target to use your Bluemix Org and Space.
    ```
    # cf target -o <your-bluemix-org> -s <your-bluemix-space>
    ```

3. Log in to IBM Containers plugin.
    ```
    # cf ic login
    ```

4. Tag and push mysql database server image to your Bluemix private registry namespace.  In this example we deploy the slave to United Kingdom region (registry.eu-gb.bluemix.net).
    ```
    # docker tag cloudnative/mysql registry.eu-gb.bluemix.net/$(cf ic namespace get)/mysql:cloudnative
    # docker push registry.eu-gb.bluemix.net/$(cf ic namespace get)/mysql:cloudnative
    ```

5. Create MySQL container with database `inventorydb`.  This database can be connected at `<docker-host-ipaddr/hostname>:3306`.  The user will be replicated, so there is no need to create the user here.  Ensure that SERVER_ID is set to some unique number (not 1).
    
    _It is recommended to change the default passwords used here._
    ```
    # cf ic run -m 512 --name mysql-slave -p 3306:3306 -e MYSQL_ROOT_PASSWORD=Pass4Admin123 -e MYSQL_DATABASE=inventorydb -e SERVER_ID=2 registry.eu-gb.bluemix.net/$(cf ic namespace get)/mysql:cloudnative
    ```

Slave Inventory database is now setup in IBM Bluemix Container. 

### Setup slave host replication on the Master Container
1. Log in to your Bluemix account to the second bluemix endpoint.  For example, United Kingdom is https://api.eu-gb.bluemix.net.
    ```
    # cf login -a <bluemix-api-endpoint> -u <your-bluemix-user-id>
    ```

2. Set target to use your Bluemix Org and Space.
    ```
    # cf target -o <your-bluemix-org> -s <your-bluemix-space>
    ```

3. Log in to IBM Containers plugin.
    ```
    # cf ic login
    ```

4. Discover the hostname and IP address of the slave container using the following commands:
    ```
    # cf ic exec mysql-slave hostname
    # cf ic inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' mysql-slave
    ```

5. Log in to the Bluemix account to the first bluemix endpoint where the master container is.  For example, US South is https://api.ng.bluemix.net.
    ```
    # cf login -a <bluemix-api-endpoint> -u <your-bluemix-user-id>
    ```

6. Set target to use your Bluemix Org and Space.
    ```
    # cf target -o <your-bluemix-org> -s <your-bluemix-space>
    ```

7. Log in to IBM Containers plugin.
    ```
    # cf ic login
    ```

8. Run the following script to allow the replication user to replicate data from the slave container
    ```
    # cf ic exec mysql sh /root/scripts/add_repl_slave.sh <slave-hostname> <slave-ip>
    ```

### Setup slave host replication on the slave Container
1. Log in to your Bluemix account to the first bluemix endpoint.  For example, US South is https://api.ng.bluemix.net.
    ```
    # cf login -a <bluemix-api-endpoint> -u <your-bluemix-user-id>
    ```

2. Set target to use your Bluemix Org and Space.
    ```
    # cf target -o <your-bluemix-org> -s <your-bluemix-space>
    ```

3. Log in to IBM Containers plugin.
    ```
    # cf ic login
    ```

4. Discover the hostname and IP address of the master container using the following commands:
    ```
    # cf ic exec mysql hostname
    # cf ic inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' mysql
    ```

5. Log in to the Bluemix account to the first bluemix endpoint where the slave container is.  For example, United Kingdom is https://api.eu-gb.bluemix.net.
    ```
    # cf login -a <bluemix-api-endpoint> -u <your-bluemix-user-id>
    ```

6. Set target to use your Bluemix Org and Space.
    ```
    # cf target -o <your-bluemix-org> -s <your-bluemix-space>
    ```

7. Log in to IBM Containers plugin.
    ```
    # cf ic login
    ```

8. Run the following script to allow the replication user to replicate data from the slave container
    ```
    # cf ic exec mysql-slave sh /root/scripts/add_repl_master.sh <master-hostname> <master-ip>
    ```

9. Use the following commands to verify that replication is successful.
    ```
    # cf ic exec -it mysql-slave bash
    # mysql -u ${MYSQL_USER} -p${MYSQL_PASSWORD} ${MYSQL_DATABASE}
    mysql> show slave status\G;
    ```

    Also, verify that the items table was created successfully
    ```
    # cf ic exec -it mysql-slave bash
    # mysql -u ${MYSQL_USER} -p${MYSQL_PASSWORD} ${MYSQL_DATABASE}

    mysql> select * from items;
    mysql> quit
    # exit
    ```

The inventory database is now replicated in a second BlueMix instance.
