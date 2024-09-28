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

if [[ $# -lt 1 ]]
then
    echo "Usage: $0 <cluster-token>" >&2
    exit 1
fi

apt install -y curl

K3S_KUBECONFIG_OUTPUT=/root/k3s-kube.config

curl -sfL https://get.k3s.io | \
  K3S_TOKEN=${1} \
  K3S_KUBECONFIG_OUTPUT=${K3S_KUBECONFIG_OUTPUT} \
  INSTALL_K3S_EXEC="server \
  --cluster-init \
  --cluster-cidr=10.42.0.0/16 \
  --disable-cloud-controller \
  --disable-network-policy \
  --disable=traefik \
  --disable=servicelb \
  --flannel-backend=none \
  --log=/var/log/k3s.log" \
  sh -

## Wait before exiting to ensure ${K3S_KUBECONFIG_OUTPUT} file exists and is the latest
if [[ -f ${K3S_KUBECONFIG_OUTPUT} ]]
then
    OLD_CONFIG_TIME=$(ls --full-time --time-style=+%Y%m%d%H%M%S ${K3S_KUBECONFIG_OUTPUT} | awk '{print $6}')
    NEW_CONFIG_TIME=$(ls --full-time --time-style=+%Y%m%d%H%M%S ${K3S_KUBECONFIG_OUTPUT} | awk '{print $6}')
    while [[ "${NEW_CONFIG_TIME}" == "${OLD_CONFIG_TIME}" ]]
    do
        sleep 3
        NEW_CONFIG_TIME=$(ls --full-time --time-style=+%Y%m%d%H%M%S ${K3S_KUBECONFIG_OUTPUT} | awk '{print $6}')
    done
else
    until [[ ! -f ${K3S_KUBECONFIG_OUTPUT} ]]
    do
        sleep 3
    done
fi
