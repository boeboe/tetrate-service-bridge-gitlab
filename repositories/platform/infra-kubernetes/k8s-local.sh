#!/usr/bin/env bash
#
# Helper script to manage minikube based kubernetes clusters
#
ROOT_DIR="$( cd -- "$(dirname "${0}")" >/dev/null 2>&1 ; pwd -P )"
source ${ROOT_DIR}/k8s-local-api.sh

KUBERNETES_CLUSTER_CONFIG=${ROOT_DIR}/k8s-clusters.json
GITLAB_DOCKER_REPO="192.168.47.2:5050"

ACTION=${1}

# -e exits on error
# -u errors on undefined variables
# -x prints commands before execution
# -o (for option) pipefail exits on command pipe failures
set -euo pipefail

# Print info messages
#   args:
#     (1) message
function print_info {
  [[ -z "${1}" ]] && echo "Please provide message as 1st argument" && return 2 || local message="${1}" ;
  local purpleb="\033[1;35m"
  local end="\033[0m"
  echo -e "${purpleb}${message}${end}"
}


if [[ ${ACTION} = "up" ]]; then
  cluster_count=`jq '. | length' ${KUBERNETES_CLUSTER_CONFIG}`

  for ((i=0; i<$cluster_count; i++)); do
    k8s_type=`jq -r '.['$i'].k8s_type' ${KUBERNETES_CLUSTER_CONFIG}`
    k8s_version=`jq -r '.['$i'].k8s_version' ${KUBERNETES_CLUSTER_CONFIG}`
    cluster_name=`jq -r '.['$i'].name' ${KUBERNETES_CLUSTER_CONFIG}`
    cluster_region=`jq -r '.['$i'].region' ${KUBERNETES_CLUSTER_CONFIG}`
    cluster_zone=`jq -r '.['$i'].zone' ${KUBERNETES_CLUSTER_CONFIG}`
    print_info "================================================== ${cluster_name} cluster (type ${k8s_type}) =================================================="

    # Start cluster if needed
    print_info "Starting '${k8s_type}' based kubernetes cluster '${cluster_name}'"
    start_cluster "${k8s_type}" "${cluster_name}" "${k8s_version}" "${cluster_name}" "" "${GITLAB_DOCKER_REPO}" ;
    wait_cluster_ready "${k8s_type}" "${cluster_name}" ;

    # Add nodes labels for locality based routing (region and zone)
    for node_name in $(kubectl --context ${cluster_name} get nodes -o custom-columns=":metadata.name" --no-headers=true); do
      if ! kubectl --context ${cluster_name} get node ${node_name} --show-labels | grep "topology.kubernetes.io/region=${cluster_region}" &>/dev/null ; then
        kubectl --context ${cluster_name} label node ${node_name} topology.kubernetes.io/region=${cluster_region} --overwrite=true ;
      fi
      if ! kubectl --context ${cluster_name} get node ${node_name} --show-labels | grep "topology.kubernetes.io/zone=${cluster_zone}" &>/dev/null ; then
        kubectl --context ${cluster_name} label node ${node_name} topology.kubernetes.io/zone=${cluster_zone} --overwrite=true ;
      fi
    done
  done

  exit 0
fi

echo "Please specify one of the following action:"
echo "  - up"
exit 1