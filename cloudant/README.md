# Cloudant Database Resiliency

Configure Cloudant replication in a second BlueMix region for disaster recovery.

### Configure Cloudant with Social Review MicroService

Follow the steps to install and configure the Social Reviews microservice in the primary BlueMix Region:
https://github.com/ibm-cloud-architecture/refarch-cloudnative-micro-socialreview


### Set up Cloudant Replication to a Secondary BlueMix Region

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

5. Start the social review microservice and attempt to write some data to Cloudant using the following cURL command to the microservice:

   ```
   echo '{"comment":"Nice Product","itemId":13402,"rating":5,"review_email":"gangchen@us.ibm.com","reviewer_name":"Gang Chen","review_date":"06/08/2016"}' | curl -H "Content-type: application/json" -X POST -d@- http://<URL>/micro/review
```

6. In the secondary BlueMix region, verify that the review document was replicated to this region with the same id.

### Set up two-way Cloudant Replication 

Repeat the reverse to set up replication from the secondary BlueMix region to the primary BlueMix region.

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
