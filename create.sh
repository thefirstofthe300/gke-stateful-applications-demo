#!/bin/bash -e

# Copyright 2018 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# "---------------------------------------------------------"
# "-                                                       -"
# "-  Create starts a GKE Cluster and installs             -"
# "-  a Cassandra StatefulSet                              -"
# "-                                                       -"
# "---------------------------------------------------------"

set -o errexit
set -o nounset
set -o pipefail

ROOT=$(dirname "${BASH_SOURCE[0]}")
CLUSTER_NAME=""
ZONE=""
GKE_VERSION=$(gcloud container get-server-config \
  --format="value(validMasterVersions[0])")

# shellcheck disable=SC1090
source "$ROOT"/common.sh


if [[ "$(gcloud services list --format='value(serviceConfig.name)' \
                              --filter='serviceConfig.name:container.googleapis.com' 2>&1)" != \
                              'container.googleapis.com' ]]; then
  echo "Enabling the Kubernetes Engine API"
  gcloud services enable container.googleapis.com
else
  echo "The Kubernetes Engine API is already enabled"
fi

echo "Creating cluster"
# Turn off annoying messages
gcloud config set container/new_scopes_behavior true > /dev/null
# Create a GKE cluster
# Using beta as taints are in beta
gcloud beta container clusters create "$CLUSTER_NAME" \
  --zone "$ZONE" \
  --cluster-version "$GKE_VERSION" \
  --machine-type "n1-standard-4" \
  --num-nodes=3 \
  --node-taints app=cassandra:NoSchedule \
  --enable-network-policy \
  --enable-ip-alias

# Get the kubectl credentials for the GKE cluster.
gcloud container clusters get-credentials "$CLUSTER_NAME" --zone "$ZONE"

# Create cassandra cluster using the manifests in the 'manifests' directory.
kubectl create -f "$ROOT"/manifests

# Create new nodepool that will not schedule Cassandra Pods
# We create the nodepool after the kubectl command because this may cause
# the control plane to be upgraded.
gcloud container node-pools create nodepool-cassdemo-2 \
  --zone "$ZONE" \
  --cluster "$CLUSTER_NAME"
