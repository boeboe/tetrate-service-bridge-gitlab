#!/usr/bin/env bash
#
# Helper script to install tsb demo management/control plane
#
ROOT_DIR="$( cd -- "$(dirname "${0}")" >/dev/null 2>&1 ; pwd -P )"

TSB_MP_CLUSTER_CONFIG=${ROOT_DIR}/tsb-mp-cluster.json
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

  mp_cluster_ctx=`jq -r '.k8s_context' ${TSB_MP_CLUSTER_CONFIG}`
  mp_cluster_name=`jq -r '.cluster_name' ${TSB_MP_CLUSTER_CONFIG}`
  print_info "Start installation of tsb demo management/control plane in k8s cluster '${mp_cluster_name}'"

  if kubectl --context ${mp_cluster_ctx} get ns istio-system &>/dev/null; then
    echo "Namespace 'istio-system' already exists in cluster ${mp_cluster_name}"
  else
    kubectl --context ${mp_cluster_ctx} create ns istio-system ;
  fi
  if kubectl --context ${mp_cluster_ctx} -n istio-system get secret cacerts &>/dev/null; then
    echo "Secret 'cacerts' in namespace 'istio-system' already exists in cluster ${mp_cluster_name}"
  else
    kubectl --context ${mp_cluster_ctx} create secret generic cacerts -n istio-system \
      --from-file=${CERT_OUTPUT_DIR}/${mp_cluster_name}/ca-cert.pem \
      --from-file=${CERT_OUTPUT_DIR}/${mp_cluster_name}/ca-key.pem \
      --from-file=${CERT_OUTPUT_DIR}/${mp_cluster_name}/root-cert.pem \
      --from-file=${CERT_OUTPUT_DIR}/${mp_cluster_name}/cert-chain.pem ;
  fi

  exit 0
fi

echo "Please specify one of the following action:"
echo "  - install"
exit 1