#!/usr/bin/env bash
#
# Helper script to configure tsb
#
ROOT_DIR="$( cd -- "$(dirname "${0}")" >/dev/null 2>&1 ; pwd -P )"

CONFIG_DIR=${ROOT_DIR}/config

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

# Wait for cluster to be onboarded
#   args:
#     (1) onboarding cluster name
function wait_cluster_onboarded {
  echo "Wait for cluster ${1} to be onboarded"
  while ! tctl experimental status cs ${1} | grep "Cluster onboarded" &>/dev/null ; do
    sleep 5 ;
    echo -n "."
  done
  echo "DONE"
}


if [[ ${ACTION} = "config" ]]; then

   # Login again as tsb admin in case of a session time-out
  print_info "Login again as tsb admin in case of a session time-out" ;
  login_tsb_admin tetrate ;

  # Configure tsb organization, organizationsettings  and clusters
  print_info "Configure tsb organization, organizationsettings  and clusters" ;
  tree ${CONFIG_DIR}
  for configfile in ${CONFIG_DIR}/* ; do
    echo "Applying tsb configuration of '${configfile}'" ;
    tctl apply -f ${CONFIG_DIR}/${configfile} ;
    sleep 3 ;
  done

  # Wait for clusters to be onboarded to avoid race conditions
  print_info "Wait for clusters to be fully onboarded and synchronized to avoid race conditions"
  wait_cluster_onboarded active ;
  wait_cluster_onboarded standby ;

  exit 0
fi

echo "Please specify one of the following action:"
echo "  - config"
exit 1