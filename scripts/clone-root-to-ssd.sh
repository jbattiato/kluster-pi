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
    echo "Usage: $0 <node_address>" >&2
    echo "" >&2
    exit 1
}


remote_cmd(){
    local command
    command="${1}"

    ssh -Tq root@"${ADDRESS}" "${command}"
}

check_block_dev(){
    unset DEVICES
    declare -a DEVICES
    local dev

    ROOT_DEV="$(remote_cmd "lsblk -pnro NAME,MOUNTPOINTS | awk -F' ' '{if (\$2 == \"/\") {print \$1}}'")"
    DEVICES=( "$(remote_cmd "lsblk -pnro NAME,TYPE | awk -F' ' '{if (\$2 == \"disk\") {print \$1}}'")" )

    echo ""
    echo "Root file system is currently mounted on: "
    echo "- ${ROOT_DEV}"
    echo ""
    echo "Here's the list of available devices: "
    for dev in "${DEVICES[@]}"
    do
        echo "- ${dev}" 
    done
    echo ""
}

replace_label(){
    local file
    file=""

    for file in {"/boot/firmware/cmdline.txt","/etc/fstab","/etc/default/raspi-firmware"}
    do
        echo ""
        echo "Replacing ROOT label into ${file} file..."
        remote_cmd "sed -i 's/LABEL=RASPIROOT/LABEL=ROOT/' ${file}"
    done
}

add_cmdline(){
    local original
    local cmdline
    original=""
    cmdline="${1}"

    original=$(remote_cmd "cat /boot/firmware/cmdline.txt")
    complete_cmdline="${original} ${cmdline}"

    if ! remote_cmd "grep -q \"${cmdline}\" /boot/firmware/cmdline.txt" 
    then
        echo ""
        echo "Adding cgroups in cmdline.txt..."
        remote_cmd "echo ${complete_cmdline} > /boot/firmware/cmdline.txt" 
    fi

    echo ""
    echo "Creating the /etc/default/raspi-extra-cmdline file..."
    remote_cmd "echo ${cmdline} > /etc/default/raspi-extra-cmdline"
}

copy_partition_table(){
    remote_cmd "sfdisk -d \"${ROOT_DEV}\" > partition_table_sd"
    remote_cmd "sfdisk \"${SSD_DEV}\" < partition_table_sd"
}

increase_root_ssd(){
    echo ""
    echo "Increasing root partition..."
    remote_cmd "echo \",${NEW_SIZE}\" | sfdisk \"${SSD_DEV}\" -N2"
    echo ""
    echo "Creating third partition with remaining disk space..."
    SD_FREE_START=$(remote_cmd "sfdisk -qF \"${ROOT_DEV}\" \
        | grep -v 'Start' \
        | awk -F' ' '{print \$1}'")
    SSD_FREE_START=$(remote_cmd "sfdisk -qF \"${SSD_DEV}\" \
        | grep -v 'Start' \
        | awk -F' ' '{if (\$1 != \"${SD_FREE_START}\" ) {print \$1}}'")
    remote_cmd "echo \"${SSD_FREE_START},+\" | sfdisk \"${SSD_DEV}\" --append -N3"
    remote_cmd "udevadm settle"
}

create_fs(){
    remote_cmd "mkfs.ext4 \"${SSD_DEV}2\" -L ROOT"
    remote_cmd "udevadm settle"
}

run_clone_script(){
    if remote_cmd "[[ ! -f ./rpi-clone-master/rpi-clone ]]" 
    then
        echo "" >&2
        echo "ERROR: no clone script found in path: ./rpi-clone-master/rpi-clone." >&2
        echo "" >&2
        exit 2
    fi

    echo ""
    echo "Remote clone"
    remote_cmd "./rpi-clone-master/rpi-clone \"${SSD_DEV}\""
}

main(){
    # Check for node address
    if [[ $# -lt 1 ]]
    then
        echo "ERROR: please provide the target node address." >&2
        echo "" >&2
        usage
    fi

    # Set variables
    ADDRESS="${1}"
    SSD_DEV=""
    ROOT_DEV=""
    NEW_SIZE=""
    CMDLINE_STRING="elevator=deadline cgroup_memory=1 cgroup_enable=memory cgroup_enable=cpuset"

    # Replace RASPIROOT to ROOT in required files
    replace_label

    # Add trailing cgroups in cmdline.txt
    add_cmdline "${CMDLINE_STRING}"

    # Update APT repositories
    remote_cmd "apt update"

    # Find the available block devices
    check_block_dev

    echo "Choose the devices: "
    while true
    do
        read -rp "- target SSD for clone (e.g. /dev/sda): " SSD_DEV
        if remote_cmd "[[ ! -b \"${SSD_DEV}\" ]]"
        then
            echo -e "\ntarget SSD is not a block device: ${SSD_DEV}"
        else
            break
        fi
    done

    while true
    do
        read -rp "- current ROOT block device (e.g. /dev/mmcblk1): " ROOT_DEV
        if remote_cmd "[[ ! -b \"${ROOT_DEV}\" ]]"
        then
            echo -e "\ntarget ROOT is not a block device: ${ROOT_DEV}"
        else
            break
        fi
    done

    echo ""
    read -rp "Are you 100% sure you want to clone ${ROOT_DEV} into ${SSD_DEV}? [y/N] " ANSWER
    
    if [[ "${ANSWER}" != "y" ]]
    then
        echo "Exiting."
        exit 2
    fi
 
    # Clone partition table from ROOT device to SSD
    copy_partition_table

    echo ""
    while true
    do
        read -rp "Enter the new size for the root partition on the ${SSD_DEV} SSD (e.g. 32G): " NEW_SIZE
        if grep -E '^[0-9].*G$' <<<"${NEW_SIZE}"
        then
            break
        fi
    done
 
    # Increase partition size
    increase_root_ssd

    # Recreate file system in second partition
    create_fs

    # Execute RPi clone script
    run_clone_script

    echo ""
    read -rp "Do you want to reboot ${ADDRESS}? [y/N]: " ANSWER

    if [[ "${ANSWER}" != "y" ]]
    then
        echo "Exiting without rebooting."
        exit
    fi

    echo "Rebooting ${ADDRESS} now..."
    remote_cmd "systemctl reboot"
}

main "${@}"
