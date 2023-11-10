#!/usr/bin/env bash

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

export DEBIAN_FRONTEND=noninteractive

if [ -e /etc/supervisor/conf.d/keycloak.conf ] ; then
  echo "KeyCloak has already been setup ..."
  sudo systemctl restart supervisor
  exit 0
fi

echo "Installing Keycloak dependencies ..."

sudo apt-get update -y
sudo apt-get install -y ca-certificates-java openjdk-19-jre-headless
sudo apt-get install unzip
sudo apt-get install -y supervisor

echo "Downloading Keycloak ..."
wget https://github.com/keycloak/keycloak/releases/download/22.0.5/keycloak-22.0.5.zip
unzip keycloak-22.0.5.zip

sudo mv keycloak-22.0.5 /opt/keycloak
sudo chmod a+rwx -R /opt/keycloak
export PATH=/opt/keycloak/bin:$PATH

echo "Setting up Keycloak ..."
cat << EOF > /opt/keycloak/envvars
export KEYCLOAK_ADMIN="${keycloak_admin}"
export KEYCLOAK_ADMIN_PASSWORD="${keycloak_admin_password}"
EOF


echo "Setting Keycloak in supervisord ..."

cat << EOF | sudo tee /etc/supervisor/conf.d/keycloak.conf
[program:keycloak]
command=/bin/bash -c "source /opt/keycloak/envvars && exec /opt/keycloak/bin/kc.sh start-dev --proxy edge"
autorestart=true
EOF

sudo systemctl restart supervisor
