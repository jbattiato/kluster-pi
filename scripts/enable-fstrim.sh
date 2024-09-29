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
    echo "Usage: $0 -h [<hosts-list-file>|<remote_address>]" >&2
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
    done < <(grep "^.*_" "${HOSTS}" | tr -d '"')
}

group_setup(){
    local node
    for node in "${NODE_ADDRESSES[@]}"
    do
        setup_fstrim "${node}"
    done
}

setup_fstrim(){
    local node
    node="${1}"

    # Remote install required packages
    ssh root@"${node}" "apt install -y usbutils bc sg3-utils lsscsi"

    ssh -Tq root@"${node}" <<'EOS'
    # Retrieve values and set variables
    UNMAP_COUNT=$(sg_vpd -p bl /dev/sda | awk -F':' '{if ($1 ~ "Maximum unmap LBA count") {print $2}}')
    UNMAP_SUPPORT=$(sg_vpd -p lbpv /dev/sda | awk -F':' '{if ($1 ~ "Unmap command supported") {print $2}}')
    LOGICAL_BLOCK=$(sg_readcap -l /dev/sda | awk -F'=' '{if ($1 ~ "Logical block length") {print $2 | "cut -d \" \" -f1"}}')

    # Activate fstrim only if supported
    if [[ $UNMAP_SUPPORT -eq "1" ]]; then
        MAX_BYTE=$(echo  "$UNMAP_COUNT * $LOGICAL_BLOCK" | bc)
        USB_ID=$(lsusb | awk -F' ' '{if ($0 ~ "SATA") {print $6}}')
        VENDOR_ID=${USB_ID:0:4}
        PRODUCT_ID=${USB_ID:5}

        DEVICE=$(find /sys/ -name provisioning_mode)

        # Activate fstrim
        echo unmap > ${DEVICE}
        echo $MAX_BYTE > /sys/block/sda/queue/discard_max_bytes

        # Persist conf
        cat <<EOF >/etc/udev/rules.d/10-trim.rules
ACTION=="add|change", ATTRS{idVendor}=="$VENDOR_ID", ATTRS{idProduct}=="$PRODUCT_ID", SUBSYSTEM=="scsi_disk", ATTR{provisioning_mode}="unmap"
KERNEL=="sda", SUBSYSTEM=="block", ATTR{queue/discard_max_bytes}="$MAX_BYTE"
ACTION=="add|change", ATTRS{idVendor}=="$VENDOR_ID", ATTRS{idProduct}=="$PRODUCT_ID", SUBSYSTEM=="block", ATTR{queue/discard_max_bytes}="$MAX_BYTE"
EOF

    fi
EOS
}

main(){
    unset NODE_ADDRESSES
    declare -a NODE_ADDRESSES

    if [[ $# -eq 0 ]]
    then
        echo "ERROR: no argument passed." >&2
        echo "" >&2
        usage
    fi

    if ! getopt -T > /dev/null; then
        # GNU enhanced getopt is available
        parsed_opts=$(getopt -o h:r: -l "hosts:remote:" -- "$@") || usage
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
            --)
                shift
                break
                ;;
        esac
    done

    if [[ -z "${HOSTS:-}" ]]
    then
        echo "ERROR: missing parameter: -h" >&2
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
        setup_fstrim "${HOSTS}"
    fi
}

main "${@}"

