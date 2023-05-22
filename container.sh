#!/usr/bin/env bash
#
# Helper script to pull and push images from private container repo in order
# to avoid docker.io, grc.io and quay.io dependencies
#

ACTION=${1}

CONTAINER_REPO="harbor.allbits.info/poc"

IMAGES="
quay.io/metallb/controller:v0.9.6;${CONTAINER_REPO}/controller:v0.9.6
quay.io/metallb/speaker:v0.9.6;${CONTAINER_REPO}/speaker:v0.9.6
gcr.io/k8s-minikube/kicbase:v0.0.39;${CONTAINER_REPO}/kicbase:v0.0.39
registry:2;${CONTAINER_REPO}/registry:2
gitlab/gitlab-ee:15.11.3-ee.0;${CONTAINER_REPO}/gitlab-ee:15.11.3-ee.0
"

# Colors
end="\033[0m"
greenb="\033[1;32m"

# Print info messages
function print_info {
  echo -e "${greenb}${1}${end}"
}

if [[ ${ACTION} = "login" ]]; then
  print_info "docker login ${CONTAINER_REPO}"
  docker login ${CONTAINER_REPO}
  exit 0
fi

if [[ ${ACTION} = "push" ]]; then
  for image in ${IMAGES} ; do
    src_img=$(echo ${image} | tr ";" " " | awk '{ print $1 }')
    dst_img=$(echo ${image} | tr ";" " " | awk '{ print $NF }')
    
    print_info "docker pull ${src_img}"
    docker pull ${src_img}
    
    print_info "docker tag ${src_img} ${dst_img}"
    docker tag ${src_img} ${dst_img}
    
    print_info "docker push ${dst_img}"
    docker push ${dst_img}
  done

  exit 0
fi

if [[ ${ACTION} = "pull" ]]; then
  for image in ${IMAGES} ; do
    src_img=$(echo ${image} | tr ";" " " | awk '{ print $1 }')
    dst_img=$(echo ${image} | tr ";" " " | awk '{ print $NF }')
    print_info "docker pull ${dst_img}"
    docker pull ${dst_img}

    print_info "docker tag ${dst_img} ${src_img}"
    docker tag ${dst_img} ${src_img}
  done

  exit 0
fi

echo "Please specify one of the following action:"
echo "  - login"
echo "  - push"
echo "  - pull"
exit 1