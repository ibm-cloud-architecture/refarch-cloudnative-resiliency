# Connecting Bluemix VPN Service to Bluemix Infrastructure Vyatta Gateway

In the examples shown here, the Bluemix VPN Service is used to connect the container network to Bluemix Infrastructure VMs that represent on-premise resources.  Follow these instructions to set up an IPSec tunnel between Bluemix and a Vyatta Gateway Appliance running in Bluemix Infrastructure.


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

9. Go to Bluemix Infrastructure portal, browse to Network > Gateway Appliances. Click on the Vyatta Gateway configured for this setup to launch the Details page.

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

