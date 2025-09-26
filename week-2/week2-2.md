## 목표
- config.toml을 통해 생성한 사용자 접속을 패스워드가 아닌 SSH 키 기반 인증으로 수행

## 1. SSH 키 생성
```bash
> ssh-keygen -t rsa -b 4096 -C "beengineer0420@gmail.com" -f ~/.ssh/beengineer_rsa
```
- 생성한 SSH Public Key를 GitHub 등록하여 편리하게 사용할 수 있도록 합니다.

## 2. Containerfile 작성
```bash
cat <<EOF > ./Containerfile
ARG BASE="quay.io/fedora/fedora-bootc:42"

FROM $BASE

RUN mkdir -p /var/root/home

RUN dnf insatll -y \
@core \
@development-tools \
podman \
lshw sysstat \
&& dnf clean all \
&& rm -rf /var/cache/libdnf5

RUN systemctl enable podman
RUN systemctl enable sshd
EOF
```

## 3. Build Config
- kickstart를 활용한 config 설정을 통해서, 기본 사용자를 생성합니다.
- SSH 키 기반 접근을 위해서 퍼블릭 키 내용을 작성합니다. 테스트 목적을 위해 password 필드도 남겨둡니다.
```sh
cat <<EOF > ./config.toml
[[customizations.user]]
name = "test"
password = "testtest"
key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDFGdN6jCcvNSbV4zXF8qLtE7yES+BPwdJydHYpewd/GNGUhGumCz4OOn9xs7m7/BMRxzeyUJCn7zlSw4RZn2iCw9kmVS6YILyWxsQlVD5Uq5683yRRqcjcsNIWlf6LePHgqguGAIaoTMlJBsNxzZvLU50Nonwa1Ug5D3RdJT7MxFaiHMBcCS8W6UTHxX76Euph7WjS/fRKM7ubp8VHfDG80IZy7ymULZrtOZp9aK3ugLC6AQFE3Y/Xntqye8QiS7FsUF4stefFLKrBpVRhtXVzdp8ZYX4L9+4deTUp2B7R6L0TcG8VSlebJR53KxKx0OZlqbIlv7BR/vgPDycFsLOgq0ztms8AgDqOb2agENvuWnsoqA/PG0ETQ6KxlyCFgu19vPFLVb61LsKbFTmMucBdE2LhuO38q1TeKBKnTXJJ9P1CAMTVMn4KtFk98fUOf7y2ojKCOy0/wt3UU6QZ3QsKHcTQuy3ZX/8FJzJQ0TZWvqVBkBUs+Y8wWIoyZDQ5tQuIDtKw6oqKp4Vech9M02/srQQ/uOzF7xjZQ13WtlwqQtkC0Ydpf520IVZ3w+V4CdaoJTx4sgbwY7p0dl4CnVVkttVC9p+Liwb4mxzKtvY2NGoKUMbqU5FzPalw0SqttxRCDD0dEuZHdml2i+qWRF80tblbYXfApLo/ClNLmp1TlQ=="
groups = ["wheel"]
EOF
```

## 4. Build
- `build-anaconda-iso-v2.sh`
```bash
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
```

- Build
```bash
> sh build-anaconda-iso-v2.sh
```
