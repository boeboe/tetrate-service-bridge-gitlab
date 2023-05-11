#!/usr/bin/env bash
#
# Helper script to start a local gitlab runner 
#
ROOT_DIR="$( cd -- "$(dirname "${0}")" >/dev/null 2>&1 ; pwd -P )"
source ${ROOT_DIR}/helpers.sh
source ${ROOT_DIR}/gitlab-api.sh

ACTION=${1}

GITLAB_CONTAINER_NAME="gitlab-ee"

GITLAB_RUNNER_WORKDIR=/tmp/gitlab-runner
GITLAB_RUNNER_NAME=local-shell-runner
GITLAB_RUNNER_USER=gitlab-runner  

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

if [[ ${ACTION} = "start" ]]; then

  GITLAB_HTTP_URL=$(get_gitlab_http_url ${GITLAB_CONTAINER_NAME})
  SHARED_RUNNER_TOKEN=$(gitlab_get_shared_runner_token ${GITLAB_CONTAINER_NAME})

  # Install, run as a service and register runner
  mkdir -p ${GITLAB_RUNNER_WORKDIR}
  sudo gitlab-runner install --working-directory=${GITLAB_RUNNER_WORKDIR} --user=${GITLAB_RUNNER_USER}
  sudo gitlab-runner start
  sudo gitlab-runner register \
    --url ${GITLAB_HTTP_URL} \
    --registration-token "${SHARED_RUNNER_TOKEN}" \
    --executor shell \
    --non-interactive \
    --name ${GITLAB_RUNNER_NAME}

  exit 0
fi

if [[ ${ACTION} = "stop" ]]; then
  sudo gitlab-runner stop
  exit 0
fi

if [[ ${ACTION} = "remove" ]]; then

  GITLAB_HTTP_URL=$(get_gitlab_http_url ${GITLAB_CONTAINER_NAME})
  SHARED_RUNNER_TOKEN=$(gitlab_get_shared_runner_token ${GITLAB_CONTAINER_NAME})

  sudo gitlab-runner stop
  sudo gitlab-runner unregister \
    --url ${GITLAB_HTTP_URL} \
    --name ${GITLAB_RUNNER_NAME}
  sudo gitlab-runner uninstall
  rm -rf ${GITLAB_RUNNER_WORKDIR}
  exit 0
fi

echo "Please specify one of the following action:"
echo "  - start"
echo "  - stop"
echo "  - remove"
exit 1