#!/usr/bin/env bash
#
# Helper script to create gitlab groups, projects and repo code
#
ROOT_DIR="$( cd -- "$(dirname "${0}")" >/dev/null 2>&1 ; pwd -P )"

ACTION=${1}

if [[ ${ACTION} = "build" ]]; then
  echo "Running build stage"
  echo ${ROOT_DIR}
  pwd
  ls -la
  whoami
  sudo whoami
  which minikube
  minikube start
  docker ps
  exit 0
fi

if [[ ${ACTION} = "test" ]]; then
  echo "Running test stage"
  echo ${ROOT_DIR}
  pwd
  ls -la
  whoami
  sudo whoami
  echo "TEST_VAR == ${TEST_VAR}"
  minikube version
  minikube status
  minikube profile list
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