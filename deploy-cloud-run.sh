#!/bin/bash

# Copyright 2023 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -e

pushd ./cloud-run

export PROJECT_ID="$(gcloud config get project)"

if [ -z "${KEYCLOAK_URL}" ] ; then
  echo "KEYCLOAK_URL is required"
  exit 1
fi

export KEYCLOAK_ADMIN=${KEYCLOAK_ADMIN:-admin}
export KEYCLOAK_ADMIN_PASSWORD_SECRET=${KEYCLOAK_ADMIN_PASSWORD_SECRET:-keycloak-admin-password}

export KEYCLOAK_ADMIN_REALM=${KEYCLOAK_ADMIN_REALM:-master}
export KEYCLOAK_APIGEE_REALM=${KEYCLOAK_APIGEE_REALM:-apigee}


if [ -z "${PROJECT_ID}" ] ; then
  echo "No project detected. Run: gcloud config set project ..."
  exit 1
fi


if ! gcloud secrets versions describe latest --secret="${KEYCLOAK_ADMIN_PASSWORD_SECRET}" 1> /dev/null ; then
  echo "could not find keycloak admin password secret"
  exit 1
fi

export REGION=${REGION:-northamerica-northeast1}

gcloud services enable \
  --quiet \
  eventarc.googleapis.com \
  artifactregistry.googleapis.com \
  run.googleapis.com \
  cloudbuild.googleapis.com \
  artifactregistry.googleapis.com \
  secretmanager.googleapis.com \
  --project "${PROJECT_ID}"


gcloud run deploy apigee-app-sync \
 --quiet \
 --execution-environment=gen2 \
 --service-account="apigee-app-sync@${PROJECT_ID}.iam.gserviceaccount.com" \
 --port 8080 \
 --timeout 3600 \
 --region="${REGION}" \
 --set-secrets="KEYCLOAK_ADMIN_PASSWORD=${KEYCLOAK_ADMIN_PASSWORD_SECRET}:latest" \
 --set-env-vars="KEYCLOAK_URL=${KEYCLOAK_URL},KEYCLOAK_ADMIN=${KEYCLOAK_ADMIN},KEYCLOAK_ADMIN_REALM=${KEYCLOAK_ADMIN_REALM},KEYCLOAK_APIGEE_REALM=${KEYCLOAK_APIGEE_REALM}" \
 --source=.


# App creation trigger
gcloud eventarc triggers create apigee-app-sync-trigger-create-app \
 --location=global \
 --service-account="apigee-app-sync@${PROJECT_ID}.iam.gserviceaccount.com" \
 --destination-run-service=apigee-app-sync \
 --destination-run-region="${REGION}" \
 --destination-run-path="/" \
 --event-filters="type=google.cloud.audit.log.v1.written" \
 --event-filters="serviceName=apigee.googleapis.com" \
 --event-filters="methodName=google.cloud.apigee.v1.DeveloperApps.CreateDeveloperApp"

# App Key creation trigger
gcloud eventarc triggers create apigee-app-sync-trigger-create-app-key \
 --location=global \
 --service-account="apigee-app-sync@${PROJECT_ID}.iam.gserviceaccount.com" \
 --destination-run-service=apigee-app-sync \
 --destination-run-region="${REGION}" \
 --destination-run-path="/" \
 --event-filters="type=google.cloud.audit.log.v1.written" \
 --event-filters="serviceName=apigee.googleapis.com" \
 --event-filters="methodName=google.cloud.apigee.v1.DeveloperAppKeys.CreateDeveloperAppKey"

# App update trigger
gcloud eventarc triggers create apigee-app-sync-trigger-update-app \
 --location=global \
 --service-account="apigee-app-sync@${PROJECT_ID}.iam.gserviceaccount.com" \
 --destination-run-service=apigee-app-sync \
 --destination-run-region="${REGION}" \
 --destination-run-path="/" \
 --event-filters="type=google.cloud.audit.log.v1.written" \
 --event-filters="serviceName=apigee.googleapis.com" \
 --event-filters="methodName=google.cloud.apigee.v1.DeveloperApps.UpdateDeveloperApp"

# App Key update trigger
 gcloud eventarc triggers create apigee-app-sync-trigger-update-app-key \
  --location=global \
  --service-account="apigee-app-sync@${PROJECT_ID}.iam.gserviceaccount.com" \
  --destination-run-service=apigee-app-sync \
  --destination-run-region="${REGION}" \
  --destination-run-path="/" \
  --event-filters="type=google.cloud.audit.log.v1.written" \
  --event-filters="serviceName=apigee.googleapis.com" \
  --event-filters="methodName=google.cloud.apigee.v1.DeveloperAppKeys.UpdateDeveloperAppKey"

