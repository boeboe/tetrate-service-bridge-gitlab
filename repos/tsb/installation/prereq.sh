#!/usr/bin/env bash
#
# Helper script to check upstream pipeline statuses
#
ROOT_DIR="$( cd -- "$(dirname "${0}")" >/dev/null 2>&1 ; pwd -P )"

ACTION=${1}


# Print info messages
#   args:
#     (1) message
function print_info {
  purpleb="\033[1;35m"
  end="\033[0m"
  echo -e "${purpleb}${1}${end}"
}

# Get gitlab project id in group
#   args:
#     (1) gitlab api url
#     (2) gitlab api token
#     (3) gitlab group name
#     (4) gitlab project name
function gitlab_get_pipeline_status {
  project_id=$(curl --silent --request GET --header "PRIVATE-TOKEN: ${2}" --url "${1}/projects" | jq ".[] | select(.namespace.name=\"${3}\") | select(.name==\"${4}\")" | jq -r '.id')
  curl --silent --request GET --header "PRIVATE-TOKEN: ${2}" --url "${1}/projects/${project_id}/pipelines/latest" | jq -r ".status"
}


if [[ ${ACTION} = "check" ]]; then

  print_info "Wait for TSB container images to be available (pipeline tsb/images)"
  while true; do  
    status_tsb_images=$(gitlab_get_pipeline_status ${CI_API_V4_URL} "01234567890123456789" "tsb" "images")
    if [[ ${status_tsb_images} == "success" ]] ; then
      echo "OK"
      break
    else
      echo -n "."
      sleep 5 ;
      continue
    fi
  done

  print_info "Wait for minikube based kubernetes clusters to be available (pipeline infra/minikube)"
  while true; do  
    status_infra_minikube=$(gitlab_get_pipeline_status ${CI_API_V4_URL} "01234567890123456789" "infra" "minikube")
    if [[ ${status_infra_minikube} == "success" ]] ; then
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