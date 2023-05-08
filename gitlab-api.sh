#!/usr/bin/env bash
#
# Helper functions for gitlab API actions
#
ROOT_DIR="$( cd -- "$(dirname "${0}")" >/dev/null 2>&1 ; pwd -P )"
source ${ROOT_DIR}/helpers.sh

# Set gitlab user token
#   args:
#     (1) gitlab container name
#     (2) gitlab user
#     (3) gitlab token
#     (4) gitlab token name
function gitlab_set_user_token {
  if [[ $(docker exec gitlab-ee gitlab-rails runner "puts User.find_by_username('${2}').personal_access_tokens.any? { |token| token.name == '${4}' }") == "false" ]] ;
  then
    docker exec ${1} gitlab-rails runner \
      "token = User.find_by_username('${2}').personal_access_tokens.create(scopes: [:api, :sudo], name: '${4}'); 
       token.set_token('${3}');
       token.save"
  else
    echo "User '${2}' already has a token named '${4}'"
  fi
}

# Create gitlab group
#   args:
#     (1) gitlab url
#     (2) gitlab token
#     (3) gitlab group name
function gitlab_create_group {
  group_id=$(gitlab_get_group_id ${1} ${2} ${3})
  if [[ ${group_id} == "" ]] ; then
    response=`curl "${1}/api/v4/groups/" --silent --request POST --header "PRIVATE-TOKEN: ${2}" \
      --header "Content-Type: application/json" \
      --data @- <<BODY
{
  "path": "${3}",
  "name": "${3}",
  "visibility": "public"
}
BODY`

    echo ${response} | jq
  else
    echo "Gitlab group '${3}' (id: ${group_id}) already exists "
  fi
}

# Get gitlab group id
#   args:
#     (1) gitlab url
#     (2) gitlab token
#     (3) gitlab group name
function gitlab_get_group_id {
  curl --silent --request GET --header "PRIVATE-TOKEN: ${2}" \
    --header 'Content-Type: application/json' \
    --url "${1}/api/v4/groups/" | jq ".[] | select(.name==\"${3}\")" | jq -r '.id'
}

# Create gitlab project
#   args:
#     (1) gitlab url
#     (2) gitlab token
#     (3) gitlab group name
#     (4) gitlab project name
#     (5) gitlab project description
function gitlab_create_project_in_group {
  group_id=$(gitlab_get_group_id ${1} ${2} ${3})
  if [[ ${group_id} == "" ]] ; then
    gitlab_create_group ${1} ${2} ${3} ;
  fi

  group_id=$(gitlab_get_group_id ${1} ${2} ${3})
  project_id=$(gitlab_get_project_id_in_group ${1} ${2} ${group_id} ${4})
  if [[ ${project_id} == "" ]]; then
    response=`curl "${1}/api/v4/projects/" --silent --request POST --header "PRIVATE-TOKEN: ${2}" \
      --header "Content-Type: application/json" \
      --data @- <<BODY
{
  "description": "${5}",
  "name": "${4}",
  "namespace_id": "${group_id}",
  "path": "${4}",
  "visibility": "public"
}
BODY`

    echo ${response} | jq
  else
    echo "Gitlab project '${4}' (id: ${project_id}) already exists in group '${3}' (id: ${group_id})"
  fi
}

# Get gitlab project id in group
#   args:
#     (1) gitlab url
#     (2) gitlab token
#     (3) gitlab group name
#     (4) gitlab project name
function gitlab_get_project_id_in_group {
  if ! curl --fail --silent --request GET --header "PRIVATE-TOKEN: ${2}" --header 'Content-Type: application/json' --url "${1}/api/v4/groups/${3}" &>/dev/null; then
    # Group does not exist
    return
  else
    curl --silent --request GET --header "PRIVATE-TOKEN: ${2}" \
      --header 'Content-Type: application/json' \
      --url "${1}/api/v4/groups/${3}/projects" | jq ".[] | select(.name==\"${4}\")" | jq -r '.id'
  fi
}


# Tests

# gitlab_create_group "http://192.168.47.2:80" "01234567890123456789" "boeboe" ;

# gitlab_get_group_id "http://192.168.47.2:80" "01234567890123456789" "boeboe" ;
# gitlab_get_group_id "http://192.168.47.2:80" "01234567890123456789" "boeboe123" ;

# gitlab_create_project_in_group "http://192.168.47.2:80" "01234567890123456789" "boeboe" "test" "This is a test project" ;

# gitlab_get_project_id_in_group "http://192.168.47.2:80" "01234567890123456789" "boeboe" "test" ;
# gitlab_get_project_id_in_group "http://192.168.47.2:80" "01234567890123456789" "boeboe123" "test" ;
# gitlab_get_project_id_in_group "http://192.168.47.2:80" "01234567890123456789" "boeboe" "test123" ;

# gitlab_create_project_in_group "http://192.168.47.2:80" "01234567890123456789" "boeboe" "testbis" "This is a test bis project" ;
# gitlab_get_project_id_in_group "http://192.168.47.2:80" "01234567890123456789" "boeboe" "testbis" ;
# gitlab_create_project_in_group "http://192.168.47.2:80" "01234567890123456789" "boeboe" "testtris" "This is a test tris project" ;
# gitlab_get_project_id_in_group "http://192.168.47.2:80" "01234567890123456789" "boeboe" "testtris" ;
