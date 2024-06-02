# Setup K8S on Raspberry Pi

## Architecture

High available multi master using embedded etcd as datastore.
The following k3s components are disabled during installation,
and replaced by their alternatives when required:

* servicelb
* traefik
* flannel-backend
* cloud-controller

## TL;DR

One of the purpose of this prject is to learn by doing. This is why I documented each step
instead of sharing a single bash script or an ansible playbook.
But, I also provide scripts to automate some of the steps for the entire procedure in order to
make it repeatable and fast to deploy for experimenting.

### Select versions

The `resources.list` file contains the version for each desired component when installed with the
`scripts/deploy-resources.sh` script. Alternatevely, you can use each resource's `install.sh`
script inside each of them subdirectory: e.g. `resources/calico/install.sh`.

Versions are hardcoded in each resource's `install.sh` file, but are overridden by the
`resources.list` file when `scripts/deploy-resources.sh resources.list` is executed.

### Installing K3S

The `scripts/install-kluster.sh` file is the automation script that allows you to setup a k3s cluster
on Raspberry Pis. It takes care of all the steps in this chapter; more precisely, it will, in order:

1. install the first k3s master
2. deploy calico
3. join other masters
4. join agents (if any)
5. deploy desired resources (if defined)

Usage:

``` bash
bash scripts/install-kluster.sh -h hosts.list -r resources.list
```

The script will write the TOKEN generated automatically in the hiddent file `.k3s-token` inside the
root of the project.

Or you can manually perform the following procedure.

## Installing the first k3s master

First node command example:

``` bash
##
MASTER_1=<kluster-pi-1st-master-ip-address>
TOKEN=`pwgen -B 20 1`
##
scp scripts/init-k3s-master.sh root@${MASTER_1}:~/
ssh root@${MASTER_1} "bash init-k3s-master.sh ${TOKEN}"
scp root@${MASTER_1}:/root/k3s-kube.config ~/.kube/kluster-pi-config
sed -i -e "s/127.0.0.1:6443/${MASTER_1}:6443/g" ~/.kube/kluster-pi-config
```

Save the TOKEN somewhere, if you want to add new nodes in the future.

## Installing Calico

Create calico deployment:

``` bash
KUBECONFIG=${HOME}/.kube/kluster-pi-config bash resources/calico/install.sh
```

## Adding new masters

Other nodes command example:

``` bash
scp scripts/join-k3s-master.sh root@<kluster-pi-other-master>:~/
ssh root@<kluster-pi-other-master> "bash join-k3s-master.sh ${TOKEN} ${MASTER_1}"
```

Repeat the above for the remaining master nodes.

## Adding agents (if any)

``` bash
scp scripts/join-k3s-agent.sh root@<kluster-pi-agent>:~/
ssh root@<kluster-pi-agent> "bash join-k3s-agent.sh ${TOKEN} ${MASTER_1}"
```

Repeat the above for the remaining agent nodes.

## Installing metallb

``` bash
KUBECONFIG=${HOME}/.kube/kluster-pi-config bash resources/metallb/install.sh
```

## Installing Ingress Nginx

``` bash
KUBECONFIG=${HOME}/.kube/kluster-pi-config bash resources/ingress-nginx/install.sh
```

## Uninstall

Connect to each k3s node and execute:

``` bash 
/usr/local/bin/k3s-uninstall.sh
```
