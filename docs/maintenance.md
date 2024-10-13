# Maintenance

## K3S upgrade

[https://docs.k3s.io/upgrades/automated](https://docs.k3s.io/upgrades/automated)

To keep your Kluster Pi up to date, Rancher created a controller to automatically upgrade the K3S cluster, node by node, using the so called [System Upgrade Controller](https://github.com/rancher/system-upgrade-controller/).

To install the controller:

``` bash
export KUBECONFIG=${HOME}/.kube/kluster-pi-config
# Y.O.L.O.
kubectl apply -k github.com/rancher/system-upgrade-controller
```

To enable the automatic upgrades:

``` bash
kubectl apply -f - <<EOF
# Server plan
apiVersion: upgrade.cattle.io/v1
kind: Plan
metadata:
  name: master-plan
  namespace: system-upgrade
spec:
  concurrency: 1
  cordon: true
  nodeSelector:
    matchExpressions:
    - key: node-role.kubernetes.io/control-plane
      operator: In
      values:
      - "true"
  serviceAccountName: system-upgrade
  upgrade:
    image: rancher/k3s-upgrade
  channel: https://update.k3s.io/v1-release/channels/stable
---
# Agent plan
apiVersion: upgrade.cattle.io/v1
kind: Plan
metadata:
  name: agent-plan
  namespace: system-upgrade
spec:
  concurrency: 1
  cordon: true
  nodeSelector:
    matchExpressions:
    - key: node-role.kubernetes.io/control-plane
      operator: DoesNotExist
  prepare:
    args:
    - prepare
    - master-plan
    image: rancher/k3s-upgrade
  serviceAccountName: system-upgrade
  upgrade:
    image: rancher/k3s-upgrade
  channel: https://update.k3s.io/v1-release/channels/stable
EOF
```

