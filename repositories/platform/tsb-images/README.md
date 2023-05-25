# TSB Container Images

This repo contains a cicd pipeline definition that will
 - pull the TSB container images from the tetrate private registry
 - tag each image for gitlab's built-in container registry
 - push each image to gitlab's built-in container registry

Two extra images are added for demo and debug purposes
 - obs-tester-server
 - netshoot
