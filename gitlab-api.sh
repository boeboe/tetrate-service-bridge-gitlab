#!/usr/bin/env bash
#
# Helper functions for gitlab API actions
#
ROOT_DIR="$( cd -- "$(dirname "${0}")" >/dev/null 2>&1 ; pwd -P )"
source ${ROOT_DIR}/helpers.sh

# Set gitlab user token
#   args:
#     (1) gitlab container name
#     (2) gitlab api url
#     (3) gitlab root api token
function gitlab_set_root_api_token {
  if [[ $(curl --silent --request GET --header "PRIVATE-TOKEN: ${3}" --header 'Content-Type: application/json' --url "${2}/api/v4/metadata" -w "%{http_code}" -o /dev/null) == "200" ]] ; then
    echo "Gitlab root api token already configured and working"
  else
    echo "Going to configure gitlab root api token"
    docker exec ${1} gitlab-rails runner \
      "token = User.find_by_username('root').personal_access_tokens.create(scopes: [:api, :sudo], name: 'Root API Token'); 
       token.set_token('${3}');
       token.save"
  fi
}

# Set gitlab shared runner token
#   args:
#     (1) gitlab container name
function gitlab_get_shared_runner_token {
  docker exec -it ${1} gitlab-rails runner "puts Gitlab::CurrentSettings.current_application_settings.runners_registration_token"
}

# Get gitlab shared runner id
#   args:
#     (1) gitlab api url
#     (2) gitlab api token
#     (2) gitlab runner description
function gitlab_get_shared_runner_id {
  curl --silent --request GET --header "PRIVATE-TOKEN: ${2}" \
    --header 'Content-Type: application/json' \
    --url "${1}/api/v4/runners/all?type=instance_type" | jq ".[] | select(.description==\"${3}\")" | jq -r '.id'
}

# Create gitlab group
#   args:
#     (1) gitlab api url
#     (2) gitlab api token
#     (3) gitlab group name
function gitlab_create_group {
  group_id=$(gitlab_get_group_id ${1} ${2} ${3})
  if [[ ${group_id} == "" ]] ; then
    response=`curl --url "${1}/api/v4/groups/" --silent --request POST --header "PRIVATE-TOKEN: ${2}" \
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
#     (1) gitlab api url
#     (2) gitlab api token
#     (3) gitlab group name
function gitlab_get_group_id {
  curl --silent --request GET --header "PRIVATE-TOKEN: ${2}" \
    --header 'Content-Type: application/json' \
    --url "${1}/api/v4/groups/" | jq ".[] | select(.name==\"${3}\")" | jq -r '.id'
}

# Create gitlab project
#   args:
#     (1) gitlab api url
#     (2) gitlab api token
#     (3) gitlab group name
#     (4) gitlab project name
#     (5) gitlab project description
function gitlab_create_project_in_group {
  group_id=$(gitlab_get_group_id ${1} ${2} ${3})
  if [[ ${group_id} == "" ]] ; then
    gitlab_create_group ${1} ${2} ${3} ;
  fi

  project_id=$(gitlab_get_project_id_in_group ${1} ${2} ${3} ${4})
  if [[ ${project_id} == "" ]]; then
    response=`curl --url "${1}/api/v4/projects/" --silent --request POST --header "PRIVATE-TOKEN: ${2}" \
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
#     (1) gitlab api url
#     (2) gitlab api token
#     (3) gitlab group name
#     (4) gitlab project name
function gitlab_get_project_id_in_group {
  curl --url "${1}/api/v4/projects" --silent --request GET --header "PRIVATE-TOKEN: ${2}" \
    | jq ".[] | select(.namespace.name=\"${3}\") | select(.name==\"${4}\")" | jq -r '.id'
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
