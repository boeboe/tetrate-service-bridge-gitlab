#!/usr/bin/env bash
#
# Helper script to install tsb demo management/control plane
#
ROOT_DIR="$( cd -- "$(dirname "${0}")" >/dev/null 2>&1 ; pwd -P )"

TSB_MP_CLUSTER_CONFIG=${ROOT_DIR}/tsb-mp-cluster.json
CERT_OUTPUT_DIR=${ROOT_DIR}/output/istio-certs
TSB_OUTPUT_DIR=${ROOT_DIR}/output/tsb
INSTALL_REPO_URL=${CI_REGISTRY}/platform/tsb-images

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

# Patch affinity rules of management plane (demo only!)
#   args:
#     (1) cluster name
function patch_remove_affinity_mp {
  while ! kubectl --context ${1} -n tsb get managementplane managementplane &>/dev/null; do
    sleep 1 ;
  done
  for tsb_component in apiServer collector frontEnvoy iamServer mpc ngac oap webUI ; do
    kubectl patch managementplane managementplane -n tsb --type=json \
      -p="[{'op': 'replace', 'path': '/spec/components/${tsb_component}/kubeSpec/deployment/affinity/podAntiAffinity/requiredDuringSchedulingIgnoredDuringExecution/0/labelSelector/matchExpressions/0/key', 'value': 'platform.tsb.tetrate.io/demo-dummy'}]" \
      &>/dev/null;
  done
  echo "Managementplane tsb/managementplane sucessfully patched"
}

# Login as admin into tsb
#   args:
#     (1) cluster name
#     (2) organization
function login_tsb_admin {
  kubectl config use-context ${1} ;
  expect <<DONE
  spawn tctl login --username admin --password admin --org ${2}
  expect "Tenant:" { send "\\r" }
  expect eof
DONE
}

# Patch OAP refresh rate of management plane
#   args:
#     (1) cluster name
function patch_oap_refresh_rate_mp {
  oap_patch='{"spec":{"components":{"oap":{"streamingLogEnabled":true,"kubeSpec":{"deployment":{"env":[{"name":"SW_CORE_PERSISTENT_PERIOD","value":"5"}]}}}}}}'
  kubectl --context ${1} -n tsb patch managementplanes managementplane --type merge --patch ${oap_patch}
}

# Patch OAP refresh rate of control plane
#   args:
#     (1) cluster name
function patch_oap_refresh_rate_cp {
  oap_patch='{"spec":{"components":{"oap":{"streamingLogEnabled":true,"kubeSpec":{"deployment":{"env":[{"name":"SW_CORE_PERSISTENT_PERIOD","value":"5"}]}}}}}}'
  kubectl --context ${1} -n istio-system patch controlplanes controlplane --type merge --patch ${oap_patch}
}

# Patch jwt token expiration and pruneInterval
#   args:
#     (1) cluster name
function patch_jwt_token_expiration_mp {
  token_patch='{"spec":{"tokenIssuer":{"jwt":{"expiration":"36000s","tokenPruneInterval":"36000s"}}}}'
  kubectl --context ${1} -n tsb patch managementplanes managementplane --type merge --patch ${token_patch}
}

# Expose tsb gui with kubectl port-forward
#   args:
#     (1) cluster name
function expose_tsb_gui {
  sudo tee /etc/systemd/system/tsb-gui.service << EOF
[Unit]
Description=TSB GUI Exposure

[Service]
ExecStart=$(which kubectl) --kubeconfig ${HOME}/.kube/config --context ${1} port-forward -n tsb service/envoy 8443:8443 --address 0.0.0.0
Restart=always

[Install]
WantedBy=multi-user.target
EOF

  sudo systemctl daemon-reload ;
  sudo systemctl stop tsb-gui &>/dev/null ;
  sudo systemctl enable tsb-gui ;
  sudo systemctl start tsb-gui ;
  echo "The tsb gui should be available locally at https://127.0.0.1:8443"
  echo "The tsb gui should be available remotely at https://$(curl -s ifconfig.me):8443"
}


if [[ ${ACTION} = "install" ]]; then

  mp_cluster_name=`jq -r '.cluster_name' ${TSB_MP_CLUSTER_CONFIG}`
  mp_output_dir=${TSB_OUTPUT_DIR}/${mp_cluster_name}
  print_info "Start installation of tsb demo managementplane and controlplane in k8s cluster '${mp_cluster_name}'"

  # bootstrap cluster with self signed certificate that shares a common root certificate
  #   REF: https://docs.tetrate.io/service-bridge/1.6.x/en-us/setup/self_managed/onboarding-clusters#intermediate-istio-ca-certificates
  print_info "Bootstrap cluster '${mp_cluster_name}' with self signed certificate that shares a common root certificate"
  if kubectl --context ${mp_cluster_name} get ns istio-system &>/dev/null; then
    echo "Namespace 'istio-system' already exists in cluster '${mp_cluster_name}'"
  else
    kubectl --context ${mp_cluster_name} create ns istio-system ;
  fi
  if kubectl --context ${mp_cluster_name} -n istio-system get secret cacerts &>/dev/null; then
    echo "Secret 'cacerts' in namespace 'istio-system' already exists in cluster '${mp_cluster_name}'"
  else
    kubectl --context ${mp_cluster_name} create secret generic cacerts -n istio-system \
      --from-file=${CERT_OUTPUT_DIR}/${mp_cluster_name}/ca-cert.pem \
      --from-file=${CERT_OUTPUT_DIR}/${mp_cluster_name}/ca-key.pem \
      --from-file=${CERT_OUTPUT_DIR}/${mp_cluster_name}/root-cert.pem \
      --from-file=${CERT_OUTPUT_DIR}/${mp_cluster_name}/cert-chain.pem ;
  fi

  # start patching asynchronously
  patch_remove_affinity_mp ${mp_cluster_name} &

  # install tsb management plane using the demo installation profile
  #   REF: https://docs.tetrate.io/service-bridge/1.6.x/en-us/setup/self_managed/demo-installation
  #   NOTE: the demo profile deploys both the mgmt plane AND the ctrl plane in a single cluster!
  print_info "Install tsb managementplane in cluster '${mp_cluster_name}' using the demo installation profile"
  kubectl config use-context ${mp_cluster_name} ;
  tctl install demo --cluster ${mp_cluster_name} --registry ${INSTALL_REPO_URL} --admin-password admin ;

  # Wait for the management, control and data plane to become available
  print_info "Wait for the managementplane, controlplane and dataplane to become available in cluster '${mp_cluster_name}'"
  kubectl --context ${mp_cluster_name} wait deployment -n tsb tsb-operator-management-plane --for condition=Available=True --timeout=600s ;
  kubectl --context ${mp_cluster_name} wait deployment -n istio-system tsb-operator-control-plane --for condition=Available=True --timeout=600s ;
  kubectl --context ${mp_cluster_name} wait deployment -n istio-gateway tsb-operator-data-plane --for condition=Available=True --timeout=600s ;
  while ! kubectl --context ${mp_cluster_name} get deployment -n istio-system edge &>/dev/null; do sleep 1; done ;
  kubectl --context ${mp_cluster_name} wait deployment -n istio-system edge --for condition=Available=True --timeout=600s ;
  kubectl --context ${mp_cluster_name} get pods -A ;

  # Apply OAP patch for more real time update in the UI (Apache SkyWalking demo tweak)
  patch_oap_refresh_rate_mp ${mp_cluster_name} ;
  patch_oap_refresh_rate_cp ${mp_cluster_name} ;
  patch_jwt_token_expiration_mp ${mp_cluster_name} ;

  # Demo mgmt plane secret extraction (need to connect application clusters to mgmt cluster)
  #   REF: https://docs.tetrate.io/service-bridge/1.6.x/en-us/setup/self_managed/onboarding-clusters#using-tctl-to-generate-secrets (demo install)
  print_info "Extract and store tsb managementplane secrets"
  mkdir -p ${mp_output_dir}
  kubectl --context ${mp_cluster_name} get -n istio-system secret mp-certs -o jsonpath='{.data.ca\.crt}' | base64 --decode > ${mp_output_dir}/mp-certs.pem ;
  kubectl --context ${mp_cluster_name} get -n istio-system secret es-certs -o jsonpath='{.data.ca\.crt}' | base64 --decode > ${mp_output_dir}/es-certs.pem ;
  kubectl --context ${mp_cluster_name} get -n istio-system secret xcp-central-ca-bundle -o jsonpath='{.data.ca\.crt}' | base64 --decode > ${mp_output_dir}/xcp-central-ca-certs.pem ;

  print_info "Start or restart tsb-gui systemd service for port-forward exposure"
  expose_tsb_gui ${mp_cluster_name} ;

  print_info "Finished installation of tsb demo managementplane and controlplane in cluster ${mp_cluster_name}"

  exit 0
fi

echo "Please specify one of the following action:"
echo "  - install"
exit 1