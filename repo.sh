#!/usr/bin/env bash
#
# Helper script to create gitlab groups, projects and repo code
#
ROOT_DIR="$( cd -- "$(dirname "${0}")" >/dev/null 2>&1 ; pwd -P )"
source ${ROOT_DIR}/helpers.sh
source ${ROOT_DIR}/gitlab-api.sh

ACTION=${1}

if [[ ! -f "${ROOT_DIR}/env.json" ]] ; then echo "env.json not found, exiting..." ; exit 1 ; fi
GITLAB_ROOT_PASSWORD=$(cat ${ROOT_DIR}/env.json | jq -r ".gitlab.root.password") ;
GITLAB_ROOT_TOKEN=$(cat ${ROOT_DIR}/env.json | jq -r ".gitlab.root.token") ;

GITLAB_CONTAINER_NAME="gitlab-ee"
GITLAB_DOCKER_PORT=5050
GITLAB_REPOSITORIES_DIR=${ROOT_DIR}/repositories
GITLAB_GROUPS_CONFIG=${GITLAB_REPOSITORIES_DIR}/groups.json
GITLAB_PROJECTS_CONFIG=${GITLAB_REPOSITORIES_DIR}/projects.json
GITLAB_REPOSITORIES_TEMPDIR=/tmp/repositories


# Get local gitlab http endpoint
#   args:
#     (1) gitlab container name
function get_gitlab_http_url {
  if ! IP=$(docker inspect --format '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' ${1}  2>/dev/null ); then
    print_error "Local docker repo not running" ; 
    exit 1 ;
  fi
  echo "http://${IP}:80" ;
}

# Get local gitlab http endpoint with credentials
#   args:
#     (1) gitlab container name
function get_gitlab_http_url_with_credentials {
  if ! IP=$(docker inspect --format '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' ${1}  2>/dev/null ); then
    print_error "Local docker repo not running" ; 
    exit 1 ;
  fi
  echo "http://root:${GITLAB_ROOT_PASSWORD}@${IP}:80" ;
}


if [[ ${ACTION} = "config-repos" ]]; then

  mkdir -p ${GITLAB_REPOSITORIES_TEMPDIR}

  GITLAB_HTTP_URL=$(get_gitlab_http_url ${GITLAB_CONTAINER_NAME})
  GITLAB_HTTP_URL_CREDS=$(get_gitlab_http_url_with_credentials ${GITLAB_CONTAINER_NAME})

  # Group creation using Gitlab REST APIs
  group_count=$(jq '. | length' ${GITLAB_GROUPS_CONFIG})
  for ((group_index=0; group_index<${group_count}; group_index++)); do
    group_description=$(jq -r '.['${group_index}'].description' ${GITLAB_GROUPS_CONFIG})
    group_name=$(jq -r '.['${group_index}'].name' ${GITLAB_GROUPS_CONFIG})
    group_path=$(jq -r '.['${group_index}'].path' ${GITLAB_GROUPS_CONFIG})

    print_info "Going configure gitlab group '${group_name}' with path '${group_path}'"
    gitlab_create_group ${GITLAB_HTTP_URL} ${GITLAB_ROOT_TOKEN} ${group_name} ${group_path} "${group_description}"
  done

  # Project creation using Gitlab REST APIs
  project_count=$(jq '. | length' ${GITLAB_PROJECTS_CONFIG})
  for ((project_index=0; project_index<${project_count}; project_index++)); do
    project_description=$(jq -r '.['${project_index}'].description' ${GITLAB_PROJECTS_CONFIG})
    project_group_path=$(jq -r '.['${project_index}'].group_path' ${GITLAB_PROJECTS_CONFIG})
    project_name=$(jq -r '.['${project_index}'].name' ${GITLAB_PROJECTS_CONFIG})

    print_info "Going configure gitlab project '${project_name}' in group with path '${project_group_path}'"
    gitlab_create_project_in_group_path ${GITLAB_HTTP_URL} ${GITLAB_ROOT_TOKEN} ${project_group_path} ${project_name} "${project_description}" ;
  done

  # Repo synchronization using git clone, add, commit and push
  repo_count=$(jq '. | length' ${GITLAB_PROJECTS_CONFIG})
  for ((repo_index=0; repo_index<${repo_count}; repo_index++)); do
    repo_group_path=$(jq -r '.['${repo_index}'].group_path' ${GITLAB_PROJECTS_CONFIG})
    repo_name=$(jq -r '.['${repo_index}'].name' ${GITLAB_PROJECTS_CONFIG})

    print_info "Going to git clone repo '${repo_name}' in group with path '${repo_group_path}' to ${GITLAB_REPOSITORIES_TEMPDIR}/${repo_group_path}/${repo_name}"
    mkdir -p ${GITLAB_REPOSITORIES_TEMPDIR}/${repo_group_path}
    cd ${GITLAB_REPOSITORIES_TEMPDIR}/${repo_group_path}
    rm -rf ${GITLAB_REPOSITORIES_TEMPDIR}/${repo_group_path}/${repo_name}
    git clone ${GITLAB_HTTP_URL_CREDS}/${repo_group_path}/${repo_name}.git

    print_info "Going add, commit and push new code to repo '${repo_name}' in group with path '${repo_group_path}'"
    cd ${GITLAB_REPOSITORIES_TEMPDIR}/${repo_group_path}/${repo_name}
    rm -rf ${GITLAB_REPOSITORIES_TEMPDIR}/${repo_group_path}/${repo_name}/*
    cp -a ${GITLAB_REPOSITORIES_DIR}/${repo_group_path}/${repo_name}/. ${GITLAB_REPOSITORIES_TEMPDIR}/${repo_group_path}/${repo_name}
    git add -A
    git commit -m "This is an automated commit"
    git push -u origin main
  done

  exit 0
fi

echo "Please specify one of the following action:"
echo "  - config-repos"
exit 1