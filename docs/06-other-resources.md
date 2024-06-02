# Install and deploy more resources

This is a separate section to install resources that are not required to make the cluster work.

## Installing Longhorn

It is required to work on the node.

### Requirements
``` bash
apt install jq open-iscsi nfs-common 
```

### Check
``` bash
curl -sSfL https://raw.githubusercontent.com/longhorn/longhorn/v1.5.1/scripts/environment_check.sh | bash
```

To run from the owner's machine:

``` bash
# deploy
kubectl apply -f https://raw.githubusercontent.com/longhorn/longhorn/v1.5.1/deploy/longhorn.yaml

# Create basic auth secret
USER=<USERNAME_HERE>; PASSWORD=<PASSWORD_HERE>; echo "${USER}:$(openssl passwd -stdin -apr1 <<< ${PASSWORD})" >> resources/longhorn/auth

kubectl -n longhorn-system create secret generic basic-auth --from-file=resources/longhorn/auth

# Deploy ingress
kubectl -n longhorn-system apply -f resources/longhorn/longhorn-ingress.yaml

# Create new Storage Class longhorn-pg
kubectl apply -f resources/storage-classes/longhorn-pg.yaml

# Change the default storage class
kubectl apply -f resources/storage-classes/longhorn.yaml
kubectl edit  sc local-path
```

