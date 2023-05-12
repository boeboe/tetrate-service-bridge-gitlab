#!/usr/bin/env bash
#
# Helper script to create gitlab groups, projects and repo code
#
ROOT_DIR="$( cd -- "$(dirname "${0}")" >/dev/null 2>&1 ; pwd -P )"

ACTION=${1}

if [[ ${ACTION} = "build" ]]; then
  echo "Running build stage"
  echo "ROOT_DIR == ${ROOT_DIR}"
  echo "PATH == ${PATH}"
  echo "CI_REGISTRY_USER == ${CI_REGISTRY_USER}"
  echo "CI_REGISTRY_PASSWORD == ${CI_REGISTRY_PASSWORD}"
  echo "CI_REGISTRY == ${CI_REGISTRY}"
  echo ">> env" ; env
  echo ">> pwd" ; pwd
  echo ">> ls -la" ; ls -la
  echo ">> whoami" ; whoami
  echo ">> sudo whoami" ; sudo whoami
  echo ">> which minikube" ; which minikube
  echo ">> minikube start" ; minikube start
  echo ">> docker ps" ; docker ps
  exit 0
fi

if [[ ${ACTION} = "test" ]]; then
  echo "Running test stage"
  echo "TEST_VAR == ${TEST_VAR}"
  echo ">> minikube version" ; minikube version
  echo ">> minikube status" ; minikube status
  echo ">> minikube profile list" ; minikube profile list
  echo ">> minikube stop" ; minikube stop
  docker ps
  exit 0
fi

if [[ ${ACTION} = "pack" ]]; then
  echo "Running pack stage"
  echo ${ROOT_DIR}
  pwd
  ls -la
  whoami
  sudo whoami
  exit 0
fi


echo "Please specify one of the following action:"
echo "  - build"
echo "  - test"
echo "  - pack"
exit 1