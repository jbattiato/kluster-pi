# Scripts Overview

| name | automates | runs on |  options  | values | arguments | env variables |
-------|----------|--------|-----------|--------|-----------|----------------|
| `install-sd.sh` | [Install Debian for RPi](../docs/01-install-debian.md) | user local machine | `-d` `-h` `-k` `-i`* | block device, remote host, ssh key, distro image | | `TRACE` (debug) |
| `clone-root-to-ssd.sh` | [Clone SD image into SSD and mount it as root](../docs/02-clone-image-on-ssd.md) | user local machine | | | remote node address | `TRACE` (debug) |
| `install-kluster.sh` | [Setup cluster installing k3s on each node](../docs/04-setup-k8s.md) | user local machine | `-h` `-r` `-n`* | remote host, resources file | | `TRACE` (debug) |
| `deploy-resources.sh` | deployment of resources into k3s | user local machine | `-r` `-h`* `-v`* | a resource or a resources file, remote host, version | | `TRACE` (debug) |
| `intall-k3s-master.sh` | initialization and joining of the k3s masters | remote node | `-t` `-m`* `-n`* | k3s token, first master address | command: `init` or `join` | `TRACE` (debug), `K3S_KUBE_CONFIG` |
| `join-k3s-agent.sh` | joining of agent to the k3s cluster  | remote node | `-t` `-m` | k3s token, first master address | | `TRACE` (debug) |
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

It requires a host file that must contain a list of the desired masters and agents. The file format must be like follows:

``` bash
MASTER_1="<ip_address>"
MASTER_2="<ip_address>"
MASTER_3="<ip_address>"
AGENT_1="<ip_address>"
#AGENT_2="<ip_address>"
# more agents if needed
```

This script is basically a complex wrapper which calls other scripts to setup the entire k3s cluster following the proper order and respecting the right prerequisites.
Internally it will call, in order:

1. `install-k3s-master.sh` to init the first master
2. `deploy-resources.sh` to install calico
3. `install-k3s-master.sh` to join other masters (if defined)
4. `join-k3s-agents.sh` to join agents (if defined)
5. `deploy-resources.sh` to deploy the rest of the resources defined in the resources file

## Resource deployment

`deploy-resources.sh`

This script is designed as a wrapper which calls the `install.sh` script from each resource's directory. The selected resource is passed to the script through the `-r` option.
The `-r` option either accepts a single resource name or a file containing a list of resources with their version.

The resource file must respect the format:

```
resource-name:version
```

where the `resource-name` must match the directory name in the `resource/` directory for that specific resource.

Below is an example:

```
#calico:v3.28.2
ingress-nginx:v1.11.2
metallb:v0.14.8
cert-manager:v1.15.3
longhorn:v1.7.1
cloudnative-pg:1.24.0
```

IMPORTANT: the order of the list must respect the top-down approach, where the first elements are prerequisites of the successives following them.

NOTE: `calico` is commented out because it must be installed only during the k3s cluster setup.

Each resource name matches the corresponding directory in the [`resources`](../resources) directory. Each resource's directory must contain an `install.sh` script with all the required commands to deploy it in the Kuberentes cluster.

In case of `calico` its `install.sh` script requires additional parameters to properly work. One is the address/hostname of the first k3s master installed, which is the node where to deploy the `calico` operator to start the CNI for the entire cluster.

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


