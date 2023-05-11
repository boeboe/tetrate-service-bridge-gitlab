#!/usr/bin/env bash
#
# Helper script to create gitlab groups, projects and repo code
#
ROOT_DIR="$( cd -- "$(dirname "${0}")" >/dev/null 2>&1 ; pwd -P )"
source ${ROOT_DIR}/helpers.sh
source ${ROOT_DIR}/gitlab-api.sh

ACTION=${1}

GITLAB_CONTAINER_NAME="gitlab-ee"
GITLAB_DOCKER_PORT=5050

GITLAB_ROOT_PASSWORD="Tetrate123."
GITLAB_ROOT_TOKEN="01234567890123456789"

GITLAB_REPOS_DIR=${ROOT_DIR}/repos
GITLAB_REPOS_CONFIG=${GITLAB_REPOS_DIR}/repos.json
GITLAB_REPOS_TEMPDIR=/tmp/repos


# Get local gitlab http endpoint
#   args:
#     (1) gitlab name
function get_gitlab_http_url {
  if ! IP=$(docker inspect --format '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' ${1}  2>/dev/null ); then
    print_error "Local docker repo not running" ; 
    exit 1 ;
  fi
  echo "http://${IP}:80" ;
}

# Get local gitlab http endpoint with credentials
#   args:
#     (1) gitlab name
function get_gitlab_http_url_with_credentials {
  if ! IP=$(docker inspect --format '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' ${1}  2>/dev/null ); then
    print_error "Local docker repo not running" ; 
    exit 1 ;
  fi
  echo "http://root:${GITLAB_ROOT_PASSWORD}@${IP}:80" ;
}

# Get local gitlab docker endpoint
#   args:
#     (1) gitlab name
function get_gitlab_docker_endpoint {
  if ! IP=$(docker inspect --format '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' ${1}  2>/dev/null ); then
    print_error "Local docker repo not running" ; 
    exit 1 ;
  fi
  echo "${IP}:${GITLAB_DOCKER_PORT}" ;
}

# Sync tsb docker images into gitlab docker repo (if not yet available)
#   args:
#     (1) gitlab docker repo endpoint
function sync_tsb_images {
    # Sync all tsb images locally
    for image in `tctl install image-sync --just-print --raw --accept-eula 2>/dev/null` ; do
      image_without_repo=$(echo ${image} | sed "s|containers.dl.tetrate.io/||")
      image_name=$(echo ${image_without_repo} | awk -F: '{print $1}')
      image_tag=$(echo ${image_without_repo} | awk -F: '{print $2}')
      if ! docker image inspect ${image} &>/dev/null ; then
        docker pull ${image} ;
      fi
      if ! docker image inspect ${1}/${image_without_repo} &>/dev/null ; then
        docker tag ${image} ${1}/${image_without_repo} ;
      fi
      if ! curl -s -X GET ${1}/v2/${image_name}/tags/list | grep "${image_tag}" &>/dev/null ; then
        docker push ${1}/${image_without_repo} ;
      fi
    done

    # Sync image for application deployment
    if ! docker image inspect containers.dl.tetrate.io/obs-tester-server:1.0 &>/dev/null ; then
      docker pull containers.dl.tetrate.io/obs-tester-server:1.0 ;
    fi
    if ! docker image inspect ${1}/obs-tester-server:1.0 &>/dev/null ; then
      docker tag containers.dl.tetrate.io/obs-tester-server:1.0 ${1}/obs-tester-server:1.0 ;
    fi
    if ! curl -s -X GET ${1}/v2/obs-tester-server/tags/list | grep "1.0" &>/dev/null ; then
      docker push ${1}/obs-tester-server:1.0 ;
    fi

    # Sync image for debugging
    if ! docker image inspect containers.dl.tetrate.io/netshoot &>/dev/null ; then
      docker pull containers.dl.tetrate.io/netshoot ;
    fi
    if ! docker image inspect ${1}/netshoot &>/dev/null ; then
      docker tag containers.dl.tetrate.io/netshoot ${1}/netshoot ;
    fi
    if ! curl -s -X GET ${1}/v2/netshoot/tags/list | grep "latest" &>/dev/null ; then
      docker push ${1}/netshoot ;
    fi

    print_info "All tsb images synced and available in the local repo"
}


if [[ ${ACTION} = "sync-images" ]]; then
  GITLAB_DOCKER_ENDPOINT=$(get_gitlab_docker_endpoint ${GITLAB_CONTAINER_NAME})

  if ! docker login ${GITLAB_DOCKER_ENDPOINT} --username "root" --password ${GITLAB_ROOT_PASSWORD} 2>/dev/null; then
    echo "Failed to login to docker registry at ${GITLAB_DOCKER_ENDPOINT}. Check your credentials (root/${GITLAB_ROOT_PASSWORD})"
    exit 1
  fi

  GITLAB_DOCKER_IMAGES_ENDPOINT=${GITLAB_DOCKER_ENDPOINT}/tsb/images
  print_info "Going to sync tsb images to repo ${GITLAB_DOCKER_IMAGES_ENDPOINT}"
  sync_tsb_images ${GITLAB_DOCKER_IMAGES_ENDPOINT} ;
  print_info "Finished to sync tsb images to repo ${GITLAB_DOCKER_IMAGES_ENDPOINT}"
  exit 0
fi

if [[ ${ACTION} = "config-repos" ]]; then

  mkdir -p ${GITLAB_REPOS_TEMPDIR}

  GITLAB_HTTP_URL=$(get_gitlab_http_url ${GITLAB_CONTAINER_NAME})
  GITLAB_HTTP_URL_CREDS=$(get_gitlab_http_url_with_credentials ${GITLAB_CONTAINER_NAME})

  repo_count=`jq '. | length' ${GITLAB_REPOS_CONFIG}`

  for ((i=0; i<$repo_count; i++)); do
      description=`jq -r '.['$i'].description' ${GITLAB_REPOS_CONFIG}`
      directory=`jq -r '.['$i'].directory' ${GITLAB_REPOS_CONFIG}`
      group=`jq -r '.['$i'].group' ${GITLAB_REPOS_CONFIG}`
      project=`jq -r '.['$i'].project' ${GITLAB_REPOS_CONFIG}`
      
      print_info "Going configure gitlab project '${project}' in group '${group}'"
      gitlab_create_group ${GITLAB_HTTP_URL} ${GITLAB_ROOT_TOKEN} ${group} ;
      gitlab_create_project_in_group ${GITLAB_HTTP_URL} ${GITLAB_ROOT_TOKEN} ${group} ${project} "${description}" ;
      
      print_info "Going to clone gitlab project '${project}' in group '${group}' to ${GITLAB_REPOS_TEMPDIR}/${project}"
      cd ${GITLAB_REPOS_TEMPDIR}
      rm -rf ./${project}
      git clone ${GITLAB_HTTP_URL_CREDS}/${group}/${project}.git

      print_info "Going add, commit and push new code to project '${project}' in group '${group}'"
      cd ${GITLAB_REPOS_TEMPDIR}/${project}

      cp -a ${GITLAB_REPOS_DIR}/${directory}/. ${GITLAB_REPOS_TEMPDIR}/${project}
      git add -A
      git commit -m "initial commit"
      git push -u origin main
  done
  
  exit 0
fi

echo "Please specify one of the following action:"
echo "  - sync-images"
echo "  - config-repos"
exit 1