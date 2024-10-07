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

