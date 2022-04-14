#!/bin/bash

echo "Running FOSSA scan"
mkdir -p ${CI_PROJECT_DIR}/oss-results
export FOSSA_API_KEY=$fossa_api_key
cd ${CI_PROJECT_DIR}/linux_x86_64
fossa analyze --debug -p ${CI_PROJECT_URL} -b ${CI_COMMIT_REF_NAME} &> ${CI_PROJECT_DIR}/oss-results/fossa_analyze.txt
fossa analyze -p ${CI_PROJECT_URL} -b ${CI_COMMIT_REF_NAME}
cd ${CI_PROJECT_DIR}/darwin_x86_64
fossa analyze --debug -p ${CI_PROJECT_URL} -b ${CI_COMMIT_REF_NAME} &> ${CI_PROJECT_DIR}/oss-results/fossa_analyze.txt
fossa analyze -p ${CI_PROJECT_URL} -b ${CI_COMMIT_REF_NAME}
cd ${CI_PROJECT_DIR}/windows_x86_64
fossa analyze --debug -p ${CI_PROJECT_URL} -b ${CI_COMMIT_REF_NAME} &> ${CI_PROJECT_DIR}/oss-results/fossa_analyze.txt
fossa analyze -p ${CI_PROJECT_URL} -b ${CI_COMMIT_REF_NAME}
#Onboard any new users
curl --request POST --form token=${CI_JOB_TOKEN} --form ref=main \
     --form "variables[gitlab_id]=${CI_PROJECT_ID}" --form "variables[gitlab_repo]=${CI_PROJECT_URL}" \
     "https:///cd.splunkdev.com/api/v4/projects/14321/trigger/pipeline" 2>&1
#FOSSA test
cd ${CI_PROJECT_DIR}
fossa test -p ${CI_PROJECT_URL}  &> ${CI_PROJECT_DIR}/oss-results/fossa_test.txt
sleep 1m
cd "/whitesource/scripts"
python3 alert_mode.py --fossa_api_key $fossa_api_key --gitlab_repo ${CI_PROJECT_URL}
mv *.log ${CI_PROJECT_DIR}/oss-results/


