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

# Get gitlab project's latest pipeline status
#   args:
#     (1) gitlab api url
#     (2) gitlab api token
#     (3) gitlab group path
#     (4) gitlab project name
#     (5) git pipeline job name
function download_and_extract_project_job_artifact {
  project_id=$(curl --silent --request GET --header "PRIVATE-TOKEN: ${2}" --url "${1}/projects?per_page=100" | jq ".[] | select(.name==\"${4}\") | select(.namespace.full_path==\"${3}\") " | jq -r '.id')
  job_id=$(curl --silent --request GET --header "PRIVATE-TOKEN: ${2}" --url "${1}/projects/${project_id}/jobs?per_page=100" | jq "[.[] | select(.status==\"success\") | select(.name==\"${5}\")][0]" | jq -r '.id')
  rm -f /tmp/artifacts.zip
  curl --silent --request GET --header "PRIVATE-TOKEN: ${2}" --url "${1}/projects/${project_id}/jobs/${job_id}/artifacts" --output /tmp/artifacts.zip
  unzip -o /tmp/artifacts.zip -d ${ROOT_DIR}
}


if [[ ${ACTION} = "check" ]]; then

  print_info "Wait for TSB tenant retailbank to be configured correctly (pipeline applications/retailbank/tsb-tenant-admin)"
  while true; do
    status_retailbank_tenant=$(gitlab_get_pipeline_status ${CI_API_V4_URL} "01234567890123456789" "applications/retailbank" "tsb-tenant-admin")
    if [[ ${status_retailbank_tenant} == "success" ]] ; then
      echo "OK"
      break
    else
      echo -n "."
      sleep 5 ;
      continue
    fi
  done

  print_info "Wait for istio certificates to be available (pipeline platform/certificates)"
  while true; do  
    status_platform_certificates=$(gitlab_get_pipeline_status ${CI_API_V4_URL} "01234567890123456789" "platform" "certificates")
    if [[ ${status_platform_certificates} == "success" ]] ; then
      echo "OK"
      break
    else
      echo -n "."
      sleep 5 ;
      continue
    fi
  done

  print_info "Download and extract istio certificates (latest artifact of pipeline platform/certificates)"
  download_and_extract_project_job_artifact ${CI_API_V4_URL} "01234567890123456789" "platform" "certificates" "gen-certs"
  tree ${ROOT_DIR}/output

  exit 0
fi

echo "Please specify one of the following action:"
echo "  - check"
exit 1