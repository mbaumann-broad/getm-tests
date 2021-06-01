#!/usr/bin/env bash

set -eux o pipefail

CURRENT_DIR=$(pwd)

# where all non-getm downloads go (wget, gsutil, and curl)
TMP_DL_DIR=/cromwell_root/speedtest3crdws3s

# google project to bill for the gsutil downloads
GOOGLE_REQUESTER_PAYS_PROJECT=platform-dev-178517

#
# Identify the runtime environment
#

# Check Linux version
cat /etc/issue
uname -a

#
# Commands that could be added to the Dockerfile
#

apt-get update && apt-get install -yq --no-install-recommends apt-utils git jq wget virtualenv python3.8-dev

virtualenv -p python3.8 v38nv
set +u
. v38nv/bin/activate
set -u
# Check that we're really using python3.8
python --version

apt-get -yq --no-install-recommends install python3-pip
python -m pip install --upgrade pip

# Install getm
python -m pip install git+https://github.com/xbrianh/getm
python -m pip show getm

#
# DRS URI download processing
#

# Check available shared memory and disk usage before downloading
df -h

mkdir -p ${TMP_DL_DIR}

# TODO Configure shared memory appropriately, if needed.

# Create a getm manifest for the DRS URIs
wget https://raw.githubusercontent.com/mbaumann-broad/getm-tests/dev/scripts/create_getm_manifest.py
python ./create_getm_manifest.py getm_manifest_filename "drs://dg.4503:dg.4503/15fdd543-9875-4edf-8bc2-22985473dab6" "drs://dg.4503:dg.4503/3c861ec6-d810-4058-b851-c0b19dd5933e" "drs://dg.4503:dg.4503/374a0ad9-b3a2-47f3-8860-5083b302e478"

# GETM DOWNLOAD of the drs uris in the manifest
start_time=`date +%s`
time getm -c -v --manifest getm_manifest_filename
getm_exit_status=$?
echo "Getm exit status: "$getm_exit_status
end_time=`date +%s`
total_time="$(($end_time-$start_time))"
# Check final disk usage after downloading
df -h

# CLEANUP; delete to prepare for the next run
downloaded_files=($(cat getm_manifest_filename | jq -r '.[] .filepath'))
for downloaded_file in ${downloaded_files[@]}; do
    echo ${downloaded_file}
    ls -lha ${downloaded_file}
    rm ${downloaded_file}
done

# WGET DOWNLOAD of the signed URLs in the manifest
start_time=`date +%s`
signed_urls=($(cat getm_manifest_filename | jq -r '.[] .url'))
for signed_url in ${signed_urls[@]}; do
    # this is going to create some crazy truncated names but it shouldn't make a difference in run times
    wget ${signed_url} -P ${TMP_DL_DIR}/
done
end_time=`date +%s`
total_time="$(($end_time-$start_time))"
# Check final disk usage after downloading
df -h

# CLEANUP; delete to prepare for the next run
sudo rm -rf ${TMP_DL_DIR}/*

# CURL DOWNLOAD of the signed URLs in the manifest
cd ${TMP_DL_DIR}
start_time=`date +%s`
signed_urls=($(cat getm_manifest_filename | jq -r '.[] .url'))
for signed_url in ${signed_urls[@]}; do
    # this is going to create some crazy truncated names but it shouldn't make a difference in run times
    curl ${signed_url} -P ${TMP_DL_DIR}/
done
end_time=`date +%s`
total_time="$(($end_time-$start_time))"
# Check final disk usage after downloading
cd ${CURRENT_DIR}
df -h

# CLEANUP; delete to prepare for the next run
sudo rm -rf ${TMP_DL_DIR}/*

# GSUTIL DOWNLOAD of the gs:// URIs in the manifest
start_time=`date +%s`
google_uris=($(cat getm_manifest_filename | jq -r '.[] .gs_uri'))
for google_uri in ${google_uris[@]}; do
    gsutil -u ${GOOGLE_REQUESTER_PAYS_PROJECT} cp ${google_uri} ${TMP_DL_DIR}/
done
end_time=`date +%s`
total_time="$(($end_time-$start_time))"
# Check final disk usage after downloading
df -h

# CLEANUP; final
sudo rm -rf ${TMP_DL_DIR}
