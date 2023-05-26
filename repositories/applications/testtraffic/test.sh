#!/usr/bin/env bash
#
# Helper script to configure tsb
#
ROOT_DIR="$( cd -- "$(dirname "${0}")" >/dev/null 2>&1 ; pwd -P )"

OUTPUT_DIR=${ROOT_DIR}/output/tsb
CERTS_BASE_DIR=${ROOT_DIR}/output/ingress-certs/client/${TARGET}

ACTION=${1}
COUNT="${COUNT:-100}"

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

if [[ ${ACTION} = "curl" ]]; then

   # Going to send test traffic using curl
  print_info "Going to send test traffic (count: ${COUNT}) to application ${TARGET} using curl" ;
  target_t1_gw_ip=$(kubectl --context mgmt get svc -n tier1-gw-${TARGET} tier1-gw-${TARGET} --output jsonpath='{.status.loadBalancer.ingress[0].ip}') ;
  print_command "curl -v -H \"X-B3-Sampled: 1\" --resolve \"${TARGET}.demo.tetrate.io:443:${target_t1_gw_ip}\" --cacert ${CERTS_BASE_DIR}/root-cert.pem --cert ${CERTS_BASE_DIR}/client1.${TARGET}.demo.tetrate.io-cert.pem --key ${CERTS_BASE_DIR}/client1.${TARGET}.demo.tetrate.io-key.pem \"https://${TARGET}.demo.tetrate.io/proxy/mid-${TARGET}.mid-${TARGET}/proxy/back-${TARGET}.back-${TARGET}\""

  for ((i=0; i<${COUNT}; i++)); do
    curl -v -H "X-B3-Sampled: 1" --resolve "${TARGET}.demo.tetrate.io:443:${target_t1_gw_ip}" --cacert ${CERTS_BASE_DIR}/root-cert.pem --cert ${CERTS_BASE_DIR}/client1.${TARGET}.demo.tetrate.io-cert.pem --key ${CERTS_BASE_DIR}/client1.${TARGET}.demo.tetrate.io-key.pem "https://${TARGET}.demo.tetrate.io/proxy/mid-${TARGET}.mid-${TARGET}/proxy/back-${TARGET}.back-${TARGET}" ;
    sleep 1 ;
  done

  exit 0
fi


echo "Please specify one of the following action:"
echo "  - curl"
exit 1