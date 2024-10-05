# Load Balancers

A load balancer is a type of service that will redirect the traffic from the external network to the configured internal services.
Unfortunately this kind of service is not implemented directly by Kubernetes, but delegated to the cloud providers.

## MetalLB

[https://metallb.io/](https://metallb.io/)

MetalLB is an implementation of a Kubernetes' load balancer service for baremetal clusters (like in our case).


``` bash
kubectl apply -f "https://raw.githubusercontent.com/metallb/metallb/v0.13.11/config/manifests/metallb-native.yaml"
```

To announce the IP assigned to the services I chose [the Layer 2 configuration](https://metallb.io/configuration/#layer-2-configuration) for simplicity.

1. Create an address pool resource:

``` bash
cat > ip-address-pool.yaml <<EOF
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: first-pool
  namespace: metallb-system
spec:
  addresses:
      # e.g. if your local network is 192.168.1.0/24
      - 192.168.1.10-192.168.1.19
EOF
```

and apply it:

``` bash
kubectl apply -f ip-address-pool.yaml
```

2. Create the Level 2 Advertisement resource:

``` bash
cat > l2-advertisement.yaml <<EOF
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: kluster-pi-l2-adv
  namespace: metallb-system
spec:
  ipAddressPools:
  - first-pool
```

and apply it:

``` bash
kubectl apply -f l2-advertisement.yaml
```

