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
    echo "Usage: $0 -r <resource>|<resources_file> [-h <host>] [-v <version>]" >&2
    echo "" >&2
    exit 1
}

group_deploy(){
    local resource
    local version

    ## Read the resources file and get the versions
    while IFS=':' read -r resource version
    do
        deploy_resource "${resource}" "${version}"
    done < <(grep -v '#' "${RESOURCES}")
}

deploy_resource(){
    local resource
    local version
    resource="${1}"
    version="${2}"

    TARGET_SCRIPT="${RESOURCES_DIR}/${resource}/install.sh"
    if [[ ! -f "${TARGET_SCRIPT}" ]]
    then
        echo "ERROR: wrong resource name: ${1}" >&2
        echo " HINT: resource name is the directory name in $(realpath "${RESOURCES_DIR}") path" >&2
        echo "" >&2
        usage
    fi
    export VERSION="${version}"
    export MASTER="${HOST:-}"

    echo ""
    echo "Deploying ${resource}..."

    bash "${TARGET_SCRIPT}"
}

main(){
    SCRIPT_DIR=$(realpath "$(dirname "$0")")
    ROOT_DIR=${SCRIPT_DIR}/..
    RESOURCES_DIR=${ROOT_DIR}/resources

    if [[ $# -eq 0 ]]
    then
        echo "ERROR: missing argument(s)." >&2
        echo "" >&2
        usage
    fi

    if ! getopt -T > /dev/null; then
        # GNU enhanced getopt is available
        parsed_opts=$(getopt -o r:h:v: -l "reources:,host:,version" -- "$@") || usage
    else
        # Original getopt is available
        parsed_opts=$(getopt r:h:v: "$@") || usage
    fi

    eval "set -- $parsed_opts"

    for o
    do
        case "${o}" in
            -r | --resources)
                shift
                RESOURCES="${1}"
                shift
                ;;
            -h | --hosts)
                shift
                HOST="${1}"
                if [[ -z "${HOST:-}" ]]
                then
                    echo "" >&2
                    echo "ERROR: missing host parameter." >&2
                    usage
                fi
                shift
                ;;
             -v | --version)
                shift
                VERSION="${1}"
                if [[ -z "${VERSION:-}" ]]
                then
                    echo "" >&2
                    echo "ERROR: missing version parameter." >&2
                    usage
                fi
                shift
                ;;
           --)
                shift
                break
                ;;
        esac
    done

    if [[ -f "${RESOURCES:-}" ]]
    then
        # it's a file
        group_deploy
    else
        # it's a single resource
        deploy_resource "${RESOURCES}" "${VERSION:-}"
    fi

}

main "${@}"

