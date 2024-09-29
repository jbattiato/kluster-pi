#!/bin/env bash

##
## Copyright Jonathan Battiato
##
## Licensed under the Apache License, Version 2.0 (the "License");
## you may not use this file except in compliance with the License.
## You may obtain a copy of the License at
##
##     http://www.apache.org/licenses/LICENSE-2.0
##
## Unless required by applicable law or agreed to in writing, software
## distributed under the License is distributed on an "AS IS" BASIS,
## WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
## See the License for the specific language governing permissions and
## limitations under the License.
##

VERSION=${VERSION:-"v1.15.3"}

# Easy install
kubectl apply -f "https://github.com/cert-manager/cert-manager/releases/download/${VERSION}/cert-manager.yaml"

## Helm install
#
#VERSION=${VERSION:-"v1.14.3"}
#helm repo add jetstack https://charts.jetstack.io
#helm repo update
#kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/"${VERSION}"/cert-manager.crds.yaml
#
#helm install \
#  cert-manager jetstack/cert-manager \
#  --namespace cert-manager \
#  --create-namespace \
#  --version "${VERSION}" \
#  --set prometheus.enabled=false \
#  #--set webhook.timeoutSeconds=4
#  # --set installCRDs=true