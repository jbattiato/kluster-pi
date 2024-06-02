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

usage(){
    echo "Usage: $0 <resources_file>" >&2
    echo "" >&2
    exit 1
}

if [[ $# -lt 1 ]]
then
    echo "ERROR: missing resource file as ARG." >&2
    echo "" >&2
    usage
fi

SCRIPT_DIR=$(realpath "$(dirname "$0")")
ROOT_DIR=${SCRIPT_DIR}/../
RESOURCES_DIR=${ROOT_DIR}/resources
RESOURCES_FILE="${1}"

while IFS=':' read -r resource version
do
    TARGET_SCRIPT="${RESOURCES_DIR}/${resource}/install.sh"
    if [[ ! -f "${TARGET_SCRIPT}" ]]
    then
        echo "ERROR: wrong resource name: ${1}" >&2
        echo " HINT: resource name is the same name of each directory in $(realpath "${RESOURCES_DIR}") path" >&2
        echo "" >&2
        usage
    fi
    export VERSION="${version}"
    bash "${TARGET_SCRIPT}"
done < <(grep -v '#' "${RESOURCES_FILE}")

