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

  print_info "Check if TSB container images are available (pipeline tsb/images)"
  status_tsb_images=$(gitlab_get_pipeline_status ${CI_API_V4_URL} "01234567890123456789" "tsb" "images")
  if [[ ${status_tsb_images} == "success" ]] ; then
    echo "Upstream pipeline tsb/images status: success"
  else
    echo "Upstream pipeline tsb/images status: '${status_tsb_images}', exiting..."
    exit 1
  fi

  print_info "Check if minikube based kubernetes clusters are available (pipeline infra/minikube)"
  status_infra_minikube=$(gitlab_get_pipeline_status ${CI_API_V4_URL} "01234567890123456789" "infra" "minikube")
  if [[ ${status_infra_minikube} == "success" ]] ; then
    echo "Status pipeline infra/minikube: success"
  else
    echo "Upstream pipeline infra/minikube status: '${status_infra_minikube}', exiting..."
    exit 1
  fi

  exit 0
fi

echo "Please specify one of the following action:"
echo "  - check"
exit 1