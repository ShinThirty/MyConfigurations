#!/bin/bash

function create_mt_cluster() {
  export VAULT_ADDR=https://vault.cireops.gcp.internal.confluent.cloud
  vault login -method=oidc -path=okta

  # Log into maven
  maven-login

  # Authenticate AWS ECR to build
  ecr-setup

  assume 037803949979/nonprod-administrator
  kubectl-ccloud-config get devel
  export KUBECONFIG=$HOME/.kube/ccloud-config/devel/kubeconfig

  K8S_CLUSTER_ID=k8s-6j7bh
  NETWORK_REGION_ID=nr-loqyy
  NUM_BROKERS=$1

  if [[ -z $NUM_BROKERS ]]; then
    exit 1
  fi

  remote-scheduler-cli devel update k8scluster --id ${K8S_CLUSTER_ID} --schedulable=true
  remote-scheduler-cli devel create multitenantphysicalcluster --networkregionid ${NETWORK_REGION_ID} --k8sclusterid ${K8S_CLUSTER_ID} --brokers ${NUM_BROKERS} --enableultra=false
  remote-scheduler-cli devel update k8scluster --id ${K8S_CLUSTER_ID} --schedulable=false
}

function push_image() {
  echo "What is the -arm64 image tag in your local docker registry?"
  read SOURCE_ARM_IMAGE
  echo "What is the -amd64 image tag in your local docker registry?"
  read SOURCE_AMD_IMAGE
  echo "What is the desired tag of the -arm64 image?"
  read ARM_IMAGE
  echo "What is the desired tag of the -amd64 image?"
  read AMD_IMAGE
  echo "What is the name of the image to run on the brokers?"
  read MANIFEST_IMAGE

  echo "SOURCE_ARM_IMAGE: $SOURCE_ARM_IMAGE"
  echo "ARM_IMAGE: $ARM_IMAGE"
  echo "SOURCE_AMD_IMAGE: $SOURCE_AMD_IMAGE"
  echo "AMD_IMAGE: $AMD_IMAGE"
  echo "MANIFEST_IMAGE: $MANIFEST_IMAGE"
  read "?Continue (y/n)? "
  if [[ ! $REPLY =~ ^[Yy]$ ]]
  then
    [[ "$0" = "$BASH_SOURCE" ]] && exit 1 || return 1 # handle exits from shell or function but don't exit interactive shell
  fi

  SOURCE_REG_BASE=confluentinc/ce-kafka
  REGISTRY_BASE=519856050701.dkr.ecr.us-west-2.amazonaws.com/docker/dev/confluentinc/ce-kafka

  # tag the arm64 image and push it
  docker tag $SOURCE_REG_BASE:$SOURCE_ARM_IMAGE $REGISTRY_BASE:$ARM_IMAGE
  docker push $REGISTRY_BASE:$ARM_IMAGE

  # tag the amd64 image and push it
  docker tag $SOURCE_REG_BASE:$SOURCE_AMD_IMAGE $REGISTRY_BASE:$AMD_IMAGE
  docker push $REGISTRY_BASE:$AMD_IMAGE

  # Optional for ce-kafka images: Create the image manifest and push it
  docker manifest create $REGISTRY_BASE:$MANIFEST_IMAGE $REGISTRY_BASE:$ARM_IMAGE $REGISTRY_BASE:$AMD_IMAGE
  docker manifest push $REGISTRY_BASE:$MANIFEST_IMAGE
}
