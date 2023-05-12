#!/usr/bin/env bash
#
# Helper script to install tsb management plane
#
ROOT_DIR="$( cd -- "$(dirname "${0}")" >/dev/null 2>&1 ; pwd -P )"

TSB_CLUSTER_CONFIG=${ROOT_DIR}/tsb-clusters.json

ACTION=${1}

# Print info messages
#   args:
#     (1) message
function print_info {
  purpleb="\033[1;35m"
  end="\033[0m"
  echo -e "${purpleb}${1}${end}"
}


if [[ ${ACTION} = "install" ]]; then
  exit 0
fi

echo "Please specify one of the following action:"
echo "  - install"
exit 1