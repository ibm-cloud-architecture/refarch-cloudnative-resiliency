#!/bin/bash

. common.sh

check_cf_login

get_cloudant_creds $1

echo "cloudant_host_${_id}=${host}"
echo "cloudant_username_${_id}=${username}"
echo "cloudant_password_${_id}=${password}"
