#!/usr/bin/env bash
#
# Helper script to start a local gitlab runner 
#
ROOT_DIR="$( cd -- "$(dirname "${0}")" >/dev/null 2>&1 ; pwd -P )"
source ${ROOT_DIR}/helpers.sh
source ${ROOT_DIR}/gitlab-api.sh

ACTION=${1}

GITLAB_CONTAINER_NAME="gitlab-ee"

GITLAB_RUNNER_BINARY=/usr/local/bin/gitlab-runner
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


if [[ ${ACTION} = "install" ]]; then

  if [[ -f "${GITLAB_RUNNER_BINARY}" ]]; then
    echo "File ${GITLAB_RUNNER_BINARY} already exists" ;
  else
    # Download runner
    sudo curl -L --output ${GITLAB_RUNNER_BINARY} https://gitlab-runner-downloads.s3.amazonaws.com/latest/binaries/gitlab-runner-linux-amd64 ;
    sudo chmod +x ${GITLAB_RUNNER_BINARY} ;
  fi

  exit 0
fi

if [[ ${ACTION} = "start" ]]; then

  GITLAB_HTTP_URL=$(get_gitlab_http_url ${GITLAB_CONTAINER_NAME})
  SHARED_RUNNER_TOKEN=$(gitlab_get_shared_runner_token ${GITLAB_CONTAINER_NAME})

  # Install, run as a service and register runner
  sudo useradd --comment 'GitLab Runner' --create-home ${GITLAB_RUNNER_USER} --shell /bin/bash
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
echo "  - install"
echo "  - start"
echo "  - stop"
echo "  - remove"
exit 1