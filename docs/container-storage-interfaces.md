# Container Storage Interfaces

In this section we cover some of the available CSIs for Kubernetes that have been tested inside kluster-pi.

## Longhorn

[https://longhorn.io/](https://longhorn.io/)

Based on the official documentation, the new longhorn CLI `longhornctl` takes care of checking for preresquisites
and installing dependencies if missing.

Here are the instructions to perform the installation procedure by hands, or you can exec the practical `resource/longhorn/install.sh`
script which automates it.

``` bash
VERSION="v1.7.1"

# Install Longhorn CLI to install dependencied and check them
curl -sSfL -o longhornctl https://github.com/longhorn/cli/releases/download/"${VERSION}"/longhornctl-linux-arm64

chmod +x longhornctl

# Check
./longhornctl check preflight

# and if everything is OK
./longhornctl install preflight

# Deploy
kubectl apply -f https://raw.githubusercontent.com/longhorn/longhorn/"${VERSION}"/deploy/longhorn.yaml

# Create basic auth secret to access UI 
# Choose an USER and a PASSWORD
USER=<user> ; PASSWORD=<password> ; echo "${USER}:$(openssl passwd -stdin -apr1 <<< ${PASSWORD})" >> resources/longhorn/auth

kubectl -n longhorn-system create secret generic basic-auth --from-file=resources/longhorn/auth

# Deploy ingress to allow access UI
kubectl -n longhorn-system apply -f resources/longhorn/longhorn-ingress.yaml
```

## TopoLVM

[https://github.com/topolvm/topolvm](https://github.com/topolvm/topolvm)

The procedure for this resource can't be automated in the same way as the other at the moment, because it requires some prerequisites.
These prerequisites must either performed manually, executing the following procedure, or by running the `resource/topolvm/prepare_node.sh` script.
Once the requirements are respected, topoLVM can be installed using its `install.sh` script or the `scripts/deploy-resources.sh` script.

### Requirements

These steps are required before the installation of topoLVM.

#### Node Setup

1. lvm version 2.02.163 or later:

``` bash
apt install lvm2
```

2. a partition dedicated as a Physical Volume:

``` bash
pvcreate /dev/sda3
```

3. a Volume Group called `myvg1` created from the previous PV:

``` bash
vgcreate myvg1 /dev/sda3
```

#### Kubernetes Setup

4. a cert manager deployment:

``` bash
export KUBECONFIG=${HOME}/.kube/kluster-pi-config
bash scripts/deploy-resources.sh -r cert-manager -v "v1.15.1"
```

5. a namespace for topoLVM:

``` bash
kubectl create ns topolvm-system
```

6. labels on namespaces:
[https://github.com/topolvm/topolvm/blob/main/docs/getting-started.md](https://github.com/topolvm/topolvm/blob/main/docs/getting-started.md)

``` bash
kubectl label namespace topolvm-system topolvm.io/webhook=ignore
kubectl label namespace kube-system topolvm.io/webhook=ignore
```

#### Helm Setup

7. the topoLVM repository installed in Helm:

``` bash
helm repo add topolvm https://topolvm.github.io/topolvm
```

8. the Helm repo updated:

``` bash
helm repo update
```

### Install topoLVM

9. install through Helm:

``` bash
helm install --namespace=topolvm-system topolvm topolvm/topolvm
```

10. Verify the installation:

``` bash
kubectl get pod -n topolvm-system
```

