#!/usr/bin/env bash
#
# Helper script to create gitlab groups, projects and repo code
#
ROOT_DIR="$( cd -- "$(dirname "${0}")" >/dev/null 2>&1 ; pwd -P )"

MINIKUBE_CLUSTER_CONFIG=${ROOT_DIR}/minikube-clusters.json
MINIKUBE_OPTS="--driver docker --insecure-registry 192.168.47.0/24"

ACTION=${1}

# Print info messages
#   args:
#     (1) message
function print_info {
  purpleb="\033[1;35m"
  end="\033[0m"
  echo -e "${purpleb}${1}${end}"
}

# Configure metallb start and end IP (x.y.z.100-x.y.z.199)
#   args:
#     (1) cluster name
#     (2) cluster docker subnet
function configure_metallb {
  expect <<DONE
  spawn minikube --profile ${1} addons configure metallb
  expect "Enter Load Balancer Start IP:" { send "${2}.100\\r" }
  expect "Enter Load Balancer End IP:" { send "${2}.199\\r" }
  expect eof
DONE
}

# Configure minikube clusters to have access to docker repo containing tsb images
#   args:
#     (1) cluster name
function configure_docker_access {
  if $(minikube --profile ${1} ssh -- sudo cat /var/lib/kubelet/config.json | grep "192.168.47.2:5050" &>/dev/null) ; then
    echo "Docker access to '192.168.47.2:5050' already configured"
  else
    minikube --profile ${1} ssh -- docker login "192.168.47.2:5050" --username "root" --password "Tetrate123." &>/dev/null ;
    minikube --profile ${1} ssh -- sudo cp /home/docker/.docker/config.json /var/lib/kubelet ;
    minikube --profile ${1} ssh -- sudo systemctl restart kubelet ;
  fi
}


if [[ ${ACTION} = "up" ]]; then
  cluster_count=`jq '. | length' ${MINIKUBE_CLUSTER_CONFIG}`

  for ((i=0; i<$cluster_count; i++)); do
    k8s_version=`jq -r '.['$i'].k8s_version' ${MINIKUBE_CLUSTER_CONFIG}`
    cluster_name=`jq -r '.['$i'].name' ${MINIKUBE_CLUSTER_CONFIG}`
    cluster_region=`jq -r '.['$i'].region' ${MINIKUBE_CLUSTER_CONFIG}`
    cluster_zone=`jq -r '.['$i'].zone' ${MINIKUBE_CLUSTER_CONFIG}`
    print_info "================================================== ${cluster_name} =================================================="

    # Start cluster if needed
    print_info "Starting minikube cluster '${cluster_name}'"
    if minikube profile list 2>/dev/null | grep ${cluster_name} | grep "Running" &>/dev/null ; then
      echo "Minikube cluster '${cluster_name}' already running"
    else
      minikube start --kubernetes-version=v${k8s_version} --profile ${cluster_name} --network ${cluster_name} ${MINIKUBE_OPTS} ;
    fi

    # Extract the docker network subnet from the cluster
    docker_subnet=$(docker network inspect ${cluster_name} --format '{{(index .IPAM.Config 0).Subnet}}' | awk -F '.' '{ print $1"."$2"."$3;}')

    # Configure and enable metallb in the cluster
    print_info "Enable metallb addon in minikube cluster '${cluster_name}'"
    if minikube --profile ${cluster_name} addons list | grep "metallb" | grep "enabled" &>/dev/null ; then
      echo "Minikube cluster '${cluster_name}' has metallb addon already enabled"
    else
      configure_metallb ${cluster_name} ${docker_subnet} ;
      minikube --profile ${cluster_name} addons enable metallb ;
    fi

    # Disable iptables docker isolation for cluster to gitlab repo communication
    # https://serverfault.com/questions/1102209/how-to-disable-docker-network-isolation
    # https://serverfault.com/questions/830135/routing-among-different-docker-networks-on-the-same-host-machine 
    sudo iptables -t filter -F DOCKER-ISOLATION-STAGE-2

    # Make sure minikube has access to docker repo containing tsb images
    print_info "Login to gitlab docker registry at minikube cluster '${cluster_name}'"
    configure_docker_access ${cluster_name} ;

    # Add nodes labels for locality based routing (region and zone)
    print_info "Configure region and zone for minikube cluster '${cluster_name}'"
    if ! kubectl --context ${cluster_name} get nodes ${cluster_name} --show-labels | grep "topology.kubernetes.io/region=${cluster_region}" &>/dev/null ; then
      kubectl --context ${cluster_name} label node ${cluster_name} topology.kubernetes.io/region=${cluster_region} --overwrite=true ;
    fi
    if ! kubectl --context ${cluster_name} get nodes ${cluster_name} --show-labels | grep "topology.kubernetes.io/zone=${cluster_zone}" &>/dev/null ; then
      kubectl --context ${cluster_name} label node ${cluster_name} topology.kubernetes.io/zone=${cluster_zone} --overwrite=true ;
    fi
  done

  exit 0
fi

echo "Please specify one of the following action:"
echo "  - up"
exit 1