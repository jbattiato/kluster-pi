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

## This script will write a debian image into
## an SD card and configure the distro.
## sudo privileges are required.

set -eEuo pipefail

## Activate the debug mode
if [[ "${TRACE:-0}" == "1" ]]; then
    set -x
fi

trap clean_up ERR SIGINT SIGQUIT

usage(){
    cat >&2 <<EOS
Usage: $0 [-i <image>] -d <device> -k <ssh-id.pub> -H <hostname>
 
Options:
    -d, --device    The block device to write the image to (e.g. /dev/sde)

    -k, --key       The SSH public key to install in the /root/.ssh/authorized_keys

    -h, --help      Show this message.

    -H, --host      The chosen hostname to assign to the target machine

    -i, --image     The ISO image to write into the SD card. If not provided, the
                    writing phase will be skipped.

EOS
    exit 1
}

write_device() {
    ## this is just to be sure a destructive command
    ## is used with 100% certainty.

    echo ""
    read -r -p "Are you 100% SURE to write ${IMAGE} on ${SD_DEVICE} device? [N/yeees]: " ANSWER
    echo ""
    
    if [[ "${ANSWER}" != "yeees" ]] ; then
        echo "Exiting."
        return 2
    fi
    
    COUNT=5
    echo "If you are not sure"
    sleep 1.2
    
    while [[ "${COUNT}" -gt 1 ]] ; do
        echo "you still have ${COUNT} seconds to stop this!"
        (( COUNT-- ))
        sleep 1.2
    done
    echo "you still have ${COUNT} second to stop this!"
    sleep 1.2
    
    ## Write on disk
    echo ""
    echo "OK. Writing to disk..."
    echo ""
    sudo dd if="${IMAGE}" of="${SD_DEVICE}" status=progress
    sync
}

mount_partitions() {
    ## Mounting partitions
    local boot_mounted
    local root_mounted
    boot_mounted="false"
    root_mounted="false"
    mkdir -p "${BOOT}" "${ROOT}"
    
    PART_1="${SD_DEVICE}1"
    PART_2="${SD_DEVICE}2"

    if ! sudo mount "${PART_1}" "${BOOT}" ; then
        echo "" >&2
        echo "Cannot mount ${PART_1} on ${BOOT}" >&2
        boot_mounted="false"
    else
        boot_mounted="true"
    fi

    if ! sudo mount "${PART_2}" "${ROOT}" ; then
        echo "" >&2
        echo "Cannot mount ${PART_2} on ${ROOT}" >&2
        root_mounted="false"
    else
        root_mounted="true"
    fi

    if [[ "${boot_mounted}" == "false" ]] && [[ "${root_mounted}" == "false" ]]; then
        echo "" >&2
        echo "ERROR: partitions are not mounted." >&2
        echo "Exiting." >&2
        return 2
    else
        echo "SD card partitions mounted:"
        [[ "${boot_mounted}" == "true" ]] && echo "- ${PART_1} on ${BOOT}"
        [[ "${root_mounted}" == "true" ]] && echo "- ${PART_2} on ${ROOT}"
    fi
}

write_conf() {
    ## Configuring ssh and hostname
    if findmnt "${BOOT}" > /dev/null
    then
        if [[ ! -f "${BOOT}/sysconf.txt" ]] ; then
            echo "" >&2
            echo "ERROR: sysconf.txt not found in ${BOOT}" >&2
            echo "Exiting."
            return 2
        fi
        echo ""
        echo "Configuring SSH key and Hostname..."
        
        echo "root_authorized_key=$(cat "${SSH_KEY}")" | sudo tee -a "${BOOT}/sysconf.txt" > /dev/null
        echo "hostname=${HOST_NAME}" | sudo tee -a "${BOOT}/sysconf.txt" > /dev/null

        echo ""
        echo "Configuring cgroups in cmdline.txt..."
        CMD_ORIGINAL=$(cat "${BOOT}/cmdline.txt")
        echo "${CMD_ORIGINAL}  cgroup_memory=1 cgroup_enable=memory cgroup_enable=cpuset" | sudo tee "${BOOT}/cmdline.txt" > /dev/null
    fi

}

install_rpiclone() {
    ## Downloading rpi-clone in the root home
    if findmnt "${ROOT}" > /dev/null
    then
        if [[ ! -d "${ROOT}/root" ]] ; then
            echo "" >&2
            echo "ERROR: root directory not found in ${ROOT}" >&2
            echo "Exiting."
            return 2
        fi
        echo ""
        echo "Downloading rpi-clone on ${ROOT}/root"
        
        (
          cd "${TEMPDIR}"
          sudo wget -q "${RPI_CLONE_REPO}"
          sudo unzip -d "${ROOT}/root/" master.zip
          rm -rf master.zip
        )
    fi
}

clean_up() {
    ## Terminating script
    echo ""
    echo "Unmounting partitions..."
    
    sync

    if findmnt "${BOOT}" > /dev/null
    then
        sudo umount "${BOOT}"
    fi

    if findmnt "${ROOT}" > /dev/null
    then
        sudo umount "${ROOT}"
    fi

    echo ""
    echo "Removing temp dirs..."
    
    if [[ -d "${BOOT}" ]]
    then
        rmdir "${BOOT}"
    fi
    if [[ -d "${ROOT}" ]]
    then
        rmdir "${ROOT}"
    fi

    rmdir "${TEMPDIR}"
}

main() {
    ## Set variables
    TEMPDIR=$(mktemp -d)
    BOOT="${TEMPDIR}/boot"
    ROOT="${TEMPDIR}/root"
    RPI_CLONE_REPO="https://github.com/billw2/rpi-clone/archive/master.zip"
    SD_DEVICE=""
    SSH_KEY=""
    HOST_NAME=""

    ## The following code to manage options is inspired
    ## from the cloudnative-pg project script: hack/setup.sh
    if ! getopt -T > /dev/null; then
        options=$(getopt -o d:i:k:H:h -l "device:,image:,key:,host:,help" -- "$@") || usage
    else
        options=$(getopt d:i:k:H:h "$@") || usage
    fi

    eval "set -- $options"

    for o
    do
        case "${o}" in
            -d | --device)
                shift
                SD_DEVICE="${1}"
                shift
                ;;
            -i | --image)
                shift
                IMAGE="${1}"
                shift
                ;;
            -k | --key)
                shift
                SSH_KEY="${1}"
                shift
                ;;
            -H | --host)
                shift
                HOST_NAME="${1}"
                shift
                ;;
            -h | --help)
                usage
                ;;
            --)
                shift
                break
                ;;
        esac
    done

    ## Verify existence of mandatory parameters.
    ## Exit if they are not found.
    if [[ ! -b "${SD_DEVICE}" ]]; then
        echo "ERROR: device not found: ${SD_DEVICE}" >&2
        echo >&2
        usage
    fi
    if [[ ! -f "${SSH_KEY}" ]]; then
        echo "ERROR: ssh key not found: ${SSH_KEY}" >&2
        echo >&2
        usage
    fi
    if [[ -z "${HOST_NAME}" ]]; then
        echo "ERROR: the hostname is empty." >&2
        echo "Please provide a valid one." >&2
        echo >&2
        usage
    fi

    ## Skip the writing phase when no IMAGE is set
    if [[ -n "${IMAGE:-}" ]]; then
        if [[ ! -f "${IMAGE}" ]]; then
            echo "ERROR: file image not found: ${IMAGE}" >&2
            echo >&2
            usage
        fi
        write_device
    fi

    mount_partitions
    write_conf
    install_rpiclone

    clean_up

    echo ""
    echo "Done."
}

main "${@}"
