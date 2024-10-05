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
    echo "Usage: $0 -t <token> -m <master-address>" >&2
    echo "" >&2
    exit 1
}

install_dependencies(){
    apt-get install -y curl
}

install_k3s(){
    curl -sfL https://get.k3s.io | \
      K3S_TOKEN=${TOKEN} \
      K3S_URL=https://${SERVER}:6443 \
      sh -
}

main(){
    if [[ $# -eq 0 ]]
    then
        echo "ERROR: missing arguments." >&2
        echo "" >&2
        usage
    fi

    if ! getopt -T > /dev/null; then
        # GNU enhanced getopt is available
        parsed_opts=$(getopt -o t:m: -l "token:,master" -- "$@") || usage
    else
        # Original getopt is available
        parsed_opts=$(getopt t:m: "$@") || usage
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
            -m | --master)
                # Set master address
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
    if [[ -z ${TOKEN:-} ]]
    then
        echo "ERROR: token is empty!" >&2
        echo "" >&2
        usage
    fi

    install_dependencies
    install_k3s

    echo ""
    echo "K3S installation: done."
}

main "${@}"
