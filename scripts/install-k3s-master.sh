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
    echo "Usage: $0 -t <token> -m <master-address> [--no-calico]" >&2
    echo "" >&2
    exit 1
}

install_dependencies(){
    apt-get install -y curl
}

wait_master(){
    ## Wait before exiting to ensure ${K3S_KUBECONFIG_OUTPUT} file exists and is the latest
    if [[ -f ${K3S_KUBECONFIG_OUTPUT} ]]
    then
        OLD_CONFIG_TIME=$(ls --full-time --time-style=+%Y%m%d%H%M%S "${K3S_KUBECONFIG_OUTPUT}" | awk '{print $6}')
        NEW_CONFIG_TIME="${OLD_CONFIG_TIME}"
        while [[ "${NEW_CONFIG_TIME}" == "${OLD_CONFIG_TIME}" ]]
        do
            sleep 3
            NEW_CONFIG_TIME=$(ls --full-time --time-style=+%Y%m%d%H%M%S "${K3S_KUBECONFIG_OUTPUT}" | awk '{print $6}')
        done
    else
        until [[ ! -f "${K3S_KUBECONFIG_OUTPUT}" ]]
        do
            sleep 3
        done
    fi
}

install_k3s(){
    curl -sfL https://get.k3s.io | \
      K3S_TOKEN="${TOKEN}" \
      K3S_KUBECONFIG_OUTPUT="${K3S_KUBECONFIG_OUTPUT}" \
      INSTALL_K3S_EXEC="server ${ARGS[*]}" sh -
}

main(){
    if [[ $# -eq 0 ]]
    then
        echo "ERROR: missing arguments." >&2
        echo "" >&2
        usage
    fi

    # Set KUBECONFIG to /root/k3s-kube.config if K3S_KUBE_CONFIG env variable is missing
    K3S_KUBECONFIG_OUTPUT="${K3S_KUBE_CONFIG:-/root/k3s-kube.config}"
    TOKEN=""
    FLANNEL_OPT="--flannel-backend=none"
    unset ARGS
    declare -a ARGS

    # Set k3s server arguments
    ARGS+=( "--cluster-cidr=10.42.0.0/16" "--disable-cloud-controller" "--disable-network-policy" )
    ARGS+=( "--disable=traefik" "--disable=servicelb" "--log=/var/log/k3s.log" )

    if ! getopt -T > /dev/null; then
        # GNU enhanced getopt is available
        parsed_opts=$(getopt -o t:m:n -l "token:,master:,no-calico" -- "$@") || usage
    else
        # Original getopt is available
        parsed_opts=$(getopt t:m:n "$@") || usage
    fi

    eval "set -- $parsed_opts"

    for o
    do
        case "${o}" in
            -t | --token)
                shift
                TOKEN="${1}"
                shift
                ;;
            -n | --no-calico)
                # Don't disable flannel
                FLANNEL_OPT=""
                shift
                ;;
            -m | --master)
                # Set master address
                shift
                ADDRESS="${1}"
                shift
                ;;
            --)
                shift
                break
                ;;
        esac
    done

    # Check for configuration file
    if [[ -z "${TOKEN:-}" ]]
    then
        echo "ERROR: token is empty!" >&2
        echo "" >&2
        usage
    fi

    # Check if command is missing
    if [ "$#" -eq 0 ]; then
      echo "" >&2
      echo "ERROR: you must specify a command" >&2
      echo "" >&2
      usage
    fi

    command="${1}"

    case "$command" in
        init)
            ARGS+=( "--cluster-init" )
            ;;
        join)
            # Check for master address
            if [[ -z "${ADDRESS:-}" ]]
            then
                echo "ERROR: master address is empty!" >&2
                echo "" >&2
                usage
            fi

            ARGS+=( "--server https://${ADDRESS}:6443" )
            ;;
        *)
            echo "" >&2
            echo "ERROR: unknown command: ${command}" >&2
            echo "" >&2
            usage
            ;;
    esac

    # Complete the list of arguments
    ARGS+=( "${FLANNEL_OPT}" )

    install_dependencies
    install_k3s

    if [[ "${command}" == "init" ]]
    then
        wait_master
    fi

    echo ""
    echo "K3S installation: done."
}

main "${@}"

