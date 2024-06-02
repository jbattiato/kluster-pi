# Nodes Preparation 

In order to host k3s on each node we must follow [its requirements](https://docs.k3s.io/installation/requirements).

## Enabling legacy iptables

``` bash
sudo iptables -F
sudo update-alternatives --set iptables /usr/sbin/iptables-legacy
sudo update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy
sudo reboot
```

## Enabling cgroups

Example of `/boot/firmware/cmdline.txt`

``` bash
console=serial0,115200 console=tty1 root=LABEL=ROOT rootfstype=ext4 elevator=deadline fsck.repair=yes rootwait cgroup_memory=1 cgroup_enable=memory cgroup_enable=cpuset
```


