#!/usr/bin/env bash
#
# Helper script to configure tsb
#
ROOT_DIR="$( cd -- "$(dirname "${0}")" >/dev/null 2>&1 ; pwd -P )"

OUTPUT_DIR=${ROOT_DIR}/output/tsb

ACTION=${1}
COUNT="${COUNT:-100}"
TARGET="${TARGET:-all}"

ALL_TARGETS="
cash1
cash2
comm1
comm2
invest1
invest2
private1
private2
retail1
retail2
wealth1
wealth2
"

# -e exits on error
# -u errors on undefined variables
# -x prints commands before execution
# -o (for option) pipefail exits on command pipe failures
set -euo pipefail

# Print info messages
#   args:
#     (1) message
function print_info {
  purpleb="\033[1;35m"
  end="\033[0m"
  echo -e "${purpleb}${1}${end}"
}

# Print command
#   args:
#     (1) command
function print_command {
  yellowb="\033[1;33m"
  end="\033[0m"
  echo -e "${yellowb}${1}${end}"
}

# Send curl test traffic to application
#   args:
#     (1) application name
#     (2) count
function send_curl_traffic {
  cert_base_dir=${ROOT_DIR}/output/ingress-certs/client/${1}
  target_t1_gw_ip=$(kubectl --context mgmt get svc -n tier1-gw-${1} tier1-gw-${1} --output jsonpath='{.status.loadBalancer.ingress[0].ip}') ;
  print_command "curl -v -H \"X-B3-Sampled: 1\" --resolve \"${1}.demo.tetrate.io:443:${target_t1_gw_ip}\" --cacert ${cert_base_dir}/root-cert.pem --cert ${cert_base_dir}/client1.${1}.demo.tetrate.io-cert.pem --key ${cert_base_dir}/client1.${1}.demo.tetrate.io-key.pem \"https://${1}.demo.tetrate.io/proxy/mid-${1}.mid-${1}/proxy/back-${1}.back-${1}\""

  for ((i=0; i<${2}; i++)); do
    curl -v -H "X-B3-Sampled: 1" --resolve "${1}.demo.tetrate.io:443:${target_t1_gw_ip}" --cacert ${cert_base_dir}/root-cert.pem --cert ${cert_base_dir}/client1.${1}.demo.tetrate.io-cert.pem --key ${cert_base_dir}/client1.${1}.demo.tetrate.io-key.pem "https://${1}.demo.tetrate.io/proxy/mid-${1}.mid-${1}/proxy/back-${1}.back-${1}" ;
    sleep 0.1 ;
  done
}



if [[ ${ACTION} = "curl" ]]; then

  if [[ "${TARGET}" == "all" ]] ; then
    print_info "Going to send test traffic (count: ${COUNT}) to all applications using curl" ;

    for targ in ${ALL_TARGETS} ; do
      print_info "Going to send test traffic (count: ${COUNT}) to application ${targ} using curl" ;
      send_curl_traffic ${targ} ${COUNT} &
      declare pid_${targ}=$!
    done
    for targ in ${ALL_TARGETS} ; do
      wait ${pid_${targ}}
    done
  else
    print_info "Going to send test traffic (count: ${COUNT}) to application ${TARGET} using curl" ;
    send_curl_traffic ${TARGET} ${COUNT}
  fi

  exit 0
fi


echo "Please specify one of the following action:"
echo "  - curl"
exit 1