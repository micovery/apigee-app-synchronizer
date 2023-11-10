FROM golang:1.21.4

# Copyright 2023 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http:#www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

WORKDIR /app
COPY . .

# ENV VARS
# KEYCLOAK_URL
# KEYCLOAK_ADMIN
# KEYCLOAK_ADMIN_PASSWORD
# KEYCLOAK_ADMIN_REALM
# KEYCLOAK_APIGEE_REALM

RUN go mod download
RUN go build -o /app_sync ./cmd/app_sync/

EXPOSE 8080

CMD [ "/app_sync" ]