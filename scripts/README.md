# Scripts Overview

| name | automates | runs on |  options  | values | arguments | env variables |
-------|----------|--------|-----------|--------|-----------|----------------|
| `install-sd.sh` | [Install Debian for RPi](../docs/01-install-debian.md) | user local machine | `-d` `-h` `-k` `-i`* | block device, remote host, ssh key, distro image | | `TRACE` (debug) |
| `clone-root-to-ssd.sh` | [Clone SD image into SSD and mount it as root](../docs/02-clone-image-on-ssd.md) | user local machine | | | remote node address | `TARCE` (debug) |
| `install-kluster.sh` | [Setup cluster installing k3s on each node](../docs/04-setup-k8s.md) | user local machine | `-h` `-r` `-n`* | remote host, resources file | | `TARCE` (debug) |
| `deploy-resources.sh` | deployment of resources into k3s | user local machine | `-r` `-h`* `-v`* | a resource or a resources file, remote host, version | | `TARCE` (debug) |
| `intall-k3s-master.sh` | initialization and joining of the k3s masters | remote node | `-t` `-m`* `-n`* | k3s token, first master address | command: `init` or `join` | `TRACE` (debug), `K3S_KUBE_CONFIG` |
| `join-k3s-agent.sh` | joining of agent to the k3s cluster  | remote node | `-t` `-m` | k3s token, first master address | | `TARCE` (debug) |
| `enable-fstrim.sh` | [Prepare RPi nodes installing and configuring packages](docs/03-preparing-nodes.md) | user local machine | `-h` | remote host or a hosts file | | `TRACE` (debug) |

`*` : optional.

## SD setup

`install-sd.sh`

This script applies the steps described in the [Install Debian for RPi](../docs/01-install-debian.md) procedure.

## Disk clone

`clone-root-to-ssd.sh`

This script applies the steps described in the [Clone SD image into SSD and mount it as root](docs/02-clone-image-on-ssd.md) procedure.

## K3S cluster setup

`install-kluster.sh`

This script applies the steps described in the [Setup cluster installing k3s on each node](../docs/04-setup-k8s.md) procedure.

It's basically a complex wrapper to call other scripts to setup the entire k3s cluster following the right order and respecting the right prerequisites.
Internally will call in order:

1. `install-k3s-master.sh` to init the first master
2. `deploy-resources.sh` to install calico
3. `install-k3s-master.sh` to join the other masters
4. `join-k3s-agents.sh` to join agents (if defined)
5. `deploy-resources.sh` to deploy the rest of the resources defined in the resources file

## Resource deployment

`deploy-resources.sh`

This script is designed as a wrapper to call the external `install.sh` script from each resource defined by the `-r` option.
The `-r` option either accepts a single resource name or a file containing a list of resources with their version.
An example of the resource file is below:

```
#calico:v3.28.2
ingress-nginx:v1.11.2
metallb:v0.14.8
cert-manager:v1.15.3
longhorn:v1.7.1
cloudnative-pg:1.24.0
```

NOTE: `calico` is commented out because it must be installed only during the k3s cluster setup.

Each resource name matches the corresponding directory in the [`resources`](../resources) directory. Each resource's directory must contain an `install.sh` script with all the required commands to deploy it in the Kuberentes cluster.

In case of `calico` its `install.sh` script requires additional parameters to properly working. One is the address/hostname of the first k3s master installed, where to deploy the `calico` operator to start the CNI.

## K3S master setup

`intall-k3s-master.sh`

This script is the main wrapper of the k3s script provided by rancher to deploy masters nodes.

Calling it with the `init` command it will initialize the first master.
Consequently, with the `join` command it will setup another master and join it to the first one.

## K3S agent join

`join-k3s-agent.sh`

This script is the main wrapper of the k3s script provided by rancher to deploy agent nodes.

## SSD FSTRIM setup

`enable-fstrim.sh`

This script applies the steps described in the [Prepare RPi nodes installing and configuring packages](docs/03-preparing-nodes.md) procedure for enabling the ssd fstrim on each RPi node.



