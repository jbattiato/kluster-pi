# Databases

## CloudNativePG

Is an OpenSource Kubernetes Operator to manage the entire lifecycle of a PostgreSQL cluster.

[cloudnative-pg.io](cloudnative-pg.io)

This operator can be installed and deployed with its own `resources/cloudnative-pg/install.sh`
script or during the K3S cluster setup through the `scripts/install-kluster.sh`.

### Requirements

* A storage class with locality (use the volume on the local node where the Pod is running)
* No volume replicas (PostgreSQL takes care of data replication)

NOTE: currently tested with localpath and longhorn.

### Installation

``` bash
VERSION=1.24.0 bash resources/cloudnative-pg/install.sh
```

### Deploy a PostgreSQL cluster

To test the minimum working cluster definition:

``` bash
kubectl apply -f - <<EOS
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: cluster-example-localpath
spec:
  instances: 3

  primaryUpdateStrategy: unsupervised

  storage:
    size: 1Gi
    storageClass: local-path
EOS
```

### Deploy a cluster using Longhorn

Add custom storage classes:

``` bash
# Create new Storage Class longhorn-pg
kubectl apply -f resources/storage-classes/longhorn-pg.yaml
```

``` bash
kubectl apply -f - <<EOS
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: cluster-example-longhorn
spec:
  instances: 3

  primaryUpdateStrategy: unsupervised

  storage:
    size: 1Gi
    storageClass: longhorn-pg
EOS
```

