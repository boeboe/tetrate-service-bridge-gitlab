#!/usr/bin/env bash
#
# Helper script to configure tsb
#
ROOT_DIR="$( cd -- "$(dirname "${0}")" >/dev/null 2>&1 ; pwd -P )"

OUTPUT_DIR=${ROOT_DIR}/output/tsb
CERTS_BASE_DIR=${ROOT_DIR}/output/ingress-certs/client/def

ACTION=${1}
CURL_COUNT="${CURL_COUNT:-100}"

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
  print_info "Going to send test traffic (count: ${CURL_COUNT}) using curl" ;
  DEF_T1_GW_IP=$(kubectl --context mgmt get svc -n tier1-gw-def tier1-gw-def --output jsonpath='{.status.loadBalancer.ingress[0].ip}') ;
  echo "curl -v -H \"X-B3-Sampled: 1\" --resolve \"def.demo.tetrate.io:443:${DEF_T1_GW_IP}\" --cacert ${CERTS_BASE_DIR}/root-cert.pem --cert ${CERTS_BASE_DIR}/client1.def.demo.tetrate.io-cert.pem --key ${CERTS_BASE_DIR}/client1.def.demo.tetrate.io-key.pem \"https://def.demo.tetrate.io/proxy/app-e.ns-e/proxy/app-f.ns-f\""

  for ((i=0; i<${CURL_COUNT}; i++)); do
    curl -v -H "X-B3-Sampled: 1" --resolve "def.demo.tetrate.io:443:${DEF_T1_GW_IP}" --cacert ${CERTS_BASE_DIR}/root-cert.pem --cert ${CERTS_BASE_DIR}/client1.def.demo.tetrate.io-cert.pem --key ${CERTS_BASE_DIR}/client1.def.demo.tetrate.io-key.pem "https://def.demo.tetrate.io/proxy/app-e.ns-e/proxy/app-f.ns-f" ;
    sleep 1 ;
  done

  exit 0
fi


echo "Please specify one of the following action:"
echo "  - curl"
exit 1