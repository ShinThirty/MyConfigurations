#!/bin/sh

# exit when any command fails
set -e

# keep track of the last executed command
trap 'last_command=$current_command; current_command=$BASH_COMMAND' DEBUG
# echo an error message before exiting
trap 'echo "\"${last_command}\" command filed with exit code $?."' EXIT
trap 'docker image rm $TARGET_IMAGE' EXIT

# Get the image postfix from command line input
TAG_POSTFIX=$1
if [ -z $TAG_POSTFIX ]; then
    echo "Usage: push_latest_image $TAG_POSTFIX"
    exit 1
fi

# Get the id, repository and tag of the latest image
DOCKER_IMAGE_LS=$(docker image list --format "table {{.ID}}\t{{.Repository}}\t{{.Tag}}\t{{.Size}}" | sed -n 2p)
read -r ID REPO TAG <<< $DOCKER_IMAGE_LS

# Generates the image repository and tag for pushing
TAG_PREFIX=$(awk 'BEGIN{FS=OFS="-"}{NF--; print}' <<< $TAG)
TAG_WITH_POSTFIX="$TAG_PREFIX-$TAG_POSTFIX"
TARGET_IMAGE="037803949979.dkr.ecr.us-west-2.amazonaws.com/$REPO:$TAG_WITH_POSTFIX"

# Retag and push the image
docker tag $ID $TARGET_IMAGE
docker push $TARGET_IMAGE
