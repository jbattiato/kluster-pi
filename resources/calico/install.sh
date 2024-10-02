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

VERSION="${VERSION:-v3.27.3}"

set -eEuo pipefail
set -m

if [[ "${TRACE:-0}" == "1" ]]; then
    set -x
fi

usage(){
    echo "Usage: VERSION=<version> MASTER=<address> $0" >&2
    echo "" >&2
    exit 1
}


BASE_DIR=$(realpath "$(dirname "$0")")
MASTER="${MASTER:-}"

if [[ -z "${MASTER:-}" ]]
then
    echo "" >&2
    echo "ERROR: missing master node address." >&2
    echo "" >&2
    echo "HINT: If you did not want to install calico" >&2
    echo "remove it or comment it out in the resource file." >&2
    echo "" >&2
    usage
fi

if ssh root@"${MASTER}" "kubectl get ns calico-apiserver 2>&1 >/dev/null"
then
    echo "" >&2
    echo "ATTENTION: Calico is already installed." >&2
    echo "Skipping this installation..." >&2
    echo "" >&2
else
    echo ""
    echo "Installing calico..."

    ## Create calico dir in the remote node
    ssh root@"${MASTER}" "mkdir -p calico"

    ## Copy the required manifest in the remotely created calico directory
    scp "${BASE_DIR}/custom-resources.yaml" root@"${MASTER}":/root/calico/

    ## Install calico and wait until its apiserver is available before proceeding
    ssh root@"${MASTER}" <<EOS
kubectl create -f "https://raw.githubusercontent.com/projectcalico/calico/${VERSION}/manifests/tigera-operator.yaml"
kubectl create -f "/root/calico/custom-resources.yaml"
until kubectl get ns calico-apiserver 2>/dev/null
do
    sleep 3
done
kubectl wait -n calico-apiserver deployment/calico-apiserver --for condition=available --timeout=300s
EOS
fi

