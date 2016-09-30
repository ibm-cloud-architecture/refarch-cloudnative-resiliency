#!/bin/bash

### check that cf login has been called
function check_cf_login() {
    cf target 2>&1 > /dev/null
    if [ $? -ne 0 ]; then
        echo "Please call cf login before executing script."
        exit 1
    fi
}

function get_cloudant_creds() {
    _id=$1

    if [ -z "${_id}" ]; then
        _id="target"
    fi
   
    CLOUDANT_SVC_NAME=`cf services | grep cloudantNoSQLDB | awk '{print $1;}'`
    CLOUDANT_KEY_NAME=`cf service-keys ${CLOUDANT_SVC_NAME} | grep -v "Getting keys" | grep -v '^name$' | grep -v '^$' | head -1`
    
    _cloudant_cred_json=`cf service-key ${CLOUDANT_SVC_NAME} ${CLOUDANT_KEY_NAME} | grep -v 'Getting key' | grep -v '^$'`
    
    host=`echo ${_cloudant_cred_json} | python -c "import sys,json; obj=json.load(sys.stdin); print obj['host']"`
    username=`echo ${_cloudant_cred_json} | python -c "import sys,json; obj=json.load(sys.stdin); print obj['username']"`
    password=`echo ${_cloudant_cred_json} | python -c "import sys,json; obj=json.load(sys.stdin); print obj['password']"`
    
    # take first five chars of hostname
    
    _identifier=`echo "${host}" | head -c5`
    
    export cloudant_host_${_id}=${host}
    export cloudant_username_${_id}=${username}
    export cloudant_password_${_id}=${password}
}
