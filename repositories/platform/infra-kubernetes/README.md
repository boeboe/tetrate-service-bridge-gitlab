# Local Kubernetes Infrastructure

This repo contains the code to manage local `k3s`, `kind` or `minikube` based kubernetes clusters. The configuration is stored in [k8s-clusters.json](./k8s-clusters.json), which can be edited to add, modify or remove clusters.


The format of [minikube-clusters.json](./k8s-clusters.json) is self explanatory.

```json
[
  {
    "k8s_type": "k3s",
    "k8s_version": "1.25.9",
    "name": "mgmt",
    "region": "region1",
    "zone": "zone1a"
  },
  {
    "k8s_type": "kind",
    "k8s_version": "1.25.9",
    "name": "active",
    "region": "region1",
    "zone": "zone1a"
  },
  {
    "k8s_type": "minikube",
    "k8s_version": "1.25.9",
    "name": "standby",
    "region": "region2",
    "zone": "zone2a"
  }
]
```

Every kubernetes cluster is deployed within a dedicated `docker network`. The name of the cluster profile and the docker network, matches the name of the cluster. The kubectl context will have the same name as well.

Addons like `metallb` and `metrics-server` are depoyed in each cluster. Metallb is exposing an ip address range of `x.y.x.100-x.y.z-199`, where `x.y.z` matches the subnet of the docker network of that cluster. In order to provide cross-cluster connectivity, `iptables` docker isolation rules are flushed (cfr [here](https://serverfault.com/questions/1102209/how-to-disable-docker-network-isolation)).
