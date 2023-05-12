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
GITLAB_REPOS_DIR=${ROOT_DIR}/repos
GITLAB_REPOS_CONFIG=${GITLAB_REPOS_DIR}/repos.json
GITLAB_REPOS_TEMPDIR=/tmp/repos


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
echo "  - config-repos"
exit 1