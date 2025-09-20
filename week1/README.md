# Week1 HW

## Setup

- podman이 설치되어 있고, podman machine이 켜져 있는 환경에서 실습 진행

### Files

Containerfile
```Containerfile
FROM quay.io/fedora/fedora-bootc:42

RUN mkdir -p /var/roothome

RUN dnf install -y \
    vim \
    && dnf clean all

RUN bootc container lint    

LABEL containers.bootc 1
LABEL version="1.0"
LABEL description="Chunsoo bootc week1"
```
- `RUN mkdir -p /var/roothome`는 기본 루트 홈 디렉토리이지만 컨테이너 이미지 실행시 부재하기에 필수적으로 추가해야함.


config.toml
```toml
[customizations.installer.kickstart]
contents = """
timezone Asia/Seoul

# Hard-coded values below MUST be changed
ignoredisk --only-use=scsi1
clearpart --all --initlabel --drives=scsi1
autopart --type=plain

user --name=user --uid=1000 --groups=wheel --password password --plaintext

%post
echo "$(hostnamectl -j | jq -r .Chassis)-$(hostnamectl -j | jq -r .MachineID | cut -c 1-9)" | tee /etc/hostname > /dev/null
%end

reboot
"""
```

## Build and push OCI image
- 해당 단계에서는 podman을 사용하지 않고 Docker 등을 사용해도 상관없음

```shell
podman build -t chunsoo-week1 .
```

`podman images` 결과

```shell
REPOSITORY                                       TAG                                                                      IMAGE ID      CREATED        SIZE
localhost/chunsoo-week1                          latest                                                                   019af8111218  7 minutes ago  1.95 GB
```

- OCI 이미지 빌드를 확인했으니, 레지스트리에 푸쉬

```shell
podman tag localhost/chunsoo-week1 quay.io/charlie3965/immutable-os-chunsoo-week1

podman push quay.io/charlie3965/immutable-os-chunsoo-week1
```

- 아래와 같이 시각적으로도 확인 가능!

![check at registry graphically](images/check-on-registry.png)

## Build Disk Image

- podman machine이 반드시 rootful로 실행중이어야 함

```shell
podman run --rm \
        --privileged \
        --security-opt label=type:unconfined_t \
        -v ./output:/output \
        -v ./config.toml:/config.toml:ro \
        -v /var/lib/containers/storage:/var/lib/containers/storage \
        quay.io/centos-bootc/bootc-image-builder:latest \
        --type iso \
        --rootfs btrfs \
        quay.io/charlie3965/immutable-os-chunsoo-week1:latest
```