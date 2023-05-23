#!/usr/bin/env bash
#
# Helper script to configure tsb
#
ROOT_DIR="$( cd -- "$(dirname "${0}")" >/dev/null 2>&1 ; pwd -P )"

TSB_CONFIG_DIR=${ROOT_DIR}/tsb
ROLE_DIR=${TSB_CONFIG_DIR}/01-role
TENANT_DIR=${TSB_CONFIG_DIR}/02-tenant
TENANTSETTING_DIR=${TSB_CONFIG_DIR}/03-tenantsetting
TEAM_DIR=${TSB_CONFIG_DIR}/04-team
SERVICEACCOUNT_DIR=${TSB_CONFIG_DIR}/05-serviceaccount
ACCESSBINDING_DIR=${TSB_CONFIG_DIR}/06-accessbinding

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


if [[ ${ACTION} = "deploy" ]]; then

   # Login again as tsb admin in case of a session time-out
  print_info "Login again as tsb admin in case of a session time-out" ;
  login_tsb_admin tetrate ;

  # Configure tsb roles
  print_info "Configure tsb roles" ;
  for role_file in $(ls -1 ${ROLE_DIR}) ; do
    echo "Applying tsb configuration of '${ROLE_DIR}/${role_file}'" ;
    tctl apply -f ${ROLE_DIR}/${role_file} ;
    sleep 1 ;
  done

  # Configure tsb tenants
  print_info "Configure tsb tenants" ;
  for tenant_file in $(ls -1 ${TENANT_DIR}) ; do
    echo "Applying tsb configuration of '${TENANT_DIR}/${tenant_file}'" ;
    tctl apply -f ${TENANT_DIR}/${tenant_file} ;
    sleep 1 ;
  done

  # Configure tsb tenantsettings
  print_info "Configure tsb tenantsettings" ;
  for tenantsetting_file in $(ls -1 ${TENANTSETTING_DIR}) ; do
    echo "Applying tsb configuration of '${TENANTSETTING_DIR}/${tenantsetting_file}'" ;
    tctl apply -f ${TENANTSETTING_DIR}/${tenantsetting_file} ;
    sleep 1 ;
  done

  # Configure tsb teams
  print_info "Configure tsb teams" ;
  for team_file in $(ls -1 ${TEAM_DIR}) ; do
    echo "Applying tsb configuration of '${TEAM_DIR}/${team_file}'" ;
    tctl apply -f ${TEAM_DIR}/${team_file} ;
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