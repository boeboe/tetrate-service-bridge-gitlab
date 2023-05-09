#!/usr/bin/env bash
#
# Helper script to create local gitlab instance with tsb images 
#
ROOT_DIR="$( cd -- "$(dirname "${0}")" >/dev/null 2>&1 ; pwd -P )"
source ${ROOT_DIR}/helpers.sh
source ${ROOT_DIR}/gitlab-api.sh

ACTION=${1}

GITLAB_HOME=/tmp/gitlab
GITLAB_NETWORK="gitlab" 
GITLAB_CONTAINER_NAME="gitlab-ee"
GITLAB_DOCKER_PORT=5050

GITLAB_ROOT_EMAIL="root@local"
GITLAB_ROOT_PASSWORD="Tetrate123."
GITLAB_ROOT_TOKEN="01234567890123456789"
GITLAB_OMNIBUS_CONFIG="
    external_url 'http://127.0.0.1'
    registry_external_url 'http://127.0.0.1:${GITLAB_DOCKER_PORT}'
  "

# Start local gitlab instance
#   args:
#     (1) gitlab docker network
#     (2) gitlab name
function start_local_gitlab {
  if ! docker network inspect ${1} &>/dev/null ; then
    docker network create ${1} --subnet=192.168.47.0/24 ;
  fi

  if docker ps --filter "status=running" | grep ${2} &>/dev/null ; then
    echo "Do nothing, local repo ${2} in docker network ${1} is already running"
  elif docker ps --filter "status=exited" | grep ${2} &>/dev/null ; then
    print_info "Going to start local repo ${2} in docker network ${1} again"
    docker start ${2} ;
  else
    print_info "Going to start local repo ${2} in docker network ${1} for the first time"
    mkdir -p ${GITLAB_HOME}
    mkdir -p ${GITLAB_HOME}/data/git-data/repositories
    docker run --detach \
      --env GITLAB_ROOT_EMAIL="${GITLAB_ROOT_EMAIL}" \
      --env GITLAB_ROOT_PASSWORD="${GITLAB_ROOT_PASSWORD}" \
      --env GITLAB_OMNIBUS_CONFIG="${GITLAB_OMNIBUS_CONFIG}" \
      --hostname "${GITLAB_CONTAINER_NAME}" \
      --publish 443:443 --publish 80:80 --publish 2222:22 --publish ${GITLAB_DOCKER_PORT}:${GITLAB_DOCKER_PORT} \
      --name "${GITLAB_CONTAINER_NAME}" \
      --net ${1} \
      --restart always \
      --volume ${GITLAB_HOME}/config:/etc/gitlab \
      --volume ${GITLAB_HOME}/logs:/var/log/gitlab \
      --volume ${GITLAB_HOME}/data:/var/opt/gitlab \
      --shm-size 512m \
      gitlab/gitlab-ee:latest
  fi
}

# Stop local gitlab instance
#   args:
#     (1) gitlab name
function stop_local_gitlab {
  if docker inspect ${1} &>/dev/null ; then
    docker stop ${1} &>/dev/null ;
    print_info "Local docker repo ${1} stopped"
  fi
}

# Remove local gitlab instance
#   args:
#     (1) gitlab docker network
#     (2) gitlab name
function remove_local_gitlab {
  if docker inspect ${2} &>/dev/null ; then
    docker stop ${2} &>/dev/null ;
    docker rm ${2} &>/dev/null ;
    print_info "Local docker repo stopped and removed"
  fi
  if docker network inspect ${1} &>/dev/null ; then
    docker network rm ${1} &>/dev/null ;
    print_info "Local docker repo network removed"
  fi
  sudo rm -rf ${GITLAB_HOME}
}

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

# Wait for gitlab UI to become available
#   args:
#     (1) gitlab http url
function wait_gitlab_ui_ready {
  echo "Waiting for gitlab to be ready..."
  while ! curl ${1} -k 2>/dev/null | grep "You are being" &>/dev/null;
  do
    sleep 1 ;
    echo -n "." ;
  done
  echo "DONE"
  echo "The gitlab GUI is available at ${1}"
}

# Add local docker repo as docker insecure registry
#   args:
#     (1) repo endpoint
function add_insecure_registry {
  DOCKER_JSON="{\"insecure-registries\" : [\"http://${1}\"]}"   
  # In case no local docker configuration file yet, create new from scratch
  if [[ ! -f /etc/docker/daemon.json ]]; then
    sudo sh -c "echo '${DOCKER_JSON}' > /etc/docker/daemon.json"
    sudo systemctl restart docker 
    print_info "Insecure registry configured"
  elif cat /etc/docker/daemon.json | grep ${1} &>/dev/null; then
    print_info "Insecure registry already configured"
  else
    print_warning "File /etc/docker/daemon.json already exists"
    print_warning "Please merge ${DOCKER_JSON} manually and restart docker with 'sudo systemctl restart docker'"
    exit 1
  fi
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


if [[ ${ACTION} = "start" ]]; then
  
  start_local_gitlab ${GITLAB_NETWORK} ${GITLAB_CONTAINER_NAME} ;

  GITLAB_HTTP_URL=$(get_gitlab_http_url ${GITLAB_CONTAINER_NAME})
  wait_gitlab_ui_ready ${GITLAB_HTTP_URL} ;

  GITLAB_DOCKER_ENDPOINT=$(get_gitlab_docker_endpoint ${GITLAB_CONTAINER_NAME})
  add_insecure_registry ${GITLAB_DOCKER_ENDPOINT} ;

  exit 0
fi

if [[ ${ACTION} = "config" ]]; then
  
  gitlab_set_user_token ${GITLAB_CONTAINER_NAME} "root" ${GITLAB_ROOT_TOKEN} "Automation Token" ;
  GITLAB_HTTP_URL=$(get_gitlab_http_url ${GITLAB_CONTAINER_NAME})

  gitlab_create_group ${GITLAB_HTTP_URL} ${GITLAB_ROOT_TOKEN} "tsb" ;
  gitlab_create_project_in_group ${GITLAB_HTTP_URL} ${GITLAB_ROOT_TOKEN} "tsb" "images" "TSB container images" ;
  
  exit 0
fi

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

if [[ ${ACTION} = "stop" ]]; then
  stop_local_gitlab ${GITLAB_CONTAINER_NAME} ;
  exit 0
fi

if [[ ${ACTION} = "remove" ]]; then
  remove_local_gitlab ${GITLAB_NETWORK} ${GITLAB_CONTAINER_NAME} ;
  exit 0
fi

echo "Please specify one of the following action:"
echo "  - start"
echo "  - config"
echo "  - sync-images"
echo "  - stop"
echo "  - remove"
exit 1