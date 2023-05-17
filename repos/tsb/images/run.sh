#!/usr/bin/env bash
#
# Helper script to create gitlab groups, projects and repo code
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


if [[ ${ACTION} = "sync-imgs" ]]; then
  print_info "Going fetch list of TSB container images"
  CONTAINER_LIST=$(tctl install image-sync --just-print --raw --accept-eula 2>/dev/null)
  CONTAINER_LIST="${CONTAINER_LIST} containers.dl.tetrate.io/obs-tester-server:1.0"
  CONTAINER_LIST="${CONTAINER_LIST} containers.dl.tetrate.io/netshoot:latest"

  print_info "Going to docker login with CICD credentials"
  docker login --username ${CI_REGISTRY_USER} --password ${CI_REGISTRY_PASSWORD} ${CI_REGISTRY}
  docker login --username ${TETRATE_REGISTRY_USER} --password ${TETRATE_REGISTRY_PASSWORD} ${TETRATE_REGISTRY}

  print_info "Going pull, tag and push TSB container images if needed"
  for image in ${CONTAINER_LIST} ; do
    print_info "Image: ${image}"
    image_without_repo=$(echo ${image} | sed "s|containers.dl.tetrate.io/||")
    image_name=$(echo ${image_without_repo} | awk -F: '{print $1}')
    image_tag=$(echo ${image_without_repo} | awk -F: '{print $2}')
    if ! docker image inspect ${image} &>/dev/null ; then
      docker pull ${image} ;
    fi
    if ! docker image inspect ${CI_REGISTRY_IMAGE}/${image_without_repo} &>/dev/null ; then
      docker tag ${image} ${CI_REGISTRY_IMAGE}/${image_without_repo} ;
    fi
    docker push ${CI_REGISTRY_IMAGE}/${image_without_repo} ;
  done

  print_info "Sync job finished"
  exit 0
fi


echo "Please specify one of the following action:"
echo "  - sync-imgs"
exit 1