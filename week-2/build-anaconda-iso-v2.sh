#!/bin/bash

sudo podman run \
--rm \
--privileged \
--pull=newer \
--security-opt label=type:unconfined_t \
-v ./config-v2.toml:/config.toml:ro \
-v ./output-v2:/output \
-v /var/lib/containers/storage:/var/lib/containers/storage \
quay.io/centos-bootc/bootc-image-builder:latest \
--type anaconda-iso \
--rootfs btrfs \
quay.io/fedora/fedora-bootc:42
