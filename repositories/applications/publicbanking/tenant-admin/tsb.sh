#!/usr/bin/env bash
#
# Helper script to configure tsb
#
ROOT_DIR="$( cd -- "$(dirname "${0}")" >/dev/null 2>&1 ; pwd -P )"

TSB_CONFIG_DIR=${ROOT_DIR}/tsb
WORKSPACE_DIR=${TSB_CONFIG_DIR}/01-workspace
WORKSPACESETTING_DIR=${TSB_CONFIG_DIR}/02-workspacesetting
TEAM_DIR=${TSB_CONFIG_DIR}/03-team
SERVICEACCOUNT_DIR=${TSB_CONFIG_DIR}/04-serviceaccount
ACCESSBINDING_DIR=${TSB_CONFIG_DIR}/05-accessbinding

OUTPUT_DIR=${ROOT_DIR}/output/tsb

ACTION=${1}


# Print info messages
#   args:
#     (1) message
function print_info {
  purpleb="\033[1;35m"
  end="\033[0m"
  echo -e "${purpleb}${1}${end}"
}

# Login as admin into tsb
#   args:
#     (1) organization
function login_tsb_admin {
  expect <<DONE
  spawn tctl login --username admin --password admin --org ${1}
  expect "Tenant:" { send "\\r" }
  expect eof
DONE
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

if [[ ${ACTION} = "config-workspaces" ]]; then

   # Login again as tsb admin in case of a session time-out
  print_info "Login again as tsb admin in case of a session time-out" ;
  login_tsb_admin tetrate ;

  # Configure tsb workspaces
  print_info "Configure tsb workspaces" ;
  for workspace_file in ${WORKSPACE_DIR}/* ; do
    echo "Applying tsb configuration of '${workspace_file}'" ;
    tctl apply -f ${workspace_file} ;
    sleep 1 ;
  done

  exit 0
fi

if [[ ${ACTION} = "config-workspacesettings" ]]; then

   # Login again as tsb admin in case of a session time-out
  print_info "Login again as tsb admin in case of a session time-out" ;
  login_tsb_admin tetrate ;

  # Configure tsb workspacesettings
  print_info "Configure tsb workspacesettings" ;
  for workspacesetting_file in ${WORKSPACESETTING_DIR}/* ; do
    echo "Applying tsb configuration of '${workspacesetting_file}'" ;
    tctl apply -f ${workspacesetting_file} ;
    sleep 1 ;
  done

  exit 0
fi

if [[ ${ACTION} = "config-teams" ]]; then

   # Login again as tsb admin in case of a session time-out
  print_info "Login again as tsb admin in case of a session time-out" ;
  login_tsb_admin tetrate ;

  # Configure tsb teams
  print_info "Configure tsb teams" ;
  for team_file in ${TEAM_DIR}/* ; do
    echo "Applying tsb configuration of '${team_file}'" ;
    tctl apply -f ${team_file} ;
    sleep 1 ;
  done

  exit 0
fi

if [[ ${ACTION} = "config-serviceaccounts" ]]; then

   # Login again as tsb admin in case of a session time-out
  print_info "Login again as tsb admin in case of a session time-out" ;
  login_tsb_admin tetrate ;

  # Configure tsb serviceaccounts
  print_info "Configure tsb serviceaccounts" ;
  for serviceaccount_file in ${SERVICEACCOUNT_DIR}/* ; do
    echo "Applying tsb configuration of '${serviceaccount_file}'" ;
    tctl apply -f ${serviceaccount_file} ;

    serviceaccount=$(cat ${serviceaccount_file} | grep "name: " | awk '{print $2}') ;
    sa_revoke_all_keys ${serviceaccount} ;
    mkdir -p ${OUTPUT_DIR}/${serviceaccount} ;
    sa_generate_new_key ${serviceaccount} ${OUTPUT_DIR}/${serviceaccount}/private-key.jwk ;
    sleep 1 ;
  done

  exit 0
fi

if [[ ${ACTION} = "config-accessbindings" ]]; then

   # Login again as tsb admin in case of a session time-out
  print_info "Login again as tsb admin in case of a session time-out" ;
  login_tsb_admin tetrate ;

  # Configure tsb accessbindings
  print_info "Configure tsb accessbindings" ;
  for accessbinding_file in ${ACCESSBINDING_DIR}/* ; do
    echo "Applying tsb configuration of '${accessbinding_file}'" ;
    tctl apply -f ${accessbinding_file} ;
    sleep 1 ;
  done

  exit 0
fi

echo "Please specify one of the following action:"
echo "  - config-workspaces"
echo "  - config-workspacesettings"
echo "  - config-teams"
echo "  - config-serviceaccounts"
echo "  - config-accessbindings"
exit 1