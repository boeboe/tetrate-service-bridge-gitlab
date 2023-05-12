#!/usr/bin/env bash
#
# Helper script to install tsb control plane
#
ROOT_DIR="$( cd -- "$(dirname "${0}")" >/dev/null 2>&1 ; pwd -P )"

TSB_CP_CLUSTERS_CONFIG=${ROOT_DIR}/tsb-cp-clusters.json
CERT_OUTPUT_DIR=${ROOT_DIR}/output/istio-certs

ACTION=${1}


# Print info messages
#   args:
#     (1) message
function print_info {
  purpleb="\033[1;35m"
  end="\033[0m"
  echo -e "${purpleb}${1}${end}"
}

if [[ ${ACTION} = "install" ]]; then

  cp_cluster_count=`jq '. | length' ${TSB_CP_CLUSTERS_CONFIG}`

  for ((i=0; i<$cp_cluster_count; i++)); do
    cp_cluster_ctx=`jq -r '.['$i'].k8s_context' ${TSB_CP_CLUSTERS_CONFIG}`
    cp_cluster_name=`jq -r '.['$i'].cluster_name' ${TSB_CP_CLUSTERS_CONFIG}`
    print_info "Start installation of tsb control plane in k8s cluster '${cp_cluster_ctx}'"
  done

  tree ${CERT_OUTPUT_DIR}
  exit 0
fi

echo "Please specify one of the following action:"
echo "  - install"
exit 1