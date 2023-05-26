#!/usr/bin/env bash
#
# Helper script to configure tsb
#
ROOT_DIR="$( cd -- "$(dirname "${0}")" >/dev/null 2>&1 ; pwd -P )"

K8S_CONFIG_DIR=${ROOT_DIR}/k8s

INGRESSGATEWAY_DIR="01-ingressgateway"

OUTPUT_DIR=${ROOT_DIR}/output/k8s
CERTS_BASE_DIR=${ROOT_DIR}/output/ingress-certs/server/comm2

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
  purpleb="\033[1;35m"
  end="\033[0m"
  echo -e "${purpleb}${1}${end}"
}


if [[ ${ACTION} = "deploy" ]]; then

  # Configure k8s secrets
  print_info "Configure tier1 gateway k8s mutual tls secrets" ;
  if kubectl --context mgmt -n tier1-gw-comm2 get secret comm2-cert &>/dev/null; then
    echo "Secret 'comm2-certt' in namespace 'tier1-gw-comm2' already exists in cluster 'mgmt'"
  else
    echo "Creating secret 'comm2-cert' in namespace 'tier1-gw-comm2' in cluster 'mgmt'"
    kubectl --context mgmt create secret generic comm2-cert -n tier1-gw-comm2 \
      --from-file=tls.key=${CERTS_BASE_DIR}/comm2.demo.tetrate.io-key.pem \
      --from-file=tls.crt=${CERTS_BASE_DIR}/comm2.demo.tetrate.io-cert.pem \
      --from-file=ca.crt=${CERTS_BASE_DIR}/root-cert.pem ;
  fi
  print_info "Configure ingress gateway k8s single tls secrets" ;
  for cluster_name in active standby ; do
    if kubectl --context ${cluster_name} -n gateway-comm2 get secret comm2-cert &>/dev/null; then
      echo "Secret 'comm2-cert' in namespace 'gateway-comm2' already exists in cluster '${cluster_name}'"
    else
      echo "Creating secret 'comm2-cert' in namespace 'gateway-comm2' in cluster '${cluster_name}'"
      kubectl --context ${cluster_name} create secret tls comm2-cert -n gateway-comm2 \
        --key ${CERTS_BASE_DIR}/comm2.demo.tetrate.io-key.pem \
        --cert ${CERTS_BASE_DIR}/comm2.demo.tetrate.io-cert.pem ;
    fi
  done

  # Configure k8s ingressgateways
  print_info "Configure k8s ingressgateways" ;
  for cluster in $(ls -1 ${K8S_CONFIG_DIR}); do
    print_info "Configure k8s ingressgateways in cluster '${cluster}'" ;
    for ingressgateway_file in $(ls -1 ${K8S_CONFIG_DIR}/${cluster}/${INGRESSGATEWAY_DIR}) ; do
      echo "Applying k8s configuration of '${K8S_CONFIG_DIR}/${cluster}/${INGRESSGATEWAY_DIR}/${ingressgateway_file}' in cluster '${cluster}'" ;
      kubectl --context ${cluster} apply -f ${K8S_CONFIG_DIR}/${cluster}/${INGRESSGATEWAY_DIR}/${ingressgateway_file} ;
      sleep 1 ;
    done    
  done

  exit 0
fi


echo "Please specify one of the following action:"
echo "  - deploy"
exit 1