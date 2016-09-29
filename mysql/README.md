###### refarch-cloudnative-resiliency

This database will be managed by refarch-cloudnative-micro-inventory microservice.

The scripts here use the following git repo to provision docker containers on on-premise resources:
https://github.com/ibm-cloud-architecture/refarch-cloudnative-mysql

The docker containers are provisioned in a master-master replication across regions.  In this example, we deploy the inventory microservice from the BlueCompute reference application in two separate BlueMix regions, which are closest to the on-premise datacenters.   This example uses SoftLayer VMs in dal09 and lon02, with a Vyatta Gateway Appliance as a VPN endpoint.

### Set up VPN Tunnel between BlueMix and On-Premise resources

In this section you will establish a secure peer to peer IPsec tunnel between the IBM VPN Service in Bluemix and the Vyatta Gateway Appliance in SoftLayer.  This must be performed for each of the BlueMix regions hosting the BlueCompute application.

See [VPN Instructions](../VPN.md) on how to proceed


### Setup Inventory Database Master-Master replication in SoftLayer Datacenter(s)

1. Clone the repository
   ```
   # git clone https://github.com/ibm-cloud-architecture/refarch-cloudnative-resiliency
   ```

2.  Update the environment 
   ```
   # cd mysql
   ```
   
   Update env.sh.  Make sure one site is `SITE_MASK=0` and one site is `SITE_MASK=1`.  you may want to also label the sites uniquely.  In our example, SITE 0 is `dal09` and SITE 1 is `lon02`

   e.g.:
   ```
   SITE_MASK=0
   SITE="dal09"
   ```

   ```
   SITE_MASK=1
   SITE="lon02"
   ```


3. Ensure that each site resolves their hostname to the primary external IP that MySQL will be listening on.  The script uses the command `hostname -i` to determine this.  If not, add an entry to /etc/hosts so that the output of `hostname -i` contains the correct IP address.


4. In site 1 (dal09), build a master:
   ```
   ./rebuild_master.sh
   ```

   This creates a docker container and creates a credential for replication user.

   At the end, the output appears:
   ```
   Add the following to the environment on a remote master:
   export MASTER_IP=10.121.163.209 
   export MASTER_PORT=3306
   export MASTER_PASSWORD=a0nyp2w0cwMGqOku
   export REPL_USERNAME=repl-dal09
   export REPL_PASSWORD=Vl4O8EupAmZcbTIu

   Use the following login path to log in to the local container:
   export CONTAINER_NAME=mysql-master-dal09
   export SELF_LOGIN_PATH=root_10-121-163-209_3306
   ```

   Cut and paste `export CONTAINER_NAME` and `export SELF_LOGIN_PATH` into current terminal (assuming bash)

   Copy the export statements for `MASTER_IP`, `MASTER_PORT`, `MASTER_PASSWORD`, `REPL_USERNAME`, and `REPL_PASSWORD`

5. In site 2 (lon02),
   - paste the export statements for MASTER_IP, MASTER_PORT, MASTER_PASSWORD, REPL_USERNAME, and REPL_PASSWORD

   - build a second master:
      ```
      ./rebuild_master.sh
      ```

     This builds a second docker container and create a credential for replication user.

   Cut and paste the same two export statements to the current bash console, and copy and paste the `MASTER_*` and `REPL_*` export statements to the dal09 bash console


6. In site 2 (lon02), generate the login-path for the site 1 master using the credentials from site 1 (dal09)
   ```
   # export MASTER_LOGIN_PATH=`./add_login.sh --container-name=${CONTAINER_NAME} --password=${MASTER_PASSWORD} --port=${MASTER_PORT} --host=${MASTER_IP} --user=root`
   ```

   The environment variable `MASTER_LOGIN_PATH` will contain the login-path for the site 2 master, e.g.:
   ```
   root_10-121-163-209_3306
   ```

7. In site 1, generate the login-path for the site 2 master using the credentials from site 2:
   ```
   # export MASTER_LOGIN_PATH=`./add_login.sh --container-name=${CONTAINER_NAME} --password=${MASTER_PASSWORD} --port=${MASTER_PORT} --host=${MASTER_IP} --user=root`
   ```

   The environment variable MASTER_LOGIN_PATH will contain the login-path for the site 2 master, e.g.:
   ```
   root_10-113-180-221_3306
   ```


8. In site 1, start replication from site 2 using the master and slave login paths, and the replication username/password generated for site 2 (all in the environment already):
   ```
   # ./start_replicate.sh --container-name=${CONTAINER_NAME} --master-login-path=${MASTER_LOGIN_PATH} --slave-login-path=${SELF_LOGIN_PATH} --repl-user=${REPL_USERNAME} --repl-password=${REPL_PASSWORD}
   ```

9. In site 2, start replication from site 1 using the master and slave login paths, and the replication username/password generated for site 1 (all in the environment already)
   ```
   # ./start_replicate.sh --container-name=${CONTAINER_NAME} --master-login-path=${MASTER_LOGIN_PATH} --slave-login-path=${SELF_LOGIN_PATH} --repl-user=${REPL_USERNAME} --repl-password=${REPL_PASSWORD}
   ```

10. Check replication health, e.g.:
   ```
   # docker exec -it ${CONTAINER_NAME} mysqlrpladmin --master=${MASTER_LOGIN_PATH} --slave=${SELF_LOGIN_PATH} health
   # Checking privileges.
   #
   # Replication Topology Health:
   +-----------------+-------+---------+--------+------------+---------+
   | host            | port  | role    | state  | gtid_mode  | health  |
   +-----------------+-------+---------+--------+------------+---------+
   | 10.113.180.221  | 3306  | MASTER  | UP     | ON         | OK      |
   | 10.121.163.209  | 3306  | SLAVE   | UP     | ON         | OK      |
   +-----------------+-------+---------+--------+------------+---------+
   # ...done.
   ```

11. Load data on one of the sites:
   ```
   $ docker exec -it ${CONTAINER_NAME} /root/scripts/load-data.sh
   ```


   On the other site, make sure that the "items" table was loaded correctly:
   ```
   $ docker exec -it mysql-master-lon02 mysql --login-path=${SELF_LOGIN_PATH} inventorydb

   mysql> show tables;
   ```


12. Create a database user in one of the sites.  The database user will be replicated, so there is no need to create the user here.  
    
    _It is recommended to change the default passwords used here._
    ```
    # docker exec -it mysql-master-lon02 mysql --login-path=${SELF_LOGIN_PATH} 
    
    mysql> create user 'dbuser'@'%' identified by 'password';
    mysql> grant all on *.* to 'dbuser'@'%';
    mysql> flush privileges;
    ```

#### Start Inventory Microservice on Bluemix

Follow the instructions here:
https://github.com/ibm-cloud-architecture/refarch-cloudnative-micro-inventory

The MySQL database replica is available through the VPN Service.  When specifying the parameters for the database connection, use the following:

```
-e "spring.datasource.url=jdbc:mysql://<MASTER_IP>:<MASTER_PORT>/inventorydb" -e "spring.datasource.username=<dbuser>" -e "spring.datasource.password=<password>"
```
