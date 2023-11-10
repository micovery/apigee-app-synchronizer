#!/bin/bash

set -e
pushd ./keycloak/terraform

export PROJECT_ID="$(gcloud config get project)"

if [ -z "${PROJECT_ID}" ] ; then
  echo "No project detected. Run: gcloud config set project ..."
  exit 1
fi

export KEYCLOAK_ADMIN=${KEYCLOAK_ADMIN:-admin}
export KEYCLOAK_ADMIN_PASSWORD=${KEYCLOAK_ADMIN_PASSWORD:-SuperSecret123}


if [ -z "${KEYCLOAK_ADMIN_PASSWORD}" ] ; then
  echo "KEYCLOAK_ADMIN_PASSWORD is required"
  exit 1
fi

export REGION=${REGION:-northamerica-northeast1}
export ZONE=${ZONE:-northamerica-northeast1-a}
export VPC_NAME=${VPC_NAME:-demo-net}
export VPC_SUBNET=${VPC_SUBNET:-apigee-snet-na-northeast1}

gcloud auth application-default login

cat << EOF > ./terraform.tfvars
project_id = "${PROJECT_ID}"
region = "${REGION}"
zone ="${ZONE}"
vpc_name = "${VPC_NAME}"
vpc_subnet = "${VPC_SUBNET}"
keycloak_admin = "${KEYCLOAK_ADMIN}"
keycloak_admin_password = "${KEYCLOAK_ADMIN_PASSWORD}"
EOF

terraform apply