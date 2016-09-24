###### refarch-cloudnative-resiliency

This database will be managed by refarch-cloudnative-micro-inventory microservice.

The scripts here use the following git repo to provision docker containers on on-premise resources:
https://github.com/ibm-cloud-architecture/refarch-cloudnative-mysql

The docker containers are provisioned in a master-master replication across regions.  In this example, we deploy the inventory microservice from the BlueCompute reference application in two separate BlueMix regions, which are closest to the on-premise datacenters.   This example uses SoftLayer VMs in dal09 and lon02, with a Vyatta Gateway Appliance as a VPN endpoint.

### Setup Master-Master replication between 

### Set up VPN Tunnel between BlueMix and On-Premise resources

In this section you will establish a secure peer to peer IPsec tunnel between the IBM VPN Service in Bluemix and the Vyatta Gateway Appliance in SoftLayer.

#### Setup IBM VPN Service in Bluemix
1. Create a VPN service instance in Bluemix
   ```
   # cf create-service VPN_Service_Broker Standard My-VPNService
   ```

2. Go to the Bluemix Dashboard. From list of services double-click on `My-VPNService` service to launch the IBM Virtual Private Network dashboard.

3. Click on Create Gateway to create the default gateway. Note down the IP Address of the gateway. In SoftLayer Vyatta configuration when creating the IPsec peer, replace `<BMX-VPN-GW-IP>` with this value.

4. Also note down the Subnets for All Single Containers and All Scalable Groups. In SoftLayer Vyatta configuration when creating the IPsec peer, replace `<BMX-IC-Subnet>` with this value.

#### Setup Vyatta Gateway in SoftLayer
1. Log into the SoftLayer Portal. Place an Order for a Vyatta Gateway Appliance. Note the following hardware specifications are not recommended for a production grade setup, these are minimum specifications to run sample
workloads.

   | Item             | Value                                    |
   |------------------|------------------------------------------|
   | Server           | Single Intel Xeon E3-1270                |
   | RAM              | 4 GB                                     |
   | Operating System | Vyatta 6.x Subscription Edition (64 bit) |
   | Disk             | 1TB JBOD                                 |

2. Go to the Device Details for your MySQL Database server. Disconnect the Public interface, then click on VLAN of the Private interface and note down the VLAN Number.

3. Note down the Subnet at bottom of the page, replace `<Local-Subnet>` with this value in Vyatta configuration. Click on the subnet note down the Gateway address, replace `<vif-gateway>` in Vyatta configuration with this value. Also note down the Mask Bits of the subnet, it is the numeric value after the forward slash (for example /26).

4. SSH into MySQL server and add route to Containers network in Bluemix via
Vyatta Gateway.
    ```
    # ip route add default via <vif-gateway>
    ```

5. After the Vyatta is provisioned, connect to SoftLayer VPN and ssh to the Vyatta using it’s private IP address as user vyatta.

6. Switch to configuration mode and run following commands to add a virtual
interface to route to the VLAN containing MySQL server.
   ```
   $ configure 
   # set interfaces bonding bond0 vif <VLAN-Number> address '169.254.178.90/29' 
   # set interfaces bonding bond0 vif <VLAN-Number> vrrp vrrp-group 2 priority '254' 
   # set interfaces bonding bond0 vif <VLAN-Number> vrrp vrrp-group 2 sync-group 'vgroup1' 
   # set interfaces bonding bond0 vif <VLAN-Number> vrrp vrrp-group 2 virtual-address '<vif-gateway>/<Mask Bits>'
   ```

7. In configuration mode run the following commands to create the IPsec peer.
   ```
   # set vpn ipsec esp-group bmx-esp-default compression 'disable' 
   # set vpn ipsec esp-group bmx-esp-default lifetime '3600' 
   # set vpn ipsec esp-group bmx-esp-default mode 'tunnel' 
   # set vpn ipsec esp-group bmx-esp-default pfs 'dh-group2' 
   # set vpn ipsec esp-group bmx-esp-default proposal 1 encryption 'aes128' 
   # set vpn ipsec esp-group bmx-esp-default proposal 1 hash 'sha1' 
   # set vpn ipsec ike-group bmx-ike-default dead-peer-detection action 'restart' 
   # set vpn ipsec ike-group bmx-ike-default dead-peer-detection interval '20' 
   # set vpn ipsec ike-group bmx-ike-default dead-peer-detection timeout '120' 
   # set vpn ipsec ike-group bmx-ike-default lifetime '86400' 
   # set vpn ipsec ike-group bmx-ike-default proposal 1 dh-group '2' 
   # set vpn ipsec ike-group bmx-ike-default proposal 1 encryption 'aes128' 
   # set vpn ipsec ike-group bmx-ike-default proposal 1 hash 'sha1' 
   # set vpn ipsec ipsec-interfaces interface 'bond1' 
   # set vpn ipsec site-to-site peer <BMX-VPN-GW-IP> authentication mode 'pre-shared-secret' 
   # set vpn ipsec site-to-site peer <BMX-VPN-GW-IP> authentication pre-shared-secret 'sharedsecretstring'
   # set vpn ipsec site-to-site peer <BMX-VPN-GW-IP> connection-type 'initiate' 
   # set vpn ipsec site-to-site peer <BMX-VPN-GW-IP> default-esp-group 'bmx-esp-default' 
   # set vpn ipsec site-to-site peer <BMX-VPN-GW-IP> ike-group 'bmx-ike-default' 
   # set vpn ipsec site-to-site peer <BMX-VPN-GW-IP> local-address '<Vyatta-Public-Address>' 
   # set vpn ipsec site-to-site peer <BMX-VPN-GW-IP> tunnel 1 allow-nat-networks 'disable' 
   # set vpn ipsec site-to-site peer <BMX-VPN-GW-IP> tunnel 1 allow-public-networks 'disable' 
   # set vpn ipsec site-to-site peer <BMX-VPN-GW-IP> tunnel 1 local prefix '<Local-Subnet>' 
   # set vpn ipsec site-to-site peer <BMX-VPN-GW-IP> tunnel 1 remote prefix '<BMX-IC-Subnet>'
   ```

8. Commit and Save the configuration
   ```
   # commit 
   # save
   ```

9. Go to SoftLayer portal, browse to Network > Gateway Appliances. Click on the Vyatta Gateway configured for this setup to launch the Details page.

10. Under the Associate a VLAN, select the VLAN Number saved from step-2 and click on Associate. The VLAN will be added to Associated VLANs.

11.  Under Associated VLANs select the VLAN that was just added. Click on Actions and select Route VLAN. Give it a few minutes for the configuration change to take effect.


#### Create Site Connection in IBM VPN Service in Bluemix

1. Go to the Bluemix Dashboard. From list of services double-click on `My-VPNService` service to launch the IBM Virtual Private Network dashboard.

2. Click on Create Connection to create a new site-to-site connection with the Vyatta Gateway in SoftLayer. Use following values to create a new connection. Accept defaults for other input fields.

   | Name                 | Value                                    |
   |----------------------|------------------------------------------|
   | Preshared Key String | Sharedsecretstring                       |
   | Customer Gateway IP  | `<Vyatta-Public-Address>`                |
   | Customer Subnet      | `<Local-Subnet>` in Vyatta Configuration |

3. Connection should be created with Status ACTIVE.

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
