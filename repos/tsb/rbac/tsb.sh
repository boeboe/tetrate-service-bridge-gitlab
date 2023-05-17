#!/usr/bin/env bash
#
# Helper script to configure tsb
#
ROOT_DIR="$( cd -- "$(dirname "${0}")" >/dev/null 2>&1 ; pwd -P )"

CONFIG_DIR=${ROOT_DIR}/config
ROLE_DIR=${CONFIG_DIR}/01-role
TENANT_DIR=${CONFIG_DIR}/02-tenant
TEAM_DIR=${CONFIG_DIR}/03-team
SERVICEACCOUNT_DIR=${CONFIG_DIR}/04-serviceaccount
ACCESSBINDING_DIR=${CONFIG_DIR}/05-accessbinding

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


if [[ ${ACTION} = "config" ]]; then

   # Login again as tsb admin in case of a session time-out
  print_info "Login again as tsb admin in case of a session time-out" ;
  login_tsb_admin tetrate ;

  # Configure tsb roles
  print_info "Configure tsb roles" ;
  for role_file in ${ROLE_DIR}/* ; do
    echo "Applying tsb configuration of '${role_file}'" ;
    tctl apply -f ${role_file} ;
    sleep 5 ;
  done

  # Configure tsb tenants
  print_info "Configure tsb tenants" ;
  for tenant_file in ${TENANT_DIR}/* ; do
    echo "Applying tsb configuration of '${tenant_file}'" ;
    tctl apply -f ${tenant_file} ;
    sleep 5 ;
  done

  # Configure tsb teams
  print_info "Configure tsb teams" ;
  for team_file in ${TEAM_DIR}/* ; do
    echo "Applying tsb configuration of '${team_file}'" ;
    tctl apply -f ${team_file} ;
    sleep 5 ;
  done

  # Configure tsb roles
  print_info "Configure tsb serviceaccounts" ;
  for serviceaccount_file in ${SERVICEACCOUNT_DIR}/* ; do
    echo "Applying tsb configuration of '${serviceaccount_file}'" ;
    tctl apply -f ${serviceaccount_file} ;
    sleep 5 ;
  done

  # Configure tsb accessbindings
  print_info "Configure tsb accessbindings" ;
  for accessbinding_file in ${ACCESSBINDING_DIR}/* ; do
    echo "Applying tsb configuration of '${accessbinding_file}'" ;
    tctl apply -f ${accessbinding_file} ;
    sleep 5 ;
  done

  exit 0
fi

echo "Please specify one of the following action:"
echo "  - config"
exit 1