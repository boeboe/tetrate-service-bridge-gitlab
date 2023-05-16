#!/usr/bin/env bash
#
# Helper script to configure tsb
#
ROOT_DIR="$( cd -- "$(dirname "${0}")" >/dev/null 2>&1 ; pwd -P )"

CONFIG_DIR=${ROOT_DIR}/config
USER_CONFIG_FILE=${CONFIG_DIR}/01-user.yaml
TEAM_CONFIG_FILE=${CONFIG_DIR}/02-team.yaml

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

if [[ ${ACTION} = "users" ]]; then

   # Login again as tsb admin in case of a session time-out
  print_info "Login again as tsb admin in case of a session time-out" ;
  login_tsb_admin tetrate ;

  # Configure tsb users
  print_info "Configure tsb users" ;
  echo "Applying tsb configuration of '${USER_CONFIG_FILE}'" ;
  tctl apply -f ${USER_CONFIG_FILE} ;

  exit 0
fi

if [[ ${ACTION} = "teams" ]]; then

   # Login again as tsb admin in case of a session time-out
  print_info "Login again as tsb admin in case of a session time-out" ;
  login_tsb_admin tetrate ;

  # Configure tsb teams
  print_info "Configure tsb teams" ;
  echo "Applying tsb configuration of '${TEAM_CONFIG_FILE}'" ;
  tctl apply -f ${TEAM_CONFIG_FILE} ;

  exit 0
fi

echo "Please specify one of the following action:"
echo "  - users"
echo "  - teams"
exit 1