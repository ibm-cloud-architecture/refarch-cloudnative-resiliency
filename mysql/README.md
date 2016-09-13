###### refarch-cloudnative-resiliency

This database will be managed by refarch-cloudnative-micro-inventory microservice.

Initially, follow the steps here to deploy the inventory database to a container in IBM BlueMix:
https://github.com/ibm-cloud-architecture/refarch-cloudnative-mysql

This database will be located in the primary BlueMix region.  In this README a secondary BlueMix region is utilized as a disaster recovery site for the MySQL database.

### Set up VPN Service in two IBM BlueMix regions

1. Create VPN service in the primary IBM BlueMix region, for example, US South.

2. Under Manage, add a new Gateway Appliance.  Ensure that the destination consists of all single containers and all scalable groups.  Note the IP Address of the Gateway Appliance.

   If desired, the IKE and IPSec Policies can be updated, but the defaults should be fine.

3. Using the CF CLI, login to the other IBM BlueMix region, for example, United Kingdom (https://api.eu-gb.bluemix.net).
    ```
    # cf login -a <bluemix-api-endpoint> -u <your-bluemix-user-id>
    ```

4. Set target to use your BlueMix Org and Space.
    ```
    # cf target -o <your-bluemix-org> -s <your-bluemix-space>
    ```

5. Log in to IBM Containers plugin.
    ```
    # cf ic login
    ```

6. Remove the default container network and recreate it with a different subnet than the default 172.31.0.0/16 to avoid overlap with the container subnet in the primary BlueMix region.
    ```
    # cf ic network rm default
    # cf ic network create --name=default --subnet 172.32.0.0/16
    ```

7. In the BlueMix console, create the VPN Service for the secondary BlueMix region.

8. Under Manage, add a new Gateway Appliance.  Ensure that the destination consists of all single containers and scalable groups, with the updated subnet 172.32.0.0/16.  Note the IP address of this gateway appliance.

   If the IKE and IPSec policies were modified in step 2, ensure that they match in the secondary BlueMix region.

9. In the primary BlueMix region, under VPN Service, `Create a Connection` for the gateway appliance.  
    - Enter a preshared key string, at least 8 characters.
    - Ensure that Customer Gateway IP is the IP address of the Gateway Appliance of the secondary BlueMix region.  
    - Ensure the Customer Subnet is the subnet created in the secondary BlueMix Region (e.g. 172.32.0.0/16).  
    - Expand the Advanced Settings and ensure "Action on dead peer" is "restart" so this side of the connection re-initiates the connection when it detects the dead peer.  
    - The remaining settings can be left as default.

10. In the secondary BlueMix region, under VPN Service, `Create a Connection` for the gateway appliance.  
    - Enter the same preshared key string as entered in the above step 
    - Ensure the Customer Gateway IP is the IP address of the Gateway appliance in the primary BlueMix region.  
    - Ensure the Customer Subnet is the container subnet of the primary BlueMix region (e.g. 172.31.0.0/16).  
    - Expand the Advanced settings and ensure "Action on dead peer" is "restart-by-peer", so the secondary region waits for the primary region to restart the connection when it detects the dead peer.  
    - The remaining settings can be left as default.

11.  Verify that both sides of the connection appear as "ACTIVE".

### Setup Slave Inventory Database in IBM BlueMix container in secondary IBM BlueMix region
1. Log in to your BlueMix account to the secondary BlueMix region API endpoint.  For example, United Kingdom is https://api.eu-gb.bluemix.net.
    ```
    # cf login -a <bluemix-api-endpoint> -u <your-bluemix-user-id>
    ```

2. Set target to use your BlueMix Org and Space.
    ```
    # cf target -o <your-bluemix-org> -s <your-bluemix-space>
    ```

3. Log in to IBM Containers plugin.
    ```
    # cf ic login
    ```

4. Tag and push mysql database server image to your BlueMix private registry namespace.  In this example we deploy the slave to United Kingdom region (registry.eu-gb.bluemix.net).
    ```
    # docker tag cloudnative/mysql registry.eu-gb.bluemix.net/$(cf ic namespace get)/mysql:cloudnative
    # docker push registry.eu-gb.bluemix.net/$(cf ic namespace get)/mysql:cloudnative
    ```

5. Create MySQL container with database `inventorydb`.  The database user will be replicated, so there is no need to create the user here.  Ensure that SERVER_ID is set to a number other than 1, as this is what the primary MySQL server is set to.
    
    _It is recommended to change the default passwords used here._
    ```
    # cf ic run -m 512 --name mysql-slave -p 3306:3306 -e MYSQL_ROOT_PASSWORD=Pass4Admin123 -e MYSQL_DATABASE=inventorydb -e SERVER_ID=2 registry.eu-gb.bluemix.net/$(cf ic namespace get)/mysql:cloudnative
    ```

Slave Inventory database is now setup in an IBM BlueMix Container in the secondary BlueMix region. 

### Setup slave host replication on the Master Container
1. Log in to your BlueMix account to the secondary BlueMix API endpoint.  For example, United Kingdom is https://api.eu-gb.bluemix.net.
    ```
    # cf login -a <bluemix-api-endpoint> -u <your-bluemix-user-id>
    ```

2. Set target to use your BlueMix Org and Space.
    ```
    # cf target -o <your-bluemix-org> -s <your-bluemix-space>
    ```

3. Log in to IBM Containers plugin.
    ```
    # cf ic login
    ```

4. Discover the hostname and IP address of the slave container using the following commands:
    ```
    # cf ic inspect -f '{{.Config.Hostname}}' mysql-slave
    # cf ic inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' mysql-slave
    ```

5. Log in to the BlueMix account to the primary BlueMix region API endpoint where the master container is.  For example, US South is https://api.ng.bluemix.net.
    ```
    # cf login -a <bluemix-api-endpoint> -u <your-bluemix-user-id>
    ```

6. Set target to use your BlueMix Org and Space.
    ```
    # cf target -o <your-bluemix-org> -s <your-bluemix-space>
    ```

7. Log in to IBM Containers plugin.
    ```
    # cf ic login
    ```

8. Run the following script to allow the replication user to replicate data from the slave container.  This generates a user named `repl` that is authorized to replicate the database.
    ```
    # cf ic exec mysql sh /root/scripts/add_repl_slave.sh --slave-host=<slave-hostname> --slave-ip=<slave-ip>
    ```

    Note the password that it generates for the slave.  If desired, you may generate your own password and pass it in using --repl-passwd=&lt;password&gt;

### Setup slave host replication on the slave Container
1. Log in to your BlueMix account to the primary BlueMix region.  For example, US South is https://api.ng.bluemix.net.
    ```
    # cf login -a <bluemix-api-endpoint> -u <your-bluemix-user-id>
    ```

2. Set target to use your BlueMix Org and Space.
    ```
    # cf target -o <your-bluemix-org> -s <your-bluemix-space>
    ```

3. Log in to IBM Containers plugin.
    ```
    # cf ic login
    ```

4. Discover the hostname and IP address of the master container using the following commands:
    ```
    # cf ic inspect -f '{{.Config.Hostname}}' mysql 
    # cf ic inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' mysql
    ```

5. Log in to the BlueMix account to the secondary BlueMix endpoint where the slave container is.  For example, United Kingdom is https://api.eu-gb.bluemix.net.
    ```
    # cf login -a <bluemix-api-endpoint> -u <your-bluemix-user-id>
    ```

6. Set target to use your BlueMix Org and Space.
    ```
    # cf target -o <your-bluemix-org> -s <your-bluemix-space>
    ```

7. Log in to IBM Containers plugin.
    ```
    # cf ic login
    ```

8. Run the following script to allow the replication user `repl` to replicate data from the slave container.  Note the &lt;repl password&gt; should be the same one passed to the slave container above.
    ```
    # cf ic exec mysql-slave sh /root/scripts/add_repl_master.sh --master-host=<master-hostname> --master-ip=<master-ip> --repl-passwd=<repl password>
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

The inventory database is now replicated to the slave container running in the secondary BlueMix region.
