# Nodes Preparation 

In order to host k3s on each node we must follow [its requirements](https://docs.k3s.io/installation/requirements).

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

## Enabling cgroups

This has already been done in the previous chapter of the procedure.

Example of `/boot/firmware/cmdline.txt`

``` bash
console=serial0,115200 console=tty1 root=LABEL=ROOT rootfstype=ext4 elevator=deadline fsck.repair=yes rootwait cgroup_memory=1 cgroup_enable=memory cgroup_enable=cpuset
```

