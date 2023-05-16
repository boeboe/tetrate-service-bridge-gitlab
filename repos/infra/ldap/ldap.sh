#!/usr/bin/env bash
#
# Helper script to configure tsb
#
ROOT_DIR="$( cd -- "$(dirname "${0}")" >/dev/null 2>&1 ; pwd -P )"

CONFIG_DIR=${ROOT_DIR}/config
PATCH_DIR=${ROOT_DIR}/patch

ACTION=${1}


# Print info messages
#   args:
#     (1) message
function print_info {
  purpleb="\033[1;35m"
  end="\033[0m"
  echo -e "${purpleb}${1}${end}"
}

if [[ ${ACTION} = "sync" ]]; then

   # Create LDAP configmaps
  print_info "Create LDAP configmaps containing organization, people and groups" ;
  kubectl --context mgmt apply -f ${CONFIG_DIR}

  # Patch LDAP deployment
  print_info "Patch and restart LDAP deployment" ;
  kubectl --context mgmt patch deployment ldap --patch-file ${PATCH_DIR}/ldap-deployment.yaml -n tsb
  kubectl --context mgmt rollout restart deployment ldap -n tsb

  # Force TSB to sync users and teams from LDAP
  print_info "Force TSB to sync users and teams from LDAP" ;
  kubectl --context mgmt create job --from=cronjob/teamsync teamsync-$(date +%Y-%m-%d-%H-%M-%S) -n tsb

  exit 0
fi

echo "Please specify one of the following action:"
echo "  - sync"
exit 1