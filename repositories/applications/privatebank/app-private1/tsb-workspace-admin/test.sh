#!/usr/bin/env bash
#
# Helper script to configure tsb
#
ROOT_DIR="$( cd -- "$(dirname "${0}")" >/dev/null 2>&1 ; pwd -P )"

OUTPUT_DIR=${ROOT_DIR}/output/tsb
CERTS_BASE_DIR=${ROOT_DIR}/output/ingress-certs/client/uvw

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
  UVW_T1_GW_IP=$(kubectl --context mgmt get svc -n tier1-gw-uvw tier1-gw-uvw --output jsonpath='{.status.loadBalancer.ingress[0].ip}') ;
  echo "curl -v -H \"X-B3-Sampled: 1\" --resolve \"uvw.demo.tetrate.io:443:${UVW_T1_GW_IP}\" --cacert ${CERTS_BASE_DIR}/root-cert.pem --cert ${CERTS_BASE_DIR}/client1.uvw.demo.tetrate.io-cert.pem --key ${CERTS_BASE_DIR}/client1.uvw.demo.tetrate.io-key.pem \"https://uvw.demo.tetrate.io/proxy/front-private1.mid-private1/proxy/back-private1.back-private1\""

  for ((i=0; i<${CURL_COUNT}; i++)); do
    curl -v -H "X-B3-Sampled: 1" --resolve "uvw.demo.tetrate.io:443:${UVW_T1_GW_IP}" --cacert ${CERTS_BASE_DIR}/root-cert.pem --cert ${CERTS_BASE_DIR}/client1.uvw.demo.tetrate.io-cert.pem --key ${CERTS_BASE_DIR}/client1.uvw.demo.tetrate.io-key.pem "https://uvw.demo.tetrate.io/proxy/front-private1.mid-private1/proxy/back-private1.back-private1" ;
    sleep 1 ;
  done

  exit 0
fi


echo "Please specify one of the following action:"
echo "  - curl"
exit 1