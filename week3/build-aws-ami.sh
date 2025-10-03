#!/bin/bash

if [ $# -lt 1 ]; then
    echo "사용법: $0 <image:tag>"
    echo "예시: $0 quay.io/na3150/bootc-demo:tagA"
    exit 1
fi

IMAGE=$1

sudo podman --connection podman-machine-default-root run \
  --rm \
  -it \
  --privileged \
  --pull=newer \
  --security-opt label=type:unconfined_t \
  -v $(pwd)/config.toml:/config.toml:ro \
  -v $HOME/.aws:/root/.aws:ro \
  -v /var/lib/containers/storage:/var/lib/containers/storage \
  --env AWS_PROFILE=default \
  quay.io/centos-bootc/bootc-image-builder:latest \
  --type ami \
  --config /config.toml \
  --aws-ami-name immutable-os-ami \
  --aws-bucket immutable-os-ami-bucket \
  --aws-region ap-northeast-2 \
  --rootfs btrfs \
  $IMAGE