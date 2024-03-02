#!/bin/bash

function create_cluster() {
    # Cluster info:
    K8S_CLUSTER_ID=k8s-dev4nk0v
    NETWORK_REGION_ID=nr-lqq7l
    NUM_BROKERS=12

    remote-scheduler-cli devel update k8scluster --id ${K8S_CLUSTER_ID} --schedulable=true
    remote-scheduler-cli devel create multitenantphysicalcluster --networkregionid ${NETWORK_REGION_ID} --k8sclusterid ${K8S_CLUSTER_ID} --brokers ${NUM_BROKERS} --enableultra=false
    remote-scheduler-cli devel update k8scluster --id ${K8S_CLUSTER_ID} --schedulable=false
}

function create_tenant() {
    # Cluster info:
    ENV_ID=env-217o0o
    K8S_CLUSTER_ID=k8s-dev4nk0v
    NETWORK_REGION_ID=nr-lqq7l

    # Account info:
    ORG_ID=827830
    USER_ID=3950875

    # Other info:
    # NOTE: use higher CKU and DURABILITY if only required
    CLUSTER_NAME=InterCellBalancingTest
    DURABILITY=LOW
    SKU=BASIC
    NETWORK_TYPE=PUBLIC

    PKC=$1
    remote-scheduler-cli devel create kafkacluster \
        --networkregionid $NETWORK_REGION_ID \
        --k8sclusterid $K8S_CLUSTER_ID \
        --physicalclusterid $PKC \
        --accountid $ENV_ID \
        --org $ORG_ID \
        --user $USER_ID \
        --name $CLUSTER_NAME \
        --durability $DURABILITY \
        --sku $SKU \
        --selectednetworktype $NETWORK_TYPE \
        --allowphysicalclustercreation=false
}

function create_api_key() {
    # Account info:
    ORG_ID=827830
    USER_ID=3950875

    LKC=$1

    remote-scheduler-cli devel create apikey \
        --orgid ${ORG_ID} \
        --userid ${USER_ID} \
        --clusterid "${LKC}"
}

function push_image() {
    echo "What is the -arm64 image tag in your local docker registry?"
    read -r SOURCE_ARM_IMAGE
    SOURCE_AMD_IMAGE=${SOURCE_ARM_IMAGE%-*}-amd64
    ARM_IMAGE=$SOURCE_ARM_IMAGE-SNAPSHOT
    AMD_IMAGE=$SOURCE_AMD_IMAGE-SNAPSHOT
    MANIFEST_IMAGE=${SOURCE_ARM_IMAGE%-*}-multi-SNAPSHOT

    echo "SOURCE_ARM_IMAGE: $SOURCE_ARM_IMAGE"
    echo "ARM_IMAGE: $ARM_IMAGE"
    echo "SOURCE_AMD_IMAGE: $SOURCE_AMD_IMAGE"
    echo "AMD_IMAGE: $AMD_IMAGE"
    echo "MANIFEST_IMAGE: $MANIFEST_IMAGE"
    read -r "?Continue (y/n)? "
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
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
    docker manifest create $REGISTRY_BASE:$MANIFEST_IMAGE $REGISTRY_BASE:$ARM_IMAGE $REGISTRY_BASE:$AMD_IMAGE --amend
    docker manifest push $REGISTRY_BASE:$MANIFEST_IMAGE
}
