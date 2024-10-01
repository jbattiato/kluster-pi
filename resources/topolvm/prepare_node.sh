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
    echo "Usage: $0 -h [<hosts-list-file>|<remote_address>] -p <remote_partition>" >&2
    echo "" >&2
    exit 1
}

read_hosts_list(){
    local node
    local node_address

    ## Read the HOSTS file and get the nodes IP address
    while IFS='=' read -r node node_address
    do
        if [[ -z "${node_address}" ]]
        then
            echo "ERROR: missing node address: ${node}" >&2
            echo "" >&2
            exit 1
        else
            NODE_ADDRESSES+=( "${node_address}" )
            eval "${node}"="${node_address}"
        fi
    done < <(grep "^[MA].*_" "${HOSTS}" | tr -d '"')
}

group_setup(){
    local node
    for node in "${NODE_ADDRESSES[@]}"
    do
        setup_node "${node}"
    done
}

setup_node(){
    local node
    node="${1}"

    # Prepare Node
    ## Install dependency
    ssh -Tq root@"${node}" "apt-get -y install lvm2"

    if ! ssh -Tq root@"${node}" "vgdisplay myvg1 >/dev/null 2>&1"
    then
        ## Setup LVM partition
        ssh -Tq root@"${node}" "pvcreate ${PARTITION}"
        ssh -Tq root@"${node}" "vgcreate myvg1 ${PARTITION}"
    fi
}

main(){
    unset NODE_ADDRESSES
    declare -a NODE_ADDRESSES

    if [[ $# -eq 0 ]]
    then
        echo "ERROR: missing -h arguments." >&2
        echo "" >&2
        usage
    fi

    if ! getopt -T > /dev/null; then
        # GNU enhanced getopt is available
        parsed_opts=$(getopt -o h:p: -l "hosts:,partition:" -- "$@") || usage
    else
        # Original getopt is available
        parsed_opts=$(getopt h:p: "$@") || usage
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
            -p | --partition)
                shift
                PARTITION="${1}"
                shift
                ;;
            --)
                shift
                break
                ;;
        esac
    done

    if [[ -z ${HOSTS:-} ]]
    then
        echo "ERROR: missing arg for -h option" >&2
        echo "" >&2
        usage
    fi

    if [[ -z ${PARTITION:-} ]]
    then
        echo "ERROR: missing arg for -p option" >&2
        echo "" >&2
        usage
    fi

    if [[ -f "${HOSTS}" ]]
    then
        # it's a file
        read_hosts_list
        group_setup
    else
        # it's an address
        setup_node "${HOSTS}"
    fi
}

main "${@}"

