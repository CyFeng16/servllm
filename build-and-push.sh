#!/bin/bash
# docker login -u $DOCKERHUB_USERNAME -p $DOCKERHUB_TOKEN

CUDA_VERSIONS=("12.1" "11.8")
MODEL_NAMES=("Qwen/Qwen1.5-0.5B-Chat" "Qwen/Qwen1.5-1.8B-Chat")
PYTHON_VERSIONS=("3.8" "3.9" "3.10" "3.11")
PRE_DOWNLOADS=("true" "false")

for PRE_DOWNLOAD in "${PRE_DOWNLOADS[@]}"; do
  if [ "$PRE_DOWNLOAD" = "true" ]; then
    for MODEL_NAME in "${MODEL_NAMES[@]}"; do
      # set environment variables
      SERVELLM_MODEL_NAME="${MODEL_NAME}"
      SERVELLM_PRE_DOWNLOAD="${PRE_DOWNLOAD}"
      SERVELLM_TAG=$(echo "$MODEL_NAME" | sed -e 's/.*\///' | tr '[:upper:]' '[:lower:]')
      # export environment variables
      export SERVELLM_MODEL_NAME
      export SERVELLM_PRE_DOWNLOAD
      export SERVELLM_TAG
      # print environment variables
      echo "***************"
      echo "SERVELLM_MODEL_NAME: $SERVELLM_MODEL_NAME"
      echo "SERVELLM_PRE_DOWNLOAD: $SERVELLM_PRE_DOWNLOAD"
      echo "SERVELLM_TAG: $SERVELLM_TAG"
      docker compose -f docker-compose.build.yml build
      docker compose -f docker-compose.build.yml push
      echo "***************"
    done
  elif [ "$PRE_DOWNLOAD" = "false" ]; then
    for PYTHON_VERSION in "${PYTHON_VERSIONS[@]}"; do
      for CUDA_VERSION in "${CUDA_VERSIONS[@]}"; do
        # set environment variables
        SERVELLM_CUDA_VERSION="${CUDA_VERSION}"
        SERVELLM_PYTHON_VERSION="${PYTHON_VERSION}"
        SERVELLM_PRE_DOWNLOAD="${PRE_DOWNLOAD}"
        SERVELLM_TAG="py${PYTHON_VERSION}-cu${CUDA_VERSION}"
        # export environment variables
        export SERVELLM_CUDA_VERSION
        export SERVELLM_PYTHON_VERSION
        export SERVELLM_PRE_DOWNLOAD
        export SERVELLM_TAG
        # print environment variables
        echo "***************"
        echo "SERVELLM_CUDA_VERSION: $SERVELLM_CUDA_VERSION"
        echo "SERVELLM_PYTHON_VERSION: $SERVELLM_PYTHON_VERSION"
        echo "SERVELLM_MODEL_NAME: $SERVELLM_MODEL_NAME"
        echo "SERVELLM_PRE_DOWNLOAD: $SERVELLM_PRE_DOWNLOAD"
        echo "SERVELLM_TAG: $SERVELLM_TAG"
        docker compose -f docker-compose.build.yml build
        docker compose -f docker-compose.build.yml push
        echo "***************"
      done
    done
  fi
done