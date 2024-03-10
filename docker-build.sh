#!/bin/bash

set -e

eval $(azd env get-values)

TAG=$(date --utc +%Y%m%dT%H%M%SZ)

az acr login --subscription ${AZURE_SUBSCRIPTION_ID} --name ${AZURE_CONTAINER_REGISTRY_NAME}

docker build . -t ${APP_IMAGE_NAME}:${TAG}

docker push ${APP_IMAGE_NAME}:${TAG}

azd env set APP_IMAGE_TAG ${TAG}
