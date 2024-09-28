# Nodes Preparation

In order to host k3s on each node we must ensure [its requirements](https://docs.k3s.io/installation/requirements?os=pi)
are respected for the Raspberry Pi use case.

## Install iptables

``` bash
apt install iptables
```

### Enable iptables legacy (only for iptables < v1.6.1)

[Read this first](https://docs.k3s.io/known-issues#iptables).

The following actions are not needed on Debian Bookworm (iptables >= 1.8.9):

``` bash
iptables -F
update-alternatives --set iptables /usr/sbin/iptables-legacy
update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy
reboot
```

## Ensure cgroups

This has already been done in the previous chapter of the procedure.

Example of `/boot/firmware/cmdline.txt`

``` bash
console=serial0,115200 console=tty1 root=LABEL=ROOT rootfstype=ext4 fsck.repair=yes rootwait elevator=deadline cgroup_memory=1 cgroup_enable=memory cgroup_enable=cpuset
```

## SSD TRIM

Since we are using SSDs as main storage, we would like to keep their performances for long time. The SSD TRIM process
ensures good performance of the SSD by erasing data blocks that are not in use anymore. In this way any new writes will
not wait for the blocks to be erased first.

NOTE: not every SATA to USB3.0 adapter supports TRIM. That's why, after a long reserch, I chose the "UGREEN USB 3.0 to SATA Adapter"
which supports both UASP and TRIM.

Here you can follow one of the procedures to enable SSD TRIM in Debian:

* https://lemariva.com/blog/2020/12/raspberry-pi-4-ssd-booting-enabled-trim
* https://www.jeffgeerling.com/blog/2020/enabling-trim-on-external-ssd-on-raspberry-pi

Or use the script that takes care of every steps:

``` bash
bash scripts/enable-fstrim.sh -h hosts.list
```

IMPORTANT: the above script sends remote commands to the nodes, so must run from the local host that has SSH access to the nodes.

