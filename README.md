# K8S cluster on Raspberry Pi

<p align="center">
  <img src="docs/images/kluster_02.jpg" width="60%" alt="Kluster-Pi">
</p>

## Project

This project allows everyone to easily build a Kubernetes cluster using [Raspberry Pi](https://www.raspberrypi.com/)
and [Rancher's k3s](https://docs.k3s.io/).

The final product is a K3S cluster with [`etcd` in HA](https://docs.k3s.io/datastore/ha-embedded) running on Raspberry Pi boards with USB3.0 attached SSDs.

K3S will use:

* [calico](https://docs.k3s.io/networking/basic-network-options?cni=Calico#custom-cni) as CNI
* [Metallb](https://metallb.io/) as load balancer
* [ingress-nginx](https://kubernetes.github.io/ingress-nginx/) as ingress
* optional [CSIs](docs/container-storage-interfaces.md)
* optional [cert-manager](https://cert-manager.io/)

## Purpose

I initially created it for my personal use, from experimenting with [cloudnative-pg](https://cloudnative-pg.io/)
and [longhorn](https://longhorn.io/), to run my own cloud services using [nextcloud](https://nextcloud.com/).

The main purpose is to share the gained knowledge and the collection of bash scripts with anyone is interested in learning, practicing, and improving this project.
My recommendation is to first follow the procedure and get confidence with the commands by manually apply them step by step. Then, one could always recreate the entire cluster
and the deployed resources in a semi-automatic fashion using the provided scripts.

The scripts are mainly a solution to speed up the entire setup process from scratch, and ensuring reproducibility.

## Hardware

<p align="center">
  <img src="docs/images/kluster_01.jpg" width="60%" alt="hardware 2">
</p>

### Minimum Requirements

* x3 RPi 8GB RAM
* x3 SD cards
* x3 SSD disks
* x3 SATA to USB-3
* x1 4 ports network switch

Power adapters/cables, and network cables are omitted, but required.

### Tested

* Boards: **Raspberry Pi 4 8GB RAM**
* Power: **RPi PoE HAT** or **USB power adapters**
* SATA to USB3.0 adapter: **UGREEN with UASP TRIM support**
* SSD: **Samsung 860 EVO - 1TB**
* Network Switch: **TP-Link SG1005P (PoE)**

## Distribution

* [Debian for RPi](https://raspi.debian.net/tested-images/)

Tested on Debian 12 Bookworm for arm64.

## Procedure

Follow the procedure in the `docs/` directory:

0. [Update RPi4 Firmware (not necessary anymore)](docs/00-update-firmware.md)
1. [Install Debian for RPi](docs/01-install-debian.md)
2. [Clone image on SSD and mount it as `root`](docs/02-clone-image-on-ssd.md)
3. [Prepare RPi nodes installing and configuring packages](docs/03-preparing-nodes.md)
4. [Setup cluster installing k3s on each node](docs/04-setup-k8s.md)
5. [Install additional resources](docs/05-additional-resources.md)

## Scripts

[Scripts Overview](scripts/README.md)

### Procedural

1. `install-sd.sh` - to write distro image into SD card, add SSH key, configure hostname, download `rpi-clone` repo inside `/root`
2. `clone-root-to-ssd.sh` - to automate the procedure to clone SD to SSD
3. `install-kluster.sh` - to install k3s and deploy required resources on the cluster following the correct procedure
4. `deploy-resources.sh` (optional) - to deploy the specified kubernetes resource(s) from a list or just one resource

### Others

* `intall-k3s-master.sh` - to install and deploy the k3s master (init and join)
* `join-k3s-agent.sh` - to install and deploy a new k3s agent to join the cluster
* `enable-fstrim.sh` - to enable fstrim on target nodes where supported

## Sources

### Raspberry Pi

* [Update Raspberry Firmware #1](https://lemariva.com/blog/2020/12/raspberry-pi-4-ssd-booting-enabled-trim)
* [Raspberry Firmware Release Notes](https://github.com/raspberrypi/rpi-eeprom)
* [Boot from USB](https://www.raspberrypi.com/documentation/computers/raspberry-pi.html#usb-mass-storage-boot)
* [Debian for RPi](https://raspi.debian.net/defaults-and-settings/)
* [Image clone guide](https://notenoughtech.com/raspberry-pi/how-to-boot-raspberry-pi-4-from-usb/)
* [RPi Clone tool](https://github.com/billw2/rpi-clone)
* [RPi Boot from SSD](https://jamesachambers.com/new-raspberry-pi-4-bootloader-usb-network-boot-guide/)
* [Raspberry Pi cheat sheet](https://github.com/LukaszLapaj/raspberry-pi-cheat-sheet)
* [SSD TRIM](https://www.techtarget.com/searchstorage/definition/TRIM)

### Kubernetes

* [K8S on RPi video](https://www.youtube.com/watch?v=B2wAJ5FLOYw)
* [K8S on RPi](https://uthark.github.io/post/2020-09-02-installing-kubernetes-raspberrypi/)
* [K3S multimaster HA](https://rancher.com/docs/k3s/latest/en/installation/ha-embedded/)

### Network

* [Calico installation](https://docs.projectcalico.org/getting-started/kubernetes/k3s/multi-node-install)

### Load Balancer

* [MetalLB on GH](https://github.com/metallb/metallb)

### Storage

* [Longhorn on GH](https://github.com/longhorn/longhorn)

### Ingress

* [Nginx Ingress on GH](https://github.com/kubernetes/ingress-nginx)

### Database

* [Cloudnative-pg on GH](https://github.com/cloudnative-pg/cloudnative-pg)

