#!/usr/bin/env bash
#
# Helper script to configure tsb
#
ROOT_DIR="$( cd -- "$(dirname "${0}")" >/dev/null 2>&1 ; pwd -P )"

CONFIG_DIR=${ROOT_DIR}/config
PATCH_DIR=${ROOT_DIR}/patch
UI_DIR=${ROOT_DIR}/ui

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

if [[ ${ACTION} = "ldap-sync" ]]; then

   # Create LDAP configmaps
  print_info "Create LDAP configmaps containing organization, people and groups" ;
  kubectl --context mgmt apply -f ${CONFIG_DIR} ;

  # Patch LDAP deployment
  print_info "Patch and restart demo LDAP deployment" ;
  kubectl --context mgmt patch deployment ldap --patch-file ${PATCH_DIR}/ldap-deployment.yaml -n tsb ;
  kubectl --context mgmt rollout restart deployment ldap -n tsb ;

  # Wait for auto triggered job teamsync-first-run to finish
  while ! kubectl --context mgmt get job/teamsync-first-run -n tsb &>/dev/null; do sleep 0.1; done ;
  kubectl --context mgmt wait --for=condition=complete --timeout=10m job/teamsync-first-run -n tsb ;

  # Print auto triggered job teamsync-first-run status
  kubectl --context mgmt get job/teamsync-first-run -n tsb -o jsonpath={.status} | jq

  # # Force TSB to sync users and teams from LDAP
  # print_info "Force TSB to sync users and teams from LDAP" ;
  # job_name="teamsync-$(date +%Y-%m-%d-%H-%M-%S)"
  # kubectl --context mgmt create job --from=cronjob/teamsync ${job_name} -n tsb ;

  # print_info "Wait for TSB job to sync users and teams from LDAP" ;
  # kubectl --context mgmt wait --for=condition=complete --timeout=10m job/${job_name} -n tsb ;

  exit 0
fi

if [[ ${ACTION} = "ldap-ui" ]]; then

   # Going to deploy LDAP UI for demo purposes
  print_info "Going to deploy demo LDAP UI" ;
  kubectl --context mgmt apply -f ${UI_DIR} ;

  # Get the external LB IP address of the demo LDAP UI
  LDAP_UI_ENDPOINT=$(kubectl --context mgmt get svc -n tsb ldap-ui --output jsonpath='{.status.loadBalancer.ingress[0].ip}') ;
  print_info "Demo LDAP UI available at http://${LDAP_UI_ENDPOINT}:8080" ;

  exit 0
fi

echo "Please specify one of the following action:"
echo "  - ldap-sync"
echo "  - ldap-ui"
exit 1