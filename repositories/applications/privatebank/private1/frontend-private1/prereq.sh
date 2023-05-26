#!/usr/bin/env bash
#
# Helper script to check upstream pipeline statuses
#
ROOT_DIR="$( cd -- "$(dirname "${0}")" >/dev/null 2>&1 ; pwd -P )"

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

# Get gitlab project's latest pipeline status
#   args:
#     (1) gitlab api url
#     (2) gitlab api token
#     (3) gitlab group path
#     (4) gitlab project name
function gitlab_get_pipeline_status {
  project_id=$(curl --silent --request GET --header "PRIVATE-TOKEN: ${2}" --url "${1}/projects?per_page=100" | jq ".[] | select(.name==\"${4}\") | select(.namespace.full_path==\"${3}\") " | jq -r '.id')
  curl --silent --request GET --header "PRIVATE-TOKEN: ${2}" --url "${1}/projects/${project_id}/pipelines/latest" | jq -r ".status"
}


if [[ ${ACTION} = "check" ]]; then

  print_info "Wait for tenant namespaces to be configured correctly (pipeline applications/privatebank/tsb-tenant-admin)"
  while true; do
    status_tenant_namespaces=$(gitlab_get_pipeline_status ${CI_API_V4_URL} "01234567890123456789" "applications/privatebank" "tsb-tenant-admin")
    if [[ ${status_tenant_namespaces} == "success" ]] ; then
      echo "OK"
      break
    else
      echo -n "."
      sleep 5 ;
      continue
    fi
  done

  exit 0
fi

echo "Please specify one of the following action:"
echo "  - check"
exit 1