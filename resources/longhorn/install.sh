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

set -eEuo pipefail
set -m

if [[ "${TRACE:-0}" == "1" ]]; then
    set -x
fi

VERSION="${VERSION:-v1.7.1}"

# Install dependencied and check
curl -sSfL -o longhornctl https://github.com/longhorn/cli/releases/download/"${VERSION}"/longhornctl-linux-arm64

chmod +x longhornctl
./longhornctl install preflight
./longhornctl check preflight

# Deploy
kubectl apply -f https://raw.githubusercontent.com/longhorn/longhorn/"${VERSION}"/deploy/longhorn.yaml

# Create basic auth secret to access UI
USER=admin ; PASSWORD=$(pwgen 8 1) ; echo "${USER}:$(openssl passwd -stdin -apr1 <<< ${PASSWORD})" >> resources/longhorn/auth
echo "${PASSWORD}" > resources/longhorn/password
echo ""
echo "The password to access Longhorn UI is: ${PASSWORD}"
echo ""

kubectl -n longhorn-system create secret generic basic-auth --from-file=resources/longhorn/auth

# Deploy ingress to allow access UI
kubectl -n longhorn-system apply -f resources/longhorn/longhorn-ingress.yaml


