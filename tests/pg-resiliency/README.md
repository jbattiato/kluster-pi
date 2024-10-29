# Resiliency Test

This test is thought and designed to answer a few sensible questions: 

1. Can a single node CNPG cluster recover from primary failure using redundant volume replicas?
2. Is a 3 node CNPG cluster an overdesign or an overzealousness act?
3. Can CNPG guarantee consistency and recoverability from failure with no PostgreSQL replicas, but only using volume replicas?
4. Which technology between CSI volume replication and PostgreSQL streaming replication allows a CNPG primary to recover faster?

## Requirements

In order to work inside the Kluster-Pi, this test requires:

* the latest version of the chosen CSI
* the latest version of CNPG operator
* the latest version of MetalLB
* the storage class for PostgreSQL test to have the volume replication disabled
* the storage class for the CSI test to have the volume replication enabled

## Clusters

The available YAML manifests in this directory contain the definition of CNPG clusters.

### PostgreSQL Cluster

The `cluster_pg-based-replicas.yaml` manifest, as the name suggests, will create a CNPG cluster with 3 nodes:
one primary and two replicas in streaming replication.
The storage class used by this cluster don't make use of volume replication.

### Longhorn Cluster

The `cluster_longhorn-based-replicas.yaml` manifest, as the name suggests, will create a CNPG cluster with a single primary node.
The storage class used by this cluster make use of volume replication in the other nodes through Longhorn.

## The script

The `resiliency-test.sh` script in this section is designed to run against a single CNPG cluster at a time.
It will basically simulate a failure of the PostgreSQL primary by deleting the CNPG primary pod and cordoning the k3s node. 
This forces the CNPG operator to either create a new primary in a different k3s node in case of a single node CNPG cluster, or
promote the most advanced replica in case of a 3 node CNPG cluster.

In order to measure the downtime the test will write constantly a timestamp inside a table of the target database. The result
will be the difference between the latest written timestamp before the failure and the first timestamp written after the
primary restarted accepting writes.

## Procedure

1. Apply one cluster manifest
  ``` bash
  kubectl apply -f <cluster_*.yaml>
  ```

2. gather the load balancer IP:
  ``` bash
  kubectl get svc -o custom-columns=:.metadata.name,:.status.loadBalancer.ingress[].ip | grep db-lb
  ```

3. get cluster name
  ``` bash
  kubectl get cluster
  ```

4. run the script:
  ``` bash
  bash resiliency-test.sh <cluster-name> <load-balancer-IP>
  ```

5. compare results
  ``` bash
  head ./downtime*
  ```

Who's gonna win?

