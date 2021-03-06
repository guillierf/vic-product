#!/bin/bash
# Copyright 2016 VMware, Inc. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -x
gsutil version -l
set +x

dpkg -l > package.list

# check parameters
if [ $# -gt 1 ]; then
    echo "Usage: robot-run.sh <test_path>, runs all tests by default if test_path is not passed"
    exit 1
elif [ $# -eq 1 ]; then
    echo "Running specific test $1 ..."
    pybot_options=$1
else
    echo "Running all tests by default ..."
    pybot_options="--removekeywords TAG:secret --exclude skip tests/test-cases"
fi

if [ "${DRONE_BUILD_NUMBER}" -eq 0 ]; then
    # get current date time stamp
    now=`date +%Y-%m-%d.%H:%M:%S`
    # run pybot cmd locally
    echo "Running integration tests locally..."
    pybot -d robot-logs/robot-log-$now $pybot_options
else
    # run pybot cmd on CI
    echo "Running integration tests on CI..."
    pybot $pybot_options

    rc="$?"

    outfile="ova_integration_logs_"$DRONE_BUILD_NUMBER"_"$DRONE_COMMIT".zip"

    zip -9 $outfile output.xml log.html report.html package.list

    # GC credentials
    keyfile="/root/vic-ci-logs.key"
    botofile="/root/.boto"
    echo -en $GS_PRIVATE_KEY > $keyfile
    chmod 400 $keyfile
    echo "[Credentials]" >> $botofile
    echo "gs_service_key_file = $keyfile" >> $botofile
    echo "gs_service_client_id = $GS_CLIENT_EMAIL" >> $botofile
    echo "[GSUtil]" >> $botofile
    echo "content_language = en" >> $botofile
    echo "default_project_id = $GS_PROJECT_ID" >> $botofile

    if [ -f "$outfile" ]; then
      gsutil cp $outfile gs://vic-ci-logs

      echo "----------------------------------------------"
      echo "Download test logs:"
      echo "https://console.cloud.google.com/m/cloudstorage/b/vic-ci-logs/o/$outfile?authuser=1"
      echo "----------------------------------------------"
    else
      echo "No log output file to upload"
    fi

    if [ -f "$keyfile" ]; then
      rm -f $keyfile
    fi

    exit $rc
fi