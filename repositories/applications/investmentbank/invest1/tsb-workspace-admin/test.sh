#!/usr/bin/env bash
#
# Helper script to configure tsb
#
ROOT_DIR="$( cd -- "$(dirname "${0}")" >/dev/null 2>&1 ; pwd -P )"

OUTPUT_DIR=${ROOT_DIR}/output/tsb
CERTS_BASE_DIR=${ROOT_DIR}/output/ingress-certs/client/invest1

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


if [[ ${ACTION} = "curl" ]]; then

   # Going to send test traffic using curl
  print_info "Going to send test traffic (count: ${COUNT}) using curl" ;
  invest1_t1_gw_ip=$(kubectl --context mgmt get svc -n tier1-gw-invest1 tier1-gw-invest1 --output jsonpath='{.status.loadBalancer.ingress[0].ip}') ;
  echo "curl -v -H \"X-B3-Sampled: 1\" --resolve \"invest1.demo.tetrate.io:443:${invest1_t1_gw_ip}\" --cacert ${CERTS_BASE_DIR}/root-cert.pem --cert ${CERTS_BASE_DIR}/client1.invest1.demo.tetrate.io-cert.pem --key ${CERTS_BASE_DIR}/client1.invest1.demo.tetrate.io-key.pem \"https://invest1.demo.tetrate.io/proxy/mid-invest1.mid-invest1/proxy/back-invest1.back-invest1\""

  for ((i=0; i<${COUNT}; i++)); do
    curl -v -H "X-B3-Sampled: 1" --resolve "invest1.demo.tetrate.io:443:${invest1_t1_gw_ip}" --cacert ${CERTS_BASE_DIR}/root-cert.pem --cert ${CERTS_BASE_DIR}/client1.invest1.demo.tetrate.io-cert.pem --key ${CERTS_BASE_DIR}/client1.invest1.demo.tetrate.io-key.pem "https://invest1.demo.tetrate.io/proxy/mid-invest1.mid-invest1/proxy/back-invest1.back-invest1" ;
    sleep 1 ;
  done

  exit 0
fi


echo "Please specify one of the following action:"
echo "  - curl"
exit 1