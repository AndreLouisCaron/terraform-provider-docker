#!/bin/bash
set -e

log() {
  echo ""
  echo "##################################"
  echo "-------> $1"
  echo "##################################"
}

setup() {
  export DOCKER_REGISTRY_ADDRESS="127.0.0.1:5000"
  export DOCKER_REGISTRY_USER="testuser"
  export DOCKER_REGISTRY_PASS="testpwd"
  export DOCKER_PRIVATE_IMAGE="127.0.0.1:5000/tftest-service:v1"
  sh scripts/testing/setup_private_registry.sh
}

run() {
  # Run the acc test suite
  TF_ACC=1 go test ./docker -v -timeout 120m
  
  # for a single test
  #TF_LOG=INFO TF_ACC=1 go test -v github.com/terraform-providers/terraform-provider-docker/docker -run ^TestAccDockerService_full$ -timeout 360s
  # keep the return for the scripts to fail and clean properly
  return $?
}

cleanup() {
  unset DOCKER_REGISTRY_ADDRESS DOCKER_REGISTRY_USER DOCKER_REGISTRY_PASS DOCKER_PRIVATE_IMAGE
  echo "### unsetted env ###"
  for p in $(docker container ls --filter=name=private_registry -q); do docker stop $p; done
  echo "### stopped private registry ###"
  rm -f scripts/testing/auth/htpasswd
  rm -f scripts/testing/certs/registry_auth.*
  echo "### removed auth and certs ###"
  # For containers it's fixed in v18.02 https://github.com/moby/moby/issues/35933#issuecomment-366149721
  for resource in "container" "config" "secret" "network" "volume"; do
    for r in $(docker $resource ls --filter=name=tftest -q); do docker $resource rm $r; done
    echo "### removed $resource ###"
  done
  for i in $(docker images -aq 127.0.0.1:5000/tftest-service); do docker rmi -f $i; done
  echo "### removed service images ###"
}

## main
log "setup" && setup 
log "run" && run && echo $?
if [ $? -ne 0 ]; then
  log "cleanup" && cleanup
  exit 1
fi
log "cleanup" && cleanup
