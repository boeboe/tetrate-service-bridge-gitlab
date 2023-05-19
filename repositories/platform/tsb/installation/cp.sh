#!/usr/bin/env bash
#
# Helper script to install tsb control plane
#
ROOT_DIR="$( cd -- "$(dirname "${0}")" >/dev/null 2>&1 ; pwd -P )"

TSB_MP_CLUSTER_CONFIG=${ROOT_DIR}/tsb-mp-cluster.json
TSB_CP_CLUSTERS_CONFIG=${ROOT_DIR}/tsb-cp-clusters.json
CERT_OUTPUT_DIR=${ROOT_DIR}/output/istio-certs
TSB_OUTPUT_DIR=${ROOT_DIR}/output/tsb
INSTALL_REPO_URL=${CI_REGISTRY}/platform/tsb/images

ACTION=${1}


# Print info messages
#   args:
#     (1) message
function print_info {
  purpleb="\033[1;35m"
  end="\033[0m"
  echo -e "${purpleb}${1}${end}"
}

# Login as admin into tsb
#   args:
#     (1) organization
function login_tsb_admin {
  expect <<DONE
  spawn tctl login --username admin --password admin --org ${1}
  expect "Tenant:" { send "\\r" }
  expect eof
DONE
}

# Patch OAP refresh rate of control plane
#   args:
#     (1) cluster name
function patch_oap_refresh_rate_cp {
  OAP_PATCH='{"spec":{"components":{"oap":{"streamingLogEnabled":true,"kubeSpec":{"deployment":{"env":[{"name":"SW_CORE_PERSISTENT_PERIOD","value":"5"}]}}}}}}'
  kubectl --context ${1} -n istio-system patch controlplanes controlplane --type merge --patch ${OAP_PATCH}
}


if [[ ${ACTION} = "install" ]]; then

  mp_cluster_name=`jq -r '.cluster_name' ${TSB_MP_CLUSTER_CONFIG}`
  mp_output_dir=${TSB_OUTPUT_DIR}/${mp_cluster_name}
  cp_cluster_count=`jq '. | length' ${TSB_CP_CLUSTERS_CONFIG}`

  kubectl config use-context ${mp_cluster_name} ;
  login_tsb_admin tetrate ;

  export TSB_API_ENDPOINT=$(kubectl --context ${mp_cluster_name} get svc -n tsb envoy --output jsonpath='{.status.loadBalancer.ingress[0].ip}') ;
  export TSB_INSTALL_REPO_URL=${INSTALL_REPO_URL}

  for ((i=0; i<$cp_cluster_count; i++)); do
    cp_cluster_name=`jq -r '.['$i'].cluster_name' ${TSB_CP_CLUSTERS_CONFIG}`
    cp_output_dir=${TSB_OUTPUT_DIR}/${cp_cluster_name} ;
    print_info "Start installation of tsb control plane in k8s cluster '${cp_cluster_name}'"

    # bootstrap cluster with self signed certificate that shares a common root certificate
    #   REF: https://docs.tetrate.io/service-bridge/1.6.x/en-us/setup/self_managed/onboarding-clusters#intermediate-istio-ca-certificates
    print_info "Bootstrap cluster '${cp_cluster_name}' with self signed certificate that shares a common root certificate"
    if kubectl --context ${cp_cluster_name} get ns istio-system &>/dev/null; then
      echo "Namespace 'istio-system' already exists in cluster ${cp_cluster_name}"
    else
      kubectl --context ${cp_cluster_name} create ns istio-system ;
    fi
    if kubectl --context ${cp_cluster_name} -n istio-system get secret cacerts &>/dev/null; then
      echo "Secret 'cacerts' in namespace 'istio-system' already exists in cluster ${cp_cluster_name}"
    else
      kubectl --context ${cp_cluster_name} create secret generic cacerts -n istio-system \
        --from-file=${CERT_OUTPUT_DIR}/${cp_cluster_name}/ca-cert.pem \
        --from-file=${CERT_OUTPUT_DIR}/${cp_cluster_name}/ca-key.pem \
        --from-file=${CERT_OUTPUT_DIR}/${cp_cluster_name}/root-cert.pem \
        --from-file=${CERT_OUTPUT_DIR}/${cp_cluster_name}/cert-chain.pem ;
    fi

    # Generate a service account private key for this controlplane cluster
    #   REF: https://docs.tetrate.io/service-bridge/1.6.x/en-us/setup/self_managed/onboarding-clusters#using-tctl-to-generate-secrets
    print_info "Generate a service account private key for this controlplane cluster '${cp_cluster_name}'"
    mkdir -p ${cp_output_dir}
    kubectl config use-context ${mp_cluster_name} ;
    tctl install cluster-service-account --cluster ${cp_cluster_name} > ${cp_output_dir}/cluster-service-account.jwk ;

    # Create control plane secrets
    #   REF: https://docs.tetrate.io/service-bridge/1.6.x/en-us/setup/self_managed/onboarding-clusters#using-tctl-to-generate-secrets
    kubectl config use-context ${mp_cluster_name} ;
    tctl install manifest control-plane-secrets \
      --cluster ${cp_cluster_name} \
      --cluster-service-account="$(cat ${cp_output_dir}/cluster-service-account.jwk)" \
      --elastic-ca-certificate="$(cat ${mp_output_dir}/es-certs.pem)" \
      --management-plane-ca-certificate="$(cat ${mp_output_dir}/mp-certs.pem)" \
      --xcp-central-ca-bundle="$(cat ${mp_output_dir}/xcp-central-ca-certs.pem)" \
      > ${cp_output_dir}/controlplane-secrets.yaml ;

    # Generate controlplane.yaml by inserting the correct mgmt plane API endpoint IP address
    export TSB_CLUSTER_NAME=${cp_cluster_name}
    envsubst < ${ROOT_DIR}/templates/controlplane.yaml > ${cp_output_dir}/controlplane.yaml ;

    # Deploy operators
    #   REF: https://docs.tetrate.io/service-bridge/1.6.x/en-us/setup/self_managed/onboarding-clusters#deploy-operators
    kubectl config use-context ${mp_cluster_name} ;
    login_tsb_admin tetrate ;
    tctl install manifest cluster-operators --registry ${INSTALL_REPO_URL} > ${cp_output_dir}/clusteroperators.yaml ;

    # Applying operator, secrets and controlplane configuration
    print_info "Applying operator, secrets and controlplane configuration in cluster '${cp_cluster_name}'"
    kubectl --context ${cp_cluster_name} apply -f ${cp_output_dir}/clusteroperators.yaml ;
    kubectl --context ${cp_cluster_name} apply -f ${cp_output_dir}/controlplane-secrets.yaml ;
    while ! kubectl --context ${cp_cluster_name} get controlplanes.install.tetrate.io &>/dev/null; do sleep 1; done ;
    kubectl --context ${cp_cluster_name} apply -f ${cp_output_dir}/controlplane.yaml ;

    print_info "Bootstrapped installation of tsb controlplane in cluster '${cp_cluster_name}'"
  done

  for ((i=0; i<$cp_cluster_count; i++)); do
    cp_cluster_name=`jq -r '.['$i'].cluster_name' ${TSB_CP_CLUSTERS_CONFIG}`
    # Wait for the controlplane and dataplane to become available
    print_info "Wait for the controlplane and dataplane to become available in cluster '${cp_cluster_name}'"
    kubectl --context ${cp_cluster_name} wait deployment -n istio-system tsb-operator-control-plane --for condition=Available=True --timeout=600s ;
    kubectl --context ${cp_cluster_name} wait deployment -n istio-gateway tsb-operator-data-plane --for condition=Available=True --timeout=600s ;
    while ! kubectl --context ${cp_cluster_name} get deployment -n istio-system edge &>/dev/null; do sleep 5; done ;
    kubectl --context ${cp_cluster_name} wait deployment -n istio-system edge --for condition=Available=True --timeout=600s ;
    kubectl --context ${cp_cluster_name} get pods -A ;

    # Apply OAP patch for more real time update in the UI (Apache SkyWalking demo tweak)
    patch_oap_refresh_rate_cp ${cp_cluster_name} ;

    print_info "Finished installation of tsb controlplane in cluster '${cp_cluster_name}'"
  done

  exit 0
fi

echo "Please specify one of the following action:"
echo "  - install"
exit 1