#!/usr/bin/env bash
#
# Helper script to create local gitlab instance with tsb images 
#
ROOT_DIR="$( cd -- "$(dirname "${0}")" >/dev/null 2>&1 ; pwd -P )"
source ${ROOT_DIR}/helpers.sh
source ${ROOT_DIR}/gitlab-api.sh

ACTION=${1}

if [[ ! -f "${ROOT_DIR}/env.json" ]] ; then echo "env.json not found, exiting..." ; exit 1 ; fi
GITLAB_ROOT_EMAIL=$(cat ${ROOT_DIR}/env.json | jq -r ".gitlab.root.email") ;
GITLAB_ROOT_PASSWORD=$(cat ${ROOT_DIR}/env.json | jq -r ".gitlab.root.password") ;
GITLAB_ROOT_TOKEN=$(cat ${ROOT_DIR}/env.json | jq -r ".gitlab.root.token") ;
GITLAB_RUNNER_VERSION=$(cat ${ROOT_DIR}/env.json | jq -r ".gitlab.runner_version") ;
GITLAB_SERVER_VERSION=$(cat ${ROOT_DIR}/env.json | jq -r ".gitlab.server_version") ;

TSB_REPO_URL=$(cat ${ROOT_DIR}/env.json | jq -r ".tsb.tetrate_repo.url") ;
TSB_REPO_USER=$(cat ${ROOT_DIR}/env.json | jq -r ".tsb.tetrate_repo.user") ;
TSB_REPO_PW=$(cat ${ROOT_DIR}/env.json | jq -r ".tsb.tetrate_repo.password") ;

GITLAB_HOME=/tmp/gitlab
GITLAB_RUNNER_WORKDIR=/tmp/gitlab-runner
GITLAB_NETWORK="gitlab" 
GITLAB_CONTAINER_NAME="gitlab-ee"
GITLAB_DOCKER_PORT=5050
GITLAB_OMNIBUS_CONFIG="
    external_url 'http://192.168.47.2'
    registry_external_url 'http://192.168.47.2:${GITLAB_DOCKER_PORT}'
  "

# Start gitlab server
#   args:
#     (1) gitlab docker network
#     (2) gitlab container name
function start_gitlab {
  if ! docker network inspect ${1} &>/dev/null ; then
    docker network create ${1} --subnet="192.168.47.0/24" ;
  fi

  if docker ps --filter "status=running" | grep ${2} &>/dev/null ; then
    echo "Do nothing, container '${2}' in docker network '${1}' is already running"
  elif docker ps --filter "status=exited" | grep ${2} &>/dev/null ; then
    print_info "Going to start local repo ${2} in docker network ${1} again"
    docker start ${2} ;
  else
    print_info "Going to start local repo ${2} in docker network ${1} for the first time"
    mkdir -p ${GITLAB_HOME} ;
    mkdir -p ${GITLAB_HOME}/data/git-data/repositories ;
    docker run --detach \
      --env GITLAB_ROOT_EMAIL="${GITLAB_ROOT_EMAIL}" \
      --env GITLAB_ROOT_PASSWORD="${GITLAB_ROOT_PASSWORD}" \
      --env GITLAB_OMNIBUS_CONFIG="${GITLAB_OMNIBUS_CONFIG}" \
      --hostname "${2}" \
      --publish 443:443 --publish 80:80 --publish 2222:22 --publish ${GITLAB_DOCKER_PORT}:${GITLAB_DOCKER_PORT} \
      --name "${2}" \
      --net ${1} \
      --restart always \
      --volume ${GITLAB_HOME}/config:/etc/gitlab \
      --volume ${GITLAB_HOME}/logs:/var/log/gitlab \
      --volume ${GITLAB_HOME}/data:/var/opt/gitlab \
      --shm-size 512m \
      gitlab/gitlab-ee:${GITLAB_SERVER_VERSION}-ee.0 ;
  fi
}

# Stop gitlab server
#   args:
#     (1) gitlab container name
function stop_gitlab {
  if docker inspect ${1} &>/dev/null ; then
    docker stop ${1} &>/dev/null ;
    print_info "Local docker repo ${1} stopped"
  fi
}

# Remove gitlab server
#   args:
#     (1) gitlab docker network
#     (2) gitlab name
function remove_gitlab {
  if docker inspect ${2} &>/dev/null ; then
    docker stop ${2} &>/dev/null ;
    docker rm ${2} &>/dev/null ;
    echo "Local docker repo stopped and removed"
  fi
  if docker network inspect ${1} &>/dev/null ; then
    docker network rm ${1} &>/dev/null ;
    echo "Local docker repo network removed"
  fi
  sudo rm -rf ${GITLAB_HOME} ;

  for profile in $(sudo -u gitlab-runner minikube profile list -o json | jq -r '.valid[].Name') ; do
    echo "Deleting minikube profile '${profile}'"
    sudo -u gitlab-runner minikube --profile ${profile} delete ;
  done
}

# Start gitlab local runner
#   args:
#     (1) gitlab runner working directory
#     (2) gitlab api url
#     (3) gitlab api token
#     (4) gitlab container name
function start_gitlab_runner {
  mkdir -p ${1} ;
  sudo chown -R gitlab-runner:gitlab-runner ${1} ;

  if [[ -f "/etc/systemd/system/gitlab-runner.service" ]]; then
    echo "Gitlab runner is already installed properly"
  else
    sudo gitlab-runner install --working-directory="${1}" --user="gitlab-runner" ;
  fi

  if $(sudo gitlab-runner status &>/dev/null) ; then
    echo "Gitlab runner is already running"
  else
    echo "Starting gitlab runner"
    sudo gitlab-runner start ;
  fi

  if [[ $(gitlab_get_shared_runner_id ${2} ${3} "local-shell-runner") == "" ]] ; then
    echo "Going to register gitlab runner with description 'local-shell-runner'"
    shared_runner_token=$(gitlab_get_shared_runner_token ${4})
    sudo gitlab-runner register \
      --env "TETRATE_REGISTRY_USER=${TSB_REPO_USER}" \
      --env "TETRATE_REGISTRY_PASSWORD=${TSB_REPO_PW}" \
      --env "TETRATE_REGISTRY=${TSB_REPO_URL}" \
      --executor shell \
      --description "local-shell-runner" \
      --non-interactive \
      --url "${2}" \
      --registration-token "${shared_runner_token}" ;
  else
    echo "Gitlab runner with description 'local-shell-runner' already registered"
  fi
}

# Stop gitlab local runner
function stop_gitlab_runner {
  sudo gitlab-runner stop ;
}

# Remove gitlab local runner
#   args:
#     (1) gitlab server url
function remove_gitlab_runner {
  sudo gitlab-runner unregister --url ${1} --all-runners ;
  sudo gitlab-runner stop ;
  sudo gitlab-runner uninstall ;
  sudo rm -rf ${GITLAB_RUNNER_WORKDIR} ;
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
  
  # Start gitlab server
  start_gitlab ${GITLAB_NETWORK} ${GITLAB_CONTAINER_NAME} ;
  GITLAB_HTTP_URL=$(get_gitlab_http_url ${GITLAB_CONTAINER_NAME})
  wait_gitlab_ui_ready ${GITLAB_HTTP_URL} ;
  GITLAB_DOCKER_ENDPOINT=$(get_gitlab_docker_endpoint ${GITLAB_CONTAINER_NAME})
  add_insecure_registry ${GITLAB_DOCKER_ENDPOINT} ;
  gitlab_set_root_api_token ${GITLAB_CONTAINER_NAME} ${GITLAB_HTTP_URL} ${GITLAB_ROOT_TOKEN}  ;

  # Start gitlab runner
  start_gitlab_runner ${GITLAB_RUNNER_WORKDIR} ${GITLAB_HTTP_URL} ${GITLAB_ROOT_TOKEN} ${GITLAB_CONTAINER_NAME} ;

  exit 0
fi

if [[ ${ACTION} = "stop" ]]; then

  # Stop gitlab runner
  stop_gitlab_runner ;

  # Stop gitlab server
  stop_gitlab ${GITLAB_CONTAINER_NAME} ;
  exit 0
fi

if [[ ${ACTION} = "remove" ]]; then

  # Remove gitlab runner
  GITLAB_HTTP_URL=$(get_gitlab_http_url ${GITLAB_CONTAINER_NAME})
  remove_gitlab_runner ${GITLAB_HTTP_URL} ;

  # Remove gitlab server
  remove_gitlab ${GITLAB_NETWORK} ${GITLAB_CONTAINER_NAME} ;
  exit 0
fi


echo "Please specify one of the following action:"
echo "  - start"
echo "  - stop"
echo "  - remove"
exit 1