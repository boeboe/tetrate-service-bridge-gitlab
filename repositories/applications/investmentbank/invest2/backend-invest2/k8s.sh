#!/usr/bin/env bash
#
# Helper script to configure tsb
#
ROOT_DIR="$( cd -- "$(dirname "${0}")" >/dev/null 2>&1 ; pwd -P )"

K8S_CONFIG_DIR=${ROOT_DIR}/k8s

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

  # Configure k8s objects
  print_info "Configure k8s objects" ;
  for cluster in $(ls -1 ${K8S_CONFIG_DIR}); do
    print_info "Configure k8s object in cluster '${cluster}'" ;
    for k8s_file in $(ls -1 ${K8S_CONFIG_DIR}/${cluster}) ; do
      echo "Applying k8s configuration of '${K8S_CONFIG_DIR}/${cluster}/${k8s_file}' in cluster '${cluster}'" ;
      kubectl --context ${cluster} apply -f ${K8S_CONFIG_DIR}/${cluster}/${k8s_file} ;
      sleep 1 ;
    done    
  done

  exit 0
fi


echo "Please specify one of the following action:"
echo "  - deploy"
exit 1