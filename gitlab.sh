#!/usr/bin/env bash
#
# Helper script to create local gitlab instance with tsb images 
#
ROOT_DIR="$( cd -- "$(dirname "${0}")" >/dev/null 2>&1 ; pwd -P )"
source ${ROOT_DIR}/helpers.sh

ACTION=${1}

GITLAB_HOME=/tmp/gitlab
GITLAB_NETWORK="gitlab" 
GITLAB_NAME="gitlab-ee"

GITLAB_ROOT_EMAIL="root@local"
GITLAB_ROOT_PASSWORD="Tetrate123."
GITLAB_OMNIBUS_CONFIG="
    external_url 'http://127.0.0.1'
    registry_external_url 'http://127.0.0.1:5050'
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
    # On MacOS we need to manually fix a permission issue!
    if [[ $(uname -s) == Darwin* ]] ; then sudo chmod -R -v 2770 ${GITLAB_HOME}/data/git-data/repositories ; fi
    docker run --detach \
      --env GITLAB_ROOT_EMAIL="${GITLAB_ROOT_EMAIL}" \
      --env GITLAB_ROOT_PASSWORD="${GITLAB_ROOT_PASSWORD}" \
      --env GITLAB_OMNIBUS_CONFIG="${GITLAB_OMNIBUS_CONFIG}" \
      --hostname "${GITLAB_NAME}" \
      --publish 443:443 --publish 80:80 --publish 2222:22 --publish 5000:5050 \
      --name "${GITLAB_NAME}" \
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
  rm -rf ${GITLAB_HOME}
}

# Get local gitlab http endpoint
#   args:
#     (1) gitlab name
function get_gitlab_http_endpoint {
  if ! IP=$(docker inspect --format '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' ${1}  2>/dev/null ); then
    print_error "Local docker repo not running" ; 
    exit 1 ;
  fi
  echo "${IP}:80" ;
}

# Get local gitlab docker endpoint
#   args:
#     (1) gitlab name
function get_gitlab_docker_endpoint {
  if ! IP=$(docker inspect --format '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' ${1}  2>/dev/null ); then
    print_error "Local docker repo not running" ; 
    exit 1 ;
  fi
  echo "${IP}:5000" ;
}

# Wait for gitlab UI to become available
#   args:
#     (1) gitlab http endpoint
function wait_gitlab_ui_ready {
  echo "Waiting for gitlab to be ready (initially ca 12 minutes)..."
  while ! curl http://${1} -k 2>/dev/null | grep "You are being" &>/dev/null;
  do
    sleep 1 ;
    echo -n "." ;
  done
  echo "DONE"
  echo "The gitlab GUI is available at http://${1}"
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


if [[ ${ACTION} = "start" ]]; then
  
  start_local_gitlab ${GITLAB_NETWORK} ${GITLAB_NAME} ;

  GITLAB_HTTP_ENDPOINT=$(get_gitlab_http_endpoint ${GITLAB_NAME})
  echo ">>>>>> ${GITLAB_HTTP_ENDPOINT}"
  wait_gitlab_ui_ready ${GITLAB_HTTP_ENDPOINT}

  GITLAB_DOCKER_ENDPOINT==$(get_gitlab_docker_endpoint ${GITLAB_NAME})
  add_insecure_registry ${GITLAB_DOCKER_ENDPOINT} ;

  exit 0
fi

if [[ ${ACTION} = "stop" ]]; then
  stop_local_gitlab ${GITLAB_NAME} ;
  exit 0
fi

if [[ ${ACTION} = "remove" ]]; then
  remove_local_gitlab ${GITLAB_NETWORK} ${GITLAB_NAME} ;
  exit 0
fi

echo "Please specify one of the following action:"
echo "  - start"
echo "  - stop"
echo "  - remove"
exit 1