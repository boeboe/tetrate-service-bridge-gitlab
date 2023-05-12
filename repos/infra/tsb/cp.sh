#!/usr/bin/env bash
#
# Helper script to install tsb control plane
#
ROOT_DIR="$( cd -- "$(dirname "${0}")" >/dev/null 2>&1 ; pwd -P )"

TSB_CP_CLUSTERS_CONFIG=${ROOT_DIR}/tsb-cp-clusters.json
CERT_OUTPUT_DIR=${ROOT_DIR}/output/istio-certs

ACTION=${1}


# Print info messages
#   args:
#     (1) message
function print_info {
  purpleb="\033[1;35m"
  end="\033[0m"
  echo -e "${purpleb}${1}${end}"
}

# Generate an intermediate istio certificate signed by the self signed root certificate
#   args:
#     (1) cluster name
function generate_istio_cert {
  if [[ -f "${CERT_OUTPUT_DIR}/${1}/ca-cert.pem" ]]; then 
    echo "File ${CERT_OUTPUT_DIR}/${1}/ca-cert.pem already exists... skipping istio certificate generation" ;
    return ;
  fi

  mkdir -p ${CERT_OUTPUT_DIR}/${1} ;
  openssl req -newkey rsa:4096 -sha512 -nodes \
    -keyout ${CERT_OUTPUT_DIR}/${1}/ca-key.pem \
    -subj "/CN=Intermediate CA/O=Istio/L=${1}" \
    -out ${CERT_OUTPUT_DIR}/${1}/ca-cert.csr ;
  openssl x509 -req -sha512 -days 730 -CAcreateserial \
    -CA ${CERT_OUTPUT_DIR}/root-cert.pem \
    -CAkey ${CERT_OUTPUT_DIR}/root-key.pem \
    -in ${CERT_OUTPUT_DIR}/${1}/ca-cert.csr \
    -extfile <(printf "subjectKeyIdentifier=hash\nbasicConstraints=critical,CA:true,pathlen:0\nkeyUsage=critical,digitalSignature,nonRepudiation,keyEncipherment,keyCertSign\nsubjectAltName=DNS.1:istiod.istio-system.svc") \
    -out ${CERT_OUTPUT_DIR}/${1}/ca-cert.pem ;
  cat ${CERT_OUTPUT_DIR}/${1}/ca-cert.pem ${CERT_OUTPUT_DIR}/root-cert.pem >> ${CERT_OUTPUT_DIR}/${1}/cert-chain.pem ;
  cp ${CERT_OUTPUT_DIR}/root-cert.pem ${CERT_OUTPUT_DIR}/${1}/root-cert.pem ;
  echo "New intermediate istio certificate generated at ${CERT_OUTPUT_DIR}/${1}/ca-cert.pem"
}


if [[ ${ACTION} = "install" ]]; then

  cp_cluster_count=`jq '. | length' ${TSB_CP_CLUSTERS_CONFIG}`

  for ((i=0; i<$cp_cluster_count; i++)); do
    cp_cluster_ctx=`jq -r '.['$i'].k8s_context' ${TSB_CP_CLUSTERS_CONFIG}`
    cp_cluster_name=`jq -r '.['$i'].cluster_name' ${TSB_CP_CLUSTERS_CONFIG}`
    print_info "Start installation of tsb control plane in k8s cluster context '${cp_cluster_ctx}'"
  
  done

  exit 0
fi

echo "Please specify one of the following action:"
echo "  - install"
exit 1