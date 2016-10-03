#!/bin/bash


. common.sh

source_db=$1
target_db=$2

if [ -z "${source_db}" ]; then
    echo "usage: $0 <source db> [<target_db>]"
    exit 1
fi

if [ -z "${target_db}" ]; then
    target_db=${source_db}
fi

### check that cf login has been called
check_cf_login

if [ -z "${cloudant_host_target}" -o \
     -z "${cloudant_username_target}" -o \
     -z "${cloudant_password_target}" ]; then

    echo "Please set the following environment variables before script execution: cloudant_host_target, cloudant_username_target, cloudant_password_target."
    echo "You may source \"get_cloudant_cred.sh\" while logged into the target BlueMix instance to export the required variables into the current environment."
    exit 1
fi

get_cloudant_creds source

if [ "${cloudant_host_source}" == "${cloudant_host_target}" ]; then
    echo "Source and target appear to be the same.  Exiting"
    exit 1
fi

# now try to set up the replication!
read -r src_replication_json <<EOF
{ "source" : "https://${cloudant_username_source}:${cloudant_password_source}@${cloudant_host_source}/${source_db}", "target" : "https://${cloudant_username_target}:${cloudant_password_target}@${cloudant_host_target}/${target_db}", "create_target": true, "continuous" : true }
EOF

read -r dst_replication_json <<EOF
{ "source" : "https://${cloudant_username_target}:${cloudant_password_target}@${cloudant_host_target}/${target_db}", "target" : "https://${cloudant_username_source}:${cloudant_password_source}@${cloudant_host_source}/${source_db}", "continuous" : true }
EOF

echo "Replicating from ${cloudant_host_source}/${source_db} to ${cloudant_host_target}/${target_db} ..."
echo "${src_replication_json}" | curl -X POST -H 'Content-Type: application/json' -d@- https://${cloudant_username_source}:${cloudant_password_source}@${cloudant_host_source}/_replicate/

echo "Replicating from ${cloudant_host_target}/${target_db} to ${cloudant_host_source}/${source_db} ..."
echo "${dst_replication_json}" | curl -X POST -H 'Content-Type: application/json' -d@- https://${cloudant_username_target}:${cloudant_password_target}@${cloudant_host_target}/_replicate/
