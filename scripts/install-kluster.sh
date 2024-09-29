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

usage(){
    echo "Usage: $0 -h <hosts-list-file> -r <resources-list-file>" >&2
    echo "" >&2
    exit 1
}

generate_token(){
    pwgen -B 20 1
}

init_master(){
    local address="${1:-}"
    local token
    token=$(generate_token)
    K3S_KUBE_CONFIG="/root/k3s-kube.config"

    # Skip if k3s is already running
    if ssh -q root@"${address}" 'ps axf | grep "[k]3s\ init" >/dev/null'
    then
        echo "WARNING: k3s master is already running on: ${address}"
        return
    fi

    echo ""
    echo "Initialize first k3s master..."

    ## Copy init script to remote server
    scp scripts/init-k3s-master.sh root@"${address}":/root/

    ## Execute init script remotely
    ssh root@"${address}" "bash init-k3s-master.sh ${token}"

    ## Copy the latest ${K3S_KUBE_CONFIG} in local
    scp root@"${address}":"${K3S_KUBE_CONFIG}" "${KUBECONFIG}"

    ## Replace the localhost with MASTER_1 ip in the ${KUBECONFIG}
    sed -i -e "s/127.0.0.1:6443/${address}:6443/g" "${KUBECONFIG}"
    ## Save token
    echo "${token}" > ./.k3s-token

    ## Wait a bit
    sleep 5

    ## Wait until the apiserver respond
    READY=$(ssh root@"${address}" "kubectl get pods -A 2>/dev/null | wc -l")

    until [[ "${READY}" -gt 1 ]]
    do
        READY=$(ssh root@"${address}" "kubectl get pods -A 2>/dev/null | wc -l")
        sleep 5
    done

    deploy_calico "${address}"
}

join_master(){
    local address="${1:-}"
    local token
    token=$(cat ./.k3s-token)

    # Skip if k3s is already running
    if ssh -q root@"${address}" 'ps axf | grep "[k]3s\ init" >/dev/null'
    then
        echo "WARNING: k3s master is already running on: ${address}"
        return
    fi

    echo ""
    echo "Joining k3s master..."

    ## Copy join script to remote server
    scp scripts/join-k3s-master.sh root@"${address}":/root/

    ## Execute join script remotely
    ssh root@"${address}" "bash join-k3s-master.sh ${token} ${MASTER_1}"
}

install_master(){
    local phase="${1:-}"
    local address="${2:-}"

    case "${phase}" in
        init)
            init_master "${address}"
            ;;
        join)
            join_master "${address}"
            ;;
    esac
}

join_agent(){
    local address="${1:-}"
    local token
    token=$(cat ./.k3s-token)

    # Skip if k3s is already running
    if ssh -q root@"${address}" 'ps axf | grep "[k]3s\ agent" >/dev/null'
    then
        echo "WARNING: k3s agent is already running on: ${address}"
        return
    fi

    echo ""
    echo "Joining k3s agent..."

    ## Copy join script to remote server
    scp scripts/join-k3s-agent.sh root@"${address}":/root/

    ## Execute join script remotely
    ssh root@"${address}" "bash join-k3s-agent.sh ${token} ${MASTER_1}"
}

install_packages(){
    ## Based on the list of required packages
    ## install them in each of the target node
    echo "Nothing to do here. Yet."
}

read_hosts_list(){
    local master
    local agent
    local master_address
    local agent_address

    ## Read the HOSTS file and get the masters IP address
    while IFS='=' read -r master master_address
    do
        if [[ -z "${master_address}" ]]
        then
            echo "ERROR: missing master address: ${master}" >&2
            echo "" >&2
            exit 1
        else
            MASTER_ADDRESSES+=( "${master_address}" )
            eval "${master}"="${master_address}"
        fi
    done < <(grep ^MASTER_ "${HOSTS}" | tr -d '"')

    ## Read the HOSTS file and get the agents IP address
    while IFS='=' read -r agent agent_address
    do
        if [[ -z "${agent_address}" ]]
        then
            echo "ERROR: missing agent address: ${agent}" >&2
            echo "" >&2
            exit 1
        else
            AGENT_ADDRESSES+=( "${agent_address}" )
            eval "${agent}"="${agent_address}"
        fi
    done < <(grep ^AGENT_ "${HOSTS}" | tr -d '"')
}

deploy_calico(){
    local address=${1}
    local version

    ## Get calico version from ${RESOURCES_FILE}
    IFS=':' read -r _ version < <(grep calico "${RESOURCES_FILE}")

    echo ""
    echo "Installing calico..."

    ## Create calico dir in the remote node
    ssh root@"${address}" "mkdir -p calico"

    ## Copy the required script and manifest in the previously created calico directory
    scp "${RESOURCES_DIR}"/calico/{install.sh,custom-resources.yaml} root@"${address}":/root/calico/

    ## Deploy calico and wait until its apiserver is available before proceeding
    ssh root@"${address}" "
VERSION=${version:-} bash calico/install.sh \
&& until kubectl get ns calico-apiserver 2>/dev/null
do
    sleep 3
done \
&& kubectl wait -n calico-apiserver deployment/calico-apiserver --for condition=available --timeout=300s
"
}

main(){
    SCRIPT_DIR=$(realpath "$(dirname "$0")")
    ROOT_DIR=${SCRIPT_DIR}/../
    RESOURCES_DIR=${ROOT_DIR}/resources
    KUBECONFIG=${HOME}/.kube/kluster-pi-config
    RESOURCES_FILE=${ROOT_DIR}/resources
    unset MASTER_ADDRESSES
    unset AGENT_ADDRESSES
    declare -a MASTER_ADDRESSES
    declare -a AGENT_ADDRESSES

    if [[ $# -eq 0 ]]
    then
        echo "ERROR: no hosts file passed." >&2
        echo "" >&2
        usage
    fi

    if ! getopt -T > /dev/null; then
        # GNU enhanced getopt is available
        parsed_opts=$(getopt -o h:r: -l "hosts:resources:" -- "$@") || usage
    else
        # Original getopt is available
        parsed_opts=$(getopt h:r: "$@") || usage
    fi

    eval "set -- $parsed_opts"

    for o
    do
        case "${o}" in
            -h | --hosts)
                shift
                HOSTS="${1}"
                shift
                ;;
            -r | --resources)
                shift
                RESOURCES_FILE="${1}"
                shift
                ;;
            --)
                shift
                break
                ;;
        esac
    done

    # Check for configuration file
    if [[ ! -f ${HOSTS:-} ]]
    then
        echo "ERROR: file not found: ${HOSTS:-}" >&2
        echo "" >&2
        usage
    fi

    # Check for configuration file
    if [[ ! -f ${RESOURCES_FILE:-} ]]
    then
        echo "ERROR: file not found: ${RESOURCES_FILE:-}" >&2
        echo "" >&2
        usage
    fi

    read_hosts_list
    install_master init "${MASTER_1}"

    ## Install k3s for each defined masters except the first one
    if [[ "${#MASTER_ADDRESSES[@]}" -gt 1 ]]
    then
        for master in "${MASTER_ADDRESSES[@]}"
        do
            if [[ "${master}" == "${MASTER_1}" ]]
            then
                continue
            fi
            install_master join "${master}"
        done
    fi

    ## Install k3s for each defined agent
    # reset behaviour for unset variables
    set +u
    if [[ "${#AGENT_ADDRESSES[@]}" -gt 0 ]]
    then
        for agent in "${AGENT_ADDRESSES[@]}"
        do
            join_agent "${agent}"
        done
    fi
    # unset variable are considered error again
    set -u

    ## Deploy each resource defined in the ${RESOURCES_FILE} except calico
    sed -i -e 's/^calico/#calico/' "${RESOURCES_FILE}"
    export KUBECONFIG
    bash "${SCRIPT_DIR}"/deploy-resources.sh "${RESOURCES_FILE}"
    sed -i -e 's/^#calico/calico/' "${RESOURCES_FILE}"
}

main "${@}"

