#!/usr/bin/env bash
#
# Helper script to configure tsb
#
ROOT_DIR="$( cd -- "$(dirname "${0}")" >/dev/null 2>&1 ; pwd -P )"

OUTPUT_DIR=${ROOT_DIR}/output/tsb
CERTS_BASE_DIR=${ROOT_DIR}/output/ingress-certs/client/abc

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
  ABC_T1_GW_IP=$(kubectl --context mgmt get svc -n tier1-gw-abc tier1-gw-abc --output jsonpath='{.status.loadBalancer.ingress[0].ip}') ;
  echo "curl -v -H \"X-B3-Sampled: 1\" --resolve \"abc.demo.tetrate.io:443:${ABC_T1_GW_IP}\" --cacert ${CERTS_BASE_DIR}/root-cert.pem --cert ${CERTS_BASE_DIR}/client1.abc.demo.tetrate.io-cert.pem --key ${CERTS_BASE_DIR}/client1.abc.demo.tetrate.io-key.pem \"https://abc.demo.tetrate.io/proxy/app-b.ns-b/proxy/app-c.ns-c\""

  for ((i=0; i<${CURL_COUNT}; i++)); do
    curl -v -H "X-B3-Sampled: 1" --resolve "abc.demo.tetrate.io:443:${ABC_T1_GW_IP}" --cacert ${CERTS_BASE_DIR}/root-cert.pem --cert ${CERTS_BASE_DIR}/client1.abc.demo.tetrate.io-cert.pem --key ${CERTS_BASE_DIR}/client1.abc.demo.tetrate.io-key.pem "https://abc.demo.tetrate.io/proxy/app-b.ns-b/proxy/app-c.ns-c" ;
    sleep 1 ;
  done

  exit 0
fi


echo "Please specify one of the following action:"
echo "  - curl"
exit 1