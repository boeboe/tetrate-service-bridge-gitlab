# Minikube Infrastructure

This repo contains the code to manage kubernetes minikube based clusters. The configuration is stored in [minikube-clusters.json](./minikube-clusters.json), which can be edited to add, modify or remove clusters.


The format of [minikube-clusters.json](./minikube-clusters.json) is self explanatory.

```json
[
  {
    "k8s_version": "1.25.9",
    "name": "mgmt",
    "region": "region1",
    "zone": "zone1a"
  },
  {
    "k8s_version": "1.25.9",
    "name": "active",
    "region": "region1",
    "zone": "zone1a"
  },
  {
    "k8s_version": "1.25.9",
    "name": "standby",
    "region": "region2",
    "zone": "zone2a"
  }
]
```

Every minikube cluster is deployed as a dedicated minikube profile within a dedicated docker network. The name of the minikube profile and the docker network, matches the name of the cluster. The kubectl context will have the same name as well.

Metallb is depoyed in each cluster, exposing an ip address range of `x.y.x.100-x.y.z-199`, where `x.y.z` matches the subnet of the docker network of that cluster. In order to provide cross-cluster connectivity, `iptables` docker isolation rules are flushed (cfr [here](https://serverfault.com/questions/1102209/how-to-disable-docker-network-isolation)).
