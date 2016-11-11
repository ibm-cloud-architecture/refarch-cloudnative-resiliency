# MySQL Cluster Ansible Setup

The code requires one VM or bare metal host per node role in SoftLayer.  Only the SQL Nodes need to be reachable from the container network in BlueMix.

As a review, here is the diagram of the cluster:

![MySQL Cluster](../mysql-cluster.png)

## Cluster node provisioning

Provision VMs for each of the node roles.  The playbook is written for RHEL/CentOS 6.

### Create external volumes (optional)

The /var/lib/mysql directory in each VM can be provisioned as a SAN provisioned disk for resiliency.  If the VM fails, the data is left intact and can be attached to another VM.  Additionally, this data volume may be backed up using a backup service.

To prepare these disks, use parted to prepare the partitions:

```
# parted
> select /dev/xvdc
> mklabel msdos
> mkpart primary ext4 0% 100%
> quit
```

Then, use mkfs.ext4 to create the filesystem:

```
# mkfs.ext4 /dev/xvdc1
```

Then, mount the filesystem to a mountpoint:
```
# mkdir -p /mnt/xvdc1
# mount /dev/xvdc1 /var/lib/mysql
```

## Ansible set up

Ansible works by executing commands over SSH.  As such, you will need to be connected to the SoftLayer private network using the [SSL VPN](https://vpn.softlayer.com) and have passwordless SSH access set up.  It may be helpful to create a VM in SoftLayer on the same subnet as the MySQL cluster to execute the ansible playbook.

### Install Ansible

Install Ansible from [EPEL](https://fedoraproject.org/wiki/EPEL).  If the Ansible playbook is being executed on a VM installed in the SoftLayer private network, SoftLayer maintains an internal mirror of EPEL here: [http://mirror.service.softlayer.com/fedora-epel/6/x86_64/](http://mirror.service.softlayer.com/fedora-epel/6/x86_64/).  Add the repository to yum using the following configuration in /etc/yum.repos.d/epel.repo:

```
# cat /etc/yum.repos.d/epel.repo 
[epel]
name=Extra Packages for Enterprise Linux 6 - $basearch
baseurl=http://mirrors.service.softlayer.com/fedora-epel/6/$basearch
failovermethod=priority
enabled=1
gpgcheck=0
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL-6
```

Install ansible using the following command:
```
# yum install ansible
```

### Set up Ansible host

Create a local SSH key-pair for the Ansible host:

```
# ssh-keygen
```

Distribute the SSH public keys to each of the nodes in the cluster.  When prompted, enter the root password of the VM (it can be retrieved from the SoftLayer portal).

```
# ssh-copy-id root@<hostname>
```

Ensure that all hostnames are resolvable from the Ansible host.  One simple way of doing this is to add IP/hostname entries to `/etc/hosts` on the Ansible.

```
# cat /etc/hosts
127.0.0.1 localhost 

10.121.163.234  mysql-dal09-data01.casenation.poc mysql-dal09-data01
10.121.163.250  mysql-dal09-data02.casenation.poc mysql-dal09-data02
10.121.163.243  mysql-dal09-mgmt.casenation.poc   mysql-dal09-mgmt
10.121.163.194  mysql-dal09-sql01.casenation.poc  mysql-dal09-sql01
10.121.163.226  mysql-dal09-sql02.casenation.poc  mysql-dal09-sql02
```

### Clone the git repository

Clone this repository using this command, and switch to the ansible directory:

```
# git clone https://github.com/ibm-cloud-architecture/refarch-cloudnative-resiliency.git
# cd mysql-cluster/ansible
```

### Update nodes in Ansible hosts file

Update the nodes in each role in the `hosts` file.  If using hostnames, make sure that the Ansible host can resolve all of the hostnames.

The ansible playbook will create one replica per host listed under `datanodes` listed in this file.

e.g.
```
[datanodes]
mysql-dal09-data01
mysql-dal09-data02

[sqlnodes]
mysql-dal09-sql01
mysql-dal09-sql02

[mgmtnodes]
mysql-dal09-mgmt
```

### Update global variables

Update the `site_mask` in the `group_vars/all` file.  This distinguishes the two sites from each other for replication purposes.  For example, dal09 may have `site_mask` set to 0, lon02 may have `site_mask` set to 1, etc.

e.g.
```
---

site_mask: 0
```


### New Relic Agent installation (optional)

New Relic can be used to monitor the SQL nodes.  If a New Relic license key is available, it can be provided as a variable to the ansible playbook in `group_vars/all`:

```
new_relic_license_key: <license key>
```

If the above variable is defined and not empty during execution, the Ansible playbooks will capture the value and configure and start the New Relic Java Agent with the MySQL plugin as the SQL nodes are started.  Note that the MySQL plugin only supports monitoring InnoDB and not NDB so not all metrics regarding MySQL cluster are available.

## Cluster Creation

Execute the Ansible playbook using the following command from the Ansible host:

```
# ansible-playbook -i hosts site.yml
```

This will execute commands and start MySQL cluster on the VMs defined in the `hosts` file.
