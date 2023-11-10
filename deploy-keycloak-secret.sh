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
if [ -z "${KEYCLOAK_ADMIN_PASSWORD}" ] ; then
  echo "KEYCLOAK_ADMIN_PASSWORD is required"
  exit 1
fi

export PROJECT_ID="$(gcloud config get project)"

if [ -z "${PROJECT_ID}" ] ; then
  echo "No project detected. Run: gcloud config set project ..."
  exit 1
fi


gcloud services enable \
  --quiet \
  secretmanager.googleapis.com \
  --project "${PROJECT_ID}"

printf "%s" "${KEYCLOAK_ADMIN_PASSWORD}" | gcloud secrets create keycloak-admin-password --data-file=- --project "${PROJECT_ID}"