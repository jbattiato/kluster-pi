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

VERSION=${VERSION:-v15.4.0}
KUBECONFIG="${KUBECONFIG:-${HOME}/.kube/kluster-pi-config}"
export KUBECONFIG

if ! kubectl get ns >/dev/null 2>&1
then
    echo "" >&2
    echo "ERROR: cannot reach kubernetes cluster." >&2
    echo " HINT: check the kube config." >&2
    exit 1
fi

if ! kubectl get ns cert-manager >/dev/null 2>&1
then
    echo "" >&2
    echo "ERROR: missing dependency: cert-manager." >&2
    echo "  FIX: install cert-manager firsr." >&2
    exit 1
fi

## Create Namespace
kubectl create ns topolvm-system
## Label Namespaces
kubectl label namespace topolvm-system topolvm.io/webhook=ignore
kubectl label namespace kube-system topolvm.io/webhook=ignore

# Setup Helm
helm repo add topolvm https://topolvm.github.io/topolvm
helm repo update topolvm

# Install topoLVM
helm install --namespace=topolvm-system topolvm topolvm/topolvm --version ${VERSION}

# Check installation
kubectl get pod -n topolvm-system

