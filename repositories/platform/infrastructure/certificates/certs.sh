#!/usr/bin/env bash
#
# Helper script to manage minikube based kubernetes clusters
#
ROOT_DIR="$( cd -- "$(dirname "${0}")" >/dev/null 2>&1 ; pwd -P )"

ROOT_CERTS_DIR=${ROOT_DIR}/root
ISTIO_CERTS_OUTPUT_DIR=${ROOT_DIR}/output/istio-certs
INGRESS_CLIENT_CERTS_OUTPUT_DIR=${ROOT_DIR}/output/ingress-certs/client
INGRESS_SERVER_CERTS_OUTPUT_DIR=${ROOT_DIR}/output/ingress-certs/server

CERTIFICATE_CONFIG=${ROOT_DIR}/certs.json

ACTION=${1}

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

# Print info messages
#   args:
#     (1) message
function print_error {
  redb="\033[1;31m"
  end="\033[0m"
  echo -e "${redb}${1}${end}"
}

# Generate an intermediate istio certificate signed by the self signed root certificate
#   args:
#     (1) cluster name
function generate_intermediate_istio_cert {
  if [[ ! -f "${ROOT_CERTS_DIR}/root-cert.pem" ]]; then 
    print_error "Unable to find root certificate '${ROOT_CERTS_DIR}/root-cert.pem', quitting...";
    exit 1
  fi
  if [[ -f "${ISTIO_CERTS_OUTPUT_DIR}/${1}/ca-cert.pem" ]]; then 
    echo "File ${ISTIO_CERTS_OUTPUT_DIR}/${1}/ca-cert.pem already exists... skipping istio certificate generation" ;
    return ;
  fi

  mkdir -p ${ISTIO_CERTS_OUTPUT_DIR}/${1} ;
  openssl req -newkey rsa:4096 -sha512 -nodes \
    -keyout ${ISTIO_CERTS_OUTPUT_DIR}/${1}/ca-key.pem \
    -subj "/CN=Intermediate CA/O=Istio/L=${1}" \
    -out ${ISTIO_CERTS_OUTPUT_DIR}/${1}/ca-cert.csr ;
  openssl x509 -req -sha512 -days 730 -CAcreateserial \
    -CA ${ROOT_CERTS_DIR}/root-cert.pem \
    -CAkey ${ROOT_CERTS_DIR}/root-key.pem \
    -in ${ISTIO_CERTS_OUTPUT_DIR}/${1}/ca-cert.csr \
    -extfile <(printf "subjectKeyIdentifier=hash\nbasicConstraints=critical,CA:true,pathlen:0\nkeyUsage=critical,digitalSignature,nonRepudiation,keyEncipherment,keyCertSign\nsubjectAltName=DNS.1:istiod.istio-system.svc") \
    -out ${ISTIO_CERTS_OUTPUT_DIR}/${1}/ca-cert.pem ;
  cat ${ISTIO_CERTS_OUTPUT_DIR}/${1}/ca-cert.pem ${ROOT_CERTS_DIR}/root-cert.pem >> ${ISTIO_CERTS_OUTPUT_DIR}/${1}/cert-chain.pem ;
  cp ${ROOT_CERTS_DIR}/root-cert.pem ${ISTIO_CERTS_OUTPUT_DIR}/${1}/root-cert.pem ;
  echo "New intermediate istio certificate generated at ${ISTIO_CERTS_OUTPUT_DIR}/${1}/ca-cert.pem"
}

# Generate an ingress client certificate signed by the self signed root certificate
#   args:
#     (1) client name (eg client1)
#     (2) server name (eg helloworld)
#     (3) domain name (eg example.com)
#   output:
#     (eg) ingress client certificate with CN=client1.helloworld.example.com
function generate_ingress_client_cert {
  if [[ ! -f "${ROOT_CERTS_DIR}/root-cert.pem" ]]; then 
    print_error "Unable to find root certificate '${ROOT_CERTS_DIR}/root-cert.pem', quitting...";
    exit 1
  fi
  if [[ -f "${INGRESS_CLIENT_CERTS_OUTPUT_DIR}/${2}/${1}.${2}.${3}-cert.pem" ]]; then
    echo "File ${INGRESS_CLIENT_CERTS_OUTPUT_DIR}/${2}/${1}.${2}.${3}-cert.pem already exists... skipping client certificate generation" ;
    return ;
  fi

  mkdir -p ${INGRESS_CLIENT_CERTS_OUTPUT_DIR}/${2} ;
  openssl req -newkey rsa:4096 -sha512 -nodes \
    -keyout ${INGRESS_CLIENT_CERTS_OUTPUT_DIR}/${2}/${1}.${2}.${3}-key.pem \
    -subj "/CN=${1}.${2}.${3}/O=Customer/C=US/ST=CA" \
    -out ${INGRESS_CLIENT_CERTS_OUTPUT_DIR}/${2}/${1}.${2}.${3}-cert.csr ;
  openssl x509 -req -sha512 -days 3650 -set_serial 1 \
    -CA ${ROOT_CERTS_DIR}/root-cert.pem \
    -CAkey ${ROOT_CERTS_DIR}/root-key.pem \
    -in ${INGRESS_CLIENT_CERTS_OUTPUT_DIR}/${2}/${1}.${2}.${3}-cert.csr \
    -out ${INGRESS_CLIENT_CERTS_OUTPUT_DIR}/${2}/${1}.${2}.${3}-cert.pem ;
  cat ${INGRESS_CLIENT_CERTS_OUTPUT_DIR}/${2}/${1}.${2}.${3}-cert.pem ${ROOT_CERTS_DIR}/root-cert.pem >> ${INGRESS_CLIENT_CERTS_OUTPUT_DIR}/${2}/${1}.${2}.${3}-cert-chain.pem ;
  cp ${ROOT_CERTS_DIR}/root-cert.pem ${INGRESS_CLIENT_CERTS_OUTPUT_DIR}/${2}/root-cert.pem ;
  echo "New ingress client certificate generated at ${INGRESS_CLIENT_CERTS_OUTPUT_DIR}/${2}/${1}.${2}.${3}-cert.pem"
}

# Generate an ingress server certificate signed by the self signed root certificate
#   args:
#     (1) server name (eg. helloworld)
#     (2) domain name (eg. example.com)
#   output:
#     (eg) ingress server certificate with CN=helloworld.example.com
function generate_ingress_server_cert {
  if [[ ! -f "${ROOT_CERTS_DIR}/root-cert.pem" ]]; then 
    print_error "Unable to find root certificate '${ROOT_CERTS_DIR}/root-cert.pem', quitting...";
    exit 1
  fi
  if [[ -f "${INGRESS_SERVER_CERTS_OUTPUT_DIR}/${1}/${1}.${2}-cert.pem" ]]; then
    echo "File ${INGRESS_SERVER_CERTS_OUTPUT_DIR}/${1}/${1}.${2}-cert.pem already exists... skipping server certificate generation" ;
    return ;
  fi

  mkdir -p ${INGRESS_SERVER_CERTS_OUTPUT_DIR}/${1} ;
  openssl req -newkey rsa:4096 -sha512 -nodes \
    -keyout ${INGRESS_SERVER_CERTS_OUTPUT_DIR}/${1}/${1}.${2}-key.pem \
    -subj "/CN=${1}.${2}/O=Tetrate/C=US/ST=CA" \
    -out ${INGRESS_SERVER_CERTS_OUTPUT_DIR}/${1}/${1}.${2}-cert.csr ;
  openssl x509 -req -sha512 -days 3650 -set_serial 0 \
    -CA ${ROOT_CERTS_DIR}/root-cert.pem \
    -CAkey ${ROOT_CERTS_DIR}/root-key.pem \
    -in ${INGRESS_SERVER_CERTS_OUTPUT_DIR}/${1}/${1}.${2}-cert.csr \
    -extfile <(printf "subjectAltName=DNS:${1}.${2},DNS:${2},DNS:*.${2},DNS:localhost") \
    -out ${INGRESS_SERVER_CERTS_OUTPUT_DIR}/${1}/${1}.${2}-cert.pem ;
  cat ${INGRESS_SERVER_CERTS_OUTPUT_DIR}/${1}/${1}.${2}-cert.pem ${ROOT_CERTS_DIR}/root-cert.pem >> ${INGRESS_SERVER_CERTS_OUTPUT_DIR}/${1}/${1}.${2}-cert-chain.pem ;
  cp ${ROOT_CERTS_DIR}/root-cert.pem ${INGRESS_SERVER_CERTS_OUTPUT_DIR}/${1}/root-cert.pem ;
  echo "New ingress server certificate generated at ${INGRESS_SERVER_CERTS_OUTPUT_DIR}/${1}/${1}.${2}-cert.pem"
}


if [[ ${ACTION} = "generate" ]]; then

  print_info "Going to generate intermediate istio certificates"
  cluster_count=$(jq '.istio.cluster_names | length' ${CERTIFICATE_CONFIG})
  for ((cluster_index=0; cluster_index<${cluster_count}; cluster_index++)); do
    cluster_name=$(jq -r '.istio.cluster_names['${cluster_index}']' ${CERTIFICATE_CONFIG})
    print_info "Going to generate intermediate istio certificate for cluster with name '${cluster_name}'"
    generate_intermediate_istio_cert ${cluster_name};
  done

  print_info "Going to generate ingress client and server certificates"
  ingress_count=$(jq '.ingress | length' ${CERTIFICATE_CONFIG})
  for ((ingress_index=0; ingress_index<${ingress_count}; ingress_index++)); do
    ingress_domain_name=$(jq -r '.ingress['${ingress_index}'].domain' ${CERTIFICATE_CONFIG})
    ingress_server_name=$(jq -r '.ingress['${ingress_index}'].server' ${CERTIFICATE_CONFIG})
    print_info "Going to generate ingress server certificate for server '${ingress_server_name}.${ingress_domain_name}'"
    generate_ingress_server_cert ${ingress_server_name} ${ingress_domain_name};

    ingress_client_count=$(jq '.ingress['${cluster_index}'].clients | length' ${CERTIFICATE_CONFIG})
    for ((ingress_client_index=0; ingress_client_index<${ingress_client_count}; ingress_client_index++)); do
      ingress_client_name=$(jq -r '.ingress['${ingress_index}'].clients['${ingress_client_index}']' ${CERTIFICATE_CONFIG})
      print_info "Going to generate ingress client certificate for '${ingress_client_name}.${ingress_server_name}.${ingress_domain_name}'"
      generate_ingress_client_cert ${ingress_client_name} ${ingress_server_name} ${ingress_domain_name};
    done
  done

  exit 0
fi

echo "Please specify one of the following action:"
echo "  - generate"
exit 1