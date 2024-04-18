#!/bin/sh

# exit when any command fails
set -e

# keep track of the last executed command
trap 'last_command=$current_command; current_command=$BASH_COMMAND' DEBUG
# echo an error message before exiting
trap 'echo "\"${last_command}\" command filed with exit code $?."' EXIT
trap 'rm -rf kubectl' EXIT
trap 'rm -rf kubectl.sha256' EXIT

VERSION=$1

curl -LO "https://dl.k8s.io/release/v$VERSION/bin/darwin/arm64/kubectl"
curl -LO "https://dl.k8s.io/release/v$VERSION/bin/darwin/arm64/kubectl.sha256"
echo "$(cat kubectl.sha256)  kubectl" | shasum -a 256 --check

chmod +x ./kubectl
sudo mv ./kubectl /usr/local/bin/kubectl
sudo chown root: /usr/local/bin/kubectl
kubectl version --client --output=yaml
