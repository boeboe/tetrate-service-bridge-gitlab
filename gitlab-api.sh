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
#     (4) gitlab group path
#     (5) gitlab group description
function gitlab_create_group {
  group_id=$(gitlab_get_group_id ${1} ${2} ${3} ${4})

  if [[ ${group_id} == "" ]] ; then
    if [[ "${3}" == "${4}" ]] ; then
      # Toplevel group
      echo "Going to create toplevel gitlab group '${3}'"
      response=`curl --url "${1}/api/v4/groups" --silent --request POST --header "PRIVATE-TOKEN: ${2}" \
        --header "Content-Type: application/json" \
        --data @- <<BODY
{
  "description": "${5}",
  "path": "${3}",
  "name": "${3}",
  "visibility": "public"
}
BODY`

      echo ${response} | jq
    else
      # Subgroup
      parent_group_path=$(echo ${4} | rev | cut -d"/" -f2-  | rev)
      parent_group_name=$(echo ${parent_group_path} | rev | cut -d"/" -f1  | rev)
      parent_group_id=$(gitlab_get_group_id ${1} ${2} ${parent_group_name} ${parent_group_path})

      if [[ ${parent_group_id} == "" ]] ; then
        echo "Gitlab parent group '${parent_group_name}' with path '${parent_group_path}' does not exist"
      else
        echo "Going to create gitlab subgroup '${3}' in path '${parent_group_path}'"
        response=`curl --url "${1}/api/v4/groups" --silent --request POST --header "PRIVATE-TOKEN: ${2}" \
          --header "Content-Type: application/json" \
          --data @- <<BODY
{
  "description": "${5}",
  "parent_id": "${parent_group_id}",
  "path": "${3}",
  "name": "${3}",
  "visibility": "public"
}
BODY`

        echo ${response} | jq
      fi
    fi
  else
    echo "Gitlab group with name '${3}' and path '${4}' already exists (group_id: ${group_id})"
  fi
}

# Get gitlab group id
#   args:
#     (1) gitlab api url
#     (2) gitlab api token
#     (3) gitlab group name
#     (4) gitlab group path
function gitlab_get_group_id {
  curl --silent --request GET --header "PRIVATE-TOKEN: ${2}" \
    --header 'Content-Type: application/json' \
    --url "${1}/api/v4/groups?per_page=100" | jq ".[] | select(.name==\"${3}\") | select(.full_path==\"${4}\")" | jq -r '.id'
}

# Create gitlab project
#   args:
#     (1) gitlab api url
#     (2) gitlab api token
#     (3) gitlab group path
#     (4) gitlab project name
#     (5) gitlab project description
function gitlab_create_project_in_group_path {
  group_name=$(echo ${3} | rev | cut -d"/" -f1  | rev)
  group_id=$(gitlab_get_group_id ${1} ${2} ${group_name} ${3})

  if [[ ${group_id} == "" ]] ; then
    echo "Gitlab group '${group_name}' with path '${3}' does not exist"
  else
    project_id=$(gitlab_get_project_id_in_group_path ${1} ${2} ${3} ${4})
    if [[ ${project_id} == "" ]]; then
      echo "Going to create gitlab project '${4}' in group with path '${3}'"
      response=`curl --url "${1}/api/v4/projects" --silent --request POST --header "PRIVATE-TOKEN: ${2}" \
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
      echo "Gitlab project '${4}' (project_id: ${project_id}) already exists in group with path '${3}' (group_id: ${group_id})"
    fi
  fi
}

# Get gitlab project id in group
#   args:
#     (1) gitlab api url
#     (2) gitlab api token
#     (3) gitlab group path
#     (4) gitlab project name
function gitlab_get_project_id_in_group_path {
  curl --url "${1}/api/v4/projects?per_page=100" --silent --request GET --header "PRIVATE-TOKEN: ${2}" \
    | jq ".[] | select(.name==\"${4}\") | select(.namespace.full_path==\"${3}\")" | jq -r '.id'
}
