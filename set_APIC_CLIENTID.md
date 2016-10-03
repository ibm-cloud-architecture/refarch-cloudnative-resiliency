# Set Client ID for APIC Subscription

This section contains instructions to set the same Client ID for APIC subscriptions in both locations.

* __Login to APIC Developer Portal of Site 1 (f.i. US Central) and note down the Client ID for BlueCompute subcription__

  ClientID is a string liek the following : f7c83290-fb40-43e9-9867-e75ac53b052a

* __Get the list of orgs associated to your account__
      curl -X GET --user "<IBMID>:<PASSWORD>" -H 'Content-Type: application/json' https://<APIC Management Server>/v1/portal/orgs -H "X-IBM-APIManagement-Context: <OrgName>.<EnvName>"

    Where OrgName is your Bluemix organization (typically youruser@your.domain) but with no at sign nor dots and Bluemix space, and EnvName in Bluemix is typically Sandbox, the default environment when you create the service.

  __Sample Command__:

      curl -X GET --user "user@us.ibm.com:passw0rd" -H 'Content-Type: application/json' https://developer.eu.apiconnect.ibmcloud.com/v1/portal/orgs -H "X-IBM-APIManagement-Context: centusibmcom-cloudnative-dev.bluecompute"

     The command returns all organizations to which specified user belongs to. Note down the OrgID of the Organization where BlueCompute API are deployed

* __Get the list of Applications associated to your account__

      curl -X GET --user "<IBMID>:<PASSWORD>" -H 'Content-Type: application/json' <APIC Management Server>/v1/portal/orgs/<OrgID>/apps -H "X-IBM-APIManagement-Context: <OrgName>.<EnvName>"

    Where OrgID is the organization ID you have noted down in the step above

    __Sample Command__:

      curl -X GET --user "user@us.ibm.com:passw0rd" -H 'Content-Type: application/json' https://developer.eu.apiconnect.ibmcloud.com/v1/portal/orgs/57e00f650cf2938c939bda2b/apps -H "X-IBM-APIManagement-Context: centusibmcom-cloudnative-dev.bluecompute"

     The command returns all Applications belonging to to specified Organization. Note down the ApplicationID of the Application where BlueCompute API are deployed

* __Set the ClientID.__

      curl -X PUT --user "<IBMID>:<PASSWORD>" -H 'Content-Type: application/json' -d '{ "clientID": <ClientID>, "clientSecret": "", "description": "" }' https://<APIC Management Server>/v1/portal/orgs/<OrgID>/apps/<AppID>/credentials -H "X-IBM-APIManagement-Context: <OrgName>.<EnvName>"

    __Sample Command__:

      curl -X PUT --user "user@us.ibm.com:passw0rd" -H 'Content-Type: application/json' -d '{ "clientID": 3f1b4cc8-78dc-450e-9461-edf377105c7a, "clientSecret": "", "description": "" }' https://developer.eu.apiconnect.ibmcloud.com/v1/portal/orgs/57e00f650cf2938c939bda2b/apps/57e014940cf2938c939be073/credentials -H "X-IBM-APIManagement-Context: centusibmcom-cloudnative-dev.bluecompute"

* __Verify ClientID is correctly set__

      curl -X GET --user "<IBMID>:<PASSWORD>" -H 'Content-Type: application/json'  https://<APIC Management Server>/v1/portal/orgs/<OrgID>/apps/<AppID>/credentials -H "X-IBM-APIManagement-Context: <OrgName>.<EnvName>"

      __Sample Command__:

      curl -X GET --user "user@us.ibm.com:passw0rd" -H 'Content-Type: application/json' https://eu.apiconnect.ibmcloud.com/v1/portal/orgs/57e00f650cf2938c939bda2b/apps/57e014940cf2938c939be073/credentials -H "X-IBM-APIManagement-Context: centusibmcom-cloudnative-dev.bluecompute"
