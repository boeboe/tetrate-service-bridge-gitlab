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
