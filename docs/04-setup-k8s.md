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
instead of just sharing a single bash script or an ansible playbook.
But, I also provide scripts to automate some of the steps for the entire procedure to make
it repeatable and fast to deploy for experimenting.

### Select versions

There are two ways to install kubernetes resources.
The first one is using the resource's `install.sh` script (e.g. `resources/calico/install.sh`)
which has the component's version hard-code inside. The `VERSION` environement variable overrides
the hard-coded one.

Example:

``` bash
export KUBECONFIG=${HOME}/.kube/kluster-pi-config
VERSION="v0.14.8" bash resources/metallb/install.sh
```

The second approach is to use the `scripts/deploy-resources.sh` script, which accepts a single
resource name or a `resources.list` file. The `resources.list` file contains the version for each
desired component.

NOTE: check the resource file format [here](../scripts/README.md).

The `scripts/deploy-resources.sh` is basically a wrapper which calls each resource's `install.sh`
script. Versions in each resource's `install.sh` file will be overridden by the `-r resources.list`
file or by the `-v <version>` options.

Example:

``` bash
export KUBECONFIG=${HOME}/.kube/kluster-pi-config
bash scripts/deploy-resources.sh -r resources.list
```

Or:

``` bash
bash scripts/deploy-resources.sh -r <resource_name> -v <version>
```

To install `calico` the script also accepts the address/hostname of the first master:

``` bash
bash scripts/deploy-resources.sh -v v3.28.2 -h kluster-pi-01 -r calico
```

Or:

``` bash
bash scripts/deploy-resources.sh -h kluster-pi-01 -r resources.list
```

### Installing K3S

The `scripts/install-kluster.sh` file is the automation script that allows you to setup a k3s cluster
on Raspberry Pis. It takes care of all the steps in this chapter; more precisely, it will, in order:

1. install the first k3s master
2. deploy calico
3. join other masters (if any)
4. join agents (if any)
5. deploy desired resources (if defined)

Usage:

``` bash
bash scripts/install-kluster.sh -h hosts.list -r resources.list
```

The script will write the TOKEN, automatically generated, in the hidden `.k3s-token` file inside the
root of the project.

Or you can manually perform the following procedure.

## Installing the first k3s master

First node command example:

``` bash
##
MASTER_1=<kluster-pi-1st-master-ip-address>
TOKEN=`pwgen -B 20 1`
##
ssh root@${MASTER_1} <<EOS
curl -sfL https://get.k3s.io | \
    K3S_TOKEN=${TOKEN} \
    K3S_KUBECONFIG_OUTPUT=/root/k3s-kube.config \
    INSTALL_K3S_EXEC="server \
    --cluster-init \
    --cluster-cidr=10.42.0.0/16 \
    --disable-cloud-controller \
    --disable-network-policy \
    --disable=traefik \
    --disable=servicelb \
    --flannel-backend=none \
    --log=/var/log/k3s.log" \
    sh -
EOS

# Copy the newly generated Kubernetes config in the user local machine
scp root@${MASTER_1}:/root/k3s-kube.config ~/.kube/kluster-pi-config

# Replace the localhost for the API server to the first master ip address
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
MASTER_2=<kluster-pi-2nd-master-ip-address>
#
ssh root@${MASTER_2} <<EOS
curl -sfL https://get.k3s.io | \
    K3S_TOKEN=${TOKEN} \
    K3S_KUBECONFIG_OUTPUT=/root/k3s-kube.config \
    INSTALL_K3S_EXEC="server \
    --cluster-cidr=10.42.0.0/16 \
    --disable-cloud-controller \
    --disable-network-policy \
    --disable=traefik \
    --disable=servicelb \
    --flannel-backend=none \
    --log=/var/log/k3s.log \
    --server https://${MASTER_1}:6443" \
    sh -
EOS
```

Repeat the above for the remaining master nodes.

## Adding agents (if any)

``` bash
AGENT_1=<kluster-pi-1st-agent-ip-address>
#
ssh root@${AGENT_1} <<EOS
curl -sfL https://get.k3s.io | \
    K3S_TOKEN="${TOKEN}" \
    K3S_URL="https://${MASTER_1}:6443" \
    sh -
EOS
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

### Masters

Connect to each k3s master node and execute:

``` bash 
/usr/local/bin/k3s-uninstall.sh
```

### Agents

Connect to each k3s agent node and execute:

``` bash 
/usr/local/bin/k3s-agent-uninstall.sh
```

