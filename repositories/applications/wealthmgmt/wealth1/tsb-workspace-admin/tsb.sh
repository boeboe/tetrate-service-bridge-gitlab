#!/usr/bin/env bash
#
# Helper script to configure tsb
#
ROOT_DIR="$( cd -- "$(dirname "${0}")" >/dev/null 2>&1 ; pwd -P )"

TSB_CONFIG_DIR=${ROOT_DIR}/tsb
GROUP_DIR=${TSB_CONFIG_DIR}/01-group
GROUPSETTING_DIR=${TSB_CONFIG_DIR}/02-groupsetting
ACCESSBINDING_DIR=${TSB_CONFIG_DIR}/03-accessbinding

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


if [[ ${ACTION} = "deploy" ]]; then

   # Login again as tsb admin in case of a session time-out
  print_info "Login again as tsb admin in case of a session time-out" ;
  login_tsb_admin tetrate ;

  # Configure tsb groups
  print_info "Configure tsb groups" ;
  for group_file in $(ls -1 ${GROUP_DIR}) ; do
    echo "Applying tsb configuration of '${GROUP_DIR}/${group_file}'" ;
    tctl apply -f ${GROUP_DIR}/${group_file} ;
    sleep 1 ;
  done

  # Configure tsb groupsettings
  print_info "Configure tsb groupsettings" ;
  for groupsetting_file in $(ls -1 ${GROUPSETTING_DIR}) ; do
    echo "Applying tsb configuration of '${GROUPSETTING_DIR}/${groupsetting_file}'" ;
    tctl apply -f ${GROUPSETTING_DIR}/${groupsetting_file} ;
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