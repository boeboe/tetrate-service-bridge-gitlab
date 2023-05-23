#!/usr/bin/env bash
#
# Helper script to configure tsb
#
ROOT_DIR="$( cd -- "$(dirname "${0}")" >/dev/null 2>&1 ; pwd -P )"

TSB_CONFIG_DIR=${ROOT_DIR}/tsb
WORKSPACE_DIR=${TSB_CONFIG_DIR}/01-workspace
WORKSPACESETTING_DIR=${TSB_CONFIG_DIR}/02-workspacesetting
SERVICEACCOUNT_DIR=${TSB_CONFIG_DIR}/03-serviceaccount
ACCESSBINDING_DIR=${TSB_CONFIG_DIR}/04-accessbinding

OUTPUT_DIR=${ROOT_DIR}/output/tsb

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

# Login as a serviceaccount into tsb
#   args:
#     (1) serviceaccount name
function login_tsb_serviceaccount {
  tctl config profiles set-current mgmt ;
  token=$(tctl x sa token ${1} --key-path ${OUTPUT_DIR}/${1}/private-key.jwk --expiration 1h0m0s) ;
  echo "Using token '${token}' for serviceaccount '${1}'"
  tctl config users set ${1} --token ${token} ;
  tctl config profiles set ${1} --cluster mgmt --username ${1} ;
  tctl config profiles set-current ${1} ;
  tctl config profiles list ;
}

# Revoke all serviceaccount keys
#   args:
#     (1) serviceaccount name
function sa_revoke_all_keys {
  for key_id in $(tctl get serviceaccount ${1} -o json | jq -r '.spec.keys[].id'); do
    echo "Revoking key pair with id '${key_id}' from serviceaccount '${1}'"
    tctl x sa revoke-key ${1} --id ${key_id} ;
  done
  
}

# Generate new serviceaccount key
#   args:
#     (1) serviceaccount name
#     (2) output file
function sa_generate_new_key {
  echo "Generating new key pair at '${2}' for serviceaccount '${1}'"
  tctl x sa gen-key ${1} > ${2}
}

if [[ ${ACTION} = "deploy" ]]; then

   # Login with tsb serviceaccount publicbanking
  print_info "Login with tsb serviceaccount 'publicbanking'" ;
  login_tsb_serviceaccount publicbanking ;

  # Configure tsb workspaces
  print_info "Configure tsb workspaces" ;
  for workspace_file in $(ls -1 ${WORKSPACE_DIR}) ; do
    echo "Applying tsb configuration of '${WORKSPACE_DIR}/${workspace_file}'" ;
    tctl apply -f ${WORKSPACE_DIR}/${workspace_file} ;
    sleep 1 ;
  done

  # Configure tsb workspacesettings
  print_info "Configure tsb workspacesettings" ;
  for workspacesetting_file in $(ls -1 ${WORKSPACESETTING_DIR}) ; do
    echo "Applying tsb configuration of '${WORKSPACESETTING_DIR}/${workspacesetting_file}'" ;
    tctl apply -f ${WORKSPACESETTING_DIR}/${workspacesetting_file} ;
    sleep 1 ;
  done

  # Configure tsb serviceaccounts
  print_info "Configure tsb serviceaccounts" ;
  for serviceaccount_file in $(ls -1 ${SERVICEACCOUNT_DIR}) ; do
    echo "Applying tsb configuration of '${SERVICEACCOUNT_DIR}/${serviceaccount_file}'" ;
    tctl apply -f ${SERVICEACCOUNT_DIR}/${serviceaccount_file} ;

    serviceaccount=$(cat ${SERVICEACCOUNT_DIR}/${serviceaccount_file} | grep "name: " | awk '{print $2}') ;
    sa_revoke_all_keys ${serviceaccount} ;
    mkdir -p ${OUTPUT_DIR}/${serviceaccount} ;
    sa_generate_new_key ${serviceaccount} ${OUTPUT_DIR}/${serviceaccount}/private-key.jwk ;
    sleep 1 ;
  done

  # Configure tsb accessbindings
  print_info "Configure tsb accessbindings" ;
  for accessbinding_file in $(ls -1 ${ACCESSBINDING_DIR}) ; do
    echo "Applying tsb configuration of '${ACCESSBINDING_DIR}/${accessbinding_file}'" ;
    tctl apply -f ${ACCESSBINDING_DIR}/${accessbinding_file} ;
    sleep 1 ;
  done

  exit 0
fi

echo "Please specify one of the following action:"
echo "  - deploy"
exit 1