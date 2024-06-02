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

BASE_DIR=$(realpath "$(dirname "$0")")
VERSION=${VERSION:-"v3.27.3"}

kubectl create -f "https://raw.githubusercontent.com/projectcalico/calico/${VERSION}/manifests/tigera-operator.yaml"
kubectl create -f "${BASE_DIR}/custom-resources.yaml"
