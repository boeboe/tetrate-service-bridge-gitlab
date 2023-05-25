#!/usr/bin/env bash
#
# Helper script to configure tsb
#
ROOT_DIR="$( cd -- "$(dirname "${0}")" >/dev/null 2>&1 ; pwd -P )"

K8S_CONFIG_DIR=${ROOT_DIR}/k8s

NAMESPACE_DIR="01-namespace"
SERVICEACCOUNT_DIR="02-serviceaccount"
ROLE_DIR="03-role"
ROLEBINDING_DIR="04-rolebinding"

OUTPUT_DIR=${ROOT_DIR}/output/k8s

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

  # Configure k8s namespaces
  print_info "Configure k8s namespaces" ;
  for cluster in $(ls -1 ${K8S_CONFIG_DIR}); do
    print_info "Configure k8s namespaces in cluster '${cluster}'" ;
    for namespace_file in $(ls -1 ${K8S_CONFIG_DIR}/${cluster}/${NAMESPACE_DIR}) ; do
      echo "Applying k8s configuration of '${K8S_CONFIG_DIR}/${cluster}/${NAMESPACE_DIR}/${namespace_file}' in cluster '${cluster}'" ;
      kubectl --context ${cluster} apply -f ${K8S_CONFIG_DIR}/${cluster}/${NAMESPACE_DIR}/${namespace_file} ;
      sleep 1 ;
    done    
  done

  # Configure k8s serviceaccounts
  print_info "Configure k8s serviceaccounts" ;
  for cluster in $(ls -1 ${K8S_CONFIG_DIR}); do
    print_info "Configure k8s serviceaccounts in cluster '${cluster}'" ;
    for serviceaccount_file in $(ls -1 ${K8S_CONFIG_DIR}/${cluster}/${SERVICEACCOUNT_DIR}) ; do
      echo "Applying k8s configuration of '${K8S_CONFIG_DIR}/${cluster}/${SERVICEACCOUNT_DIR}/${serviceaccount_file}' in cluster '${cluster}'" ;
      kubectl --context ${cluster} apply -f ${K8S_CONFIG_DIR}/${cluster}/${SERVICEACCOUNT_DIR}/${serviceaccount_file} ;
      sleep 1 ;
    done    
  done

  # Configure k8s roles
  print_info "Configure k8s roles" ;
  for cluster in $(ls -1 ${K8S_CONFIG_DIR}); do
    print_info "Configure k8s roles in cluster '${cluster}'" ;
    for role_file in $(ls -1 ${K8S_CONFIG_DIR}/${cluster}/${ROLE_DIR}) ; do
      echo "Applying k8s configuration of '${K8S_CONFIG_DIR}/${cluster}/${ROLE_DIR}/${role_file}' in cluster '${cluster}'" ;
      kubectl --context ${cluster} apply -f ${K8S_CONFIG_DIR}/${cluster}/${ROLE_DIR}/${role_file} ;
      sleep 1 ;
    done    
  done

  # Configure k8s rolebindings
  print_info "Configure k8s rolebindings" ;
  for cluster in $(ls -1 ${K8S_CONFIG_DIR}); do
    print_info "Configure k8s rolebindings in cluster '${cluster}'" ;
    for rolebinding_file in $(ls -1 ${K8S_CONFIG_DIR}/${cluster}/${ROLEBINDING_DIR}) ; do
      echo "Applying k8s configuration of '${K8S_CONFIG_DIR}/${cluster}/${ROLEBINDING_DIR}/${rolebinding_file}' in cluster '${cluster}'" ;
      kubectl --context ${cluster} apply -f ${K8S_CONFIG_DIR}/${cluster}/${ROLEBINDING_DIR}/${rolebinding_file} ;
      sleep 1 ;
    done    
  done

  exit 0
fi


echo "Please specify one of the following action:"
echo "  - deploy"
exit 1