# Cloudant Database Resiliency

Configure Cloudant replication in a second BlueMix region for disaster recovery.

### Configure Cloudant with Social Review MicroService

Follow the steps to install and configure the Social Reviews microservice in the primary BlueMix Region:
https://github.com/ibm-cloud-architecture/refarch-cloudnative-micro-socialreview

### Set up Cloudant replication using the supplied scripts with the Cloud Foundry CLI and Cloudant REST API

Use the supplied scripts to set up Cloudant replication using the Cloudant REST API.  This assumes that there are already two BlueMix spaces in two different regions.  If following the Social Review microservice steps, one instance should already be created.

1. Login to BlueMix in a secondary region.  For example, if the primary region is US South, use United Kingdom as a backup region.  Use the following link to create an instance in United Kingdom:

   https://new-console.eu-gb.bluemix.net/catalog/services/cloudant-nosql-db

2. Log into one of the BlueMix regions using CLI.  For example, to log in to United Kingdom region, use
   ```
   # cf login -a https://api.eu-gb.bluemix.net
   ```
   
   The `cf api` command will give the output:
   ```
   # cf api
   API endpoint: https://api.eu-gb.bluemix.net (API version: 2.54.0)
   ```
   
3. Source the script to retrieve the Cloudant credentials from BlueMix and export it into the current environment.  This uses the first service credentials returned by the Cloud Foundry CLI for Cloudant.  
   ```
   # source ./get_cloudant_creds.sh
   cloudant_host_target=xxxxxxxx-yyyy-zzzz-aaa-bbbbbbbbbbbb-bluemix.cloudant.com
   cloudant_username_target=xxxxxxxx-yyyy-zzzz-aaa-bbbbbbbbbbbb-bluemix
   cloudant_password_target=7a5c40125d984d86bcf90cc09a2ba0b71d41ec09f0f64676ab14328293339e87
   ```

4. Log in to the BlueMix source instance.  For example, to log in to US South, use the following:
   ```
   # cf login -a https://api.ng.bluemix.net
   ```
   
   The following command should give the output of the API endpoint that the Cloud Foundry CLI is pointing at:
   ```
   #  cf api
   API endpoint: https://api.ng.bluemix.net (API version: 2.54.0)
   ```
   
5. Run the CLI to set up the bidirectional replication.  This command replicates the `socialreviewdb` from the source Cloudant instance to the target and creates the database `socialreviewdb` on the target Cloudant instance if it does not exist already.  It also sets up replication from the target Cloudant instance to the source Cloudant instance.
   ```
   # ./replicate_cloudant.sh  socialreviewdb
   Replicating from cccccccc-dddd-eeee-ffff-gggggggggggg-bluemix.cloudant.com/socialreviewdb to xxxxxxxx-yyyy-zzzz-aaa-bbbbbbbbbbbb-bluemix.cloudant.com/socialreviewdb ...
   {"ok":true,"_local_id":"ad50a742dc69238b700da4729abc3a4e+continuous+create_target"}
   Replicating from xxxxxxxx-yyyy-zzzz-aaa-bbbbbbbbbbbb-bluemix.cloudant.com/socialreviewdb to cccccccc-dddd-eeee-ffff-gggggggggggg-bluemix.cloudant.com/socialreviewdb ...
   {"ok":true,"_local_id":"beba67b459bb72a3c32eb3dd31c30ee1+continuous"}
   ```
   
   The two Cloudant instances should now be replicated in both directions.
    

### Set up Cloudant Replication to a Secondary BlueMix Region Using BlueMix portal

These steps are a duplicate of the above scripts, but using the BlueMix and Cloudant management consoles.

1. Login to BlueMix in a secondary region.  For example, if the primary region is US South, use United Kingdom as a backup region.  Use the following link to create an instance in United Kingdom:

   https://new-console.eu-gb.bluemix.net/catalog/services/cloudant-nosql-db

2. Once created, launch the Cloudant dashboard in the secondary region, and create a database `socialreviewdb` that matches the database in the primary region.

3. In the BlueMix Dashboard in the secondary region, open the Cloudant service and view the Service Credentials.  In particular, copy the what appears in the `url` field.

4. In the primary BlueMix region, open the service page for the Cloudant service
  - Under `Service Credentials`, copy the `password` field.
  - Under `Manage`, launch Cloudant dashboard, and click on `Replication`.  
  - Select `New Replication`.  
  - Leave the `_id` blank.
  - Specify the `Source Database` as `socialreviewdb`.  
  - In the `Target Database`, select `Existing Database`, `Remote Database`, and paste the what appeared under `url` in the credentials of the secondary region.  At the end of the url, add `/socialreviewdb` to specify that the replication should be into the remote socialreviewdb.  
  - Check the box to "Make this replication continuous".  
  - Click on `Replicate Data` to begin the initial replication.  It will ask for the password, enter the password copied from the primary BlueMix region.

6. Repeat the reverse to set up replication from the secondary BlueMix region to the primary BlueMix region.

### Verify replication using the Social Review Microservice

Use the Cloudant API against the secondary BlueMix region to validate that the replication is happening correctly:
```
echo '{"comment":"My second review","itemId":13402,"rating":5,"review_email":"jkwong@ca.ibm.com","reviewer_name":"Jeffrey Kwong","review_date":"09/12/2016"}' | curl -H "Content-type: application/json"  -X POST -d@-  https://<cloudant_user>:<cloudant_password@<cloudant_host>/socialreviewdb
```

Use the social reviews microservice to verify that the new document is replicated to the primary Cloudant database:

```
curl http://<URL>:8080/micro/review
```



### Disaster recovery scenarios

In the case replication gets out of sync (either primary, or secondary), the `Errors` tab in the Cloudant dashboard will have some messages.  This may happen if either the primary or the secondary site becomes unavailable.

If this happens, check the Cloudant dashboard on both primary and secondary BlueMix regions to verify that the databases are up to date.  The sequence numbers under `Update Seq` should match on both Cloudant instances.

If the databases get out of sync, the replication can be re-established by canceling the replication(s) on both sides, deleting the database that has the lower `Update Seq` value, re-creating the empty database, and re-configuring the replication as specified in the above steps.
