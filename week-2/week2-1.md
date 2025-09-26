## `bootc` ?
- Bootable Container(부팅 가능한 컨테이너)의 줄임말입니다.
- `bootc`는 부팅 가능한 컨테이너의 핵심 구성요소입니다.
- 본래 컨테이너는 OS를 포함시키지 않고, 애플리케이션 동작에 필요한 것들만 모아서 패키징한 것을 의미합니다. 하지만 Bootable Container의 이미지에는 Linux Kernel을 포함되며, 부팅 시 사용됩니다.
- `bootc`를 통해서 OS를 컨테이너 이미지처럼 관리가 가능해집니다. 이를 통해서 Immutable을 실현할 수 있습니다.

## Goals
 - `bootc`를 통해서 커스텀 OS 컨테이너 이미지를 빌드합니다.
 - 커스텀 OS 컨테이너 이미지를 `bootc-image-builder`를 통해 `anaconda-iso` 파일로 변환합니다.
 - 변환한 `.iso` 파일을 통해 새로운 VM을 생성합니다.


## 1. podman 설치 및 활성화
```bash
> dnf update
> dnf install -y podman

# podman 상태 확인
> systemctl status 

# podman 활성화
> systemctl enable podman --now
```

## 2. `bootc` 설치

```bash
> dnf install -y bootc
```

## 3. quay.io 로그인
```bash
> podman login quay.io
Username: beengineer
Password:
```


## 4.  이미지 `pull`
```bash
> podman pull quay.io/fedora/fedora-bootc:42

> podman images
podman images
REPOSITORY                   TAG         IMAGE ID      CREATED       SIZE
quay.io/fedora/fedora-bootc  42          9d07afc88ad5  19 hours ago  1.87 GB
```

## 5. SELinux 상태 확인
```bash
> getenforce
Enforcing
```

- bootc-image-builder 깃허브 공식 가이드에 따라, `osbuild-selinux` 설치
	- https://github.com/osbuild/bootc-image-builder/tree/main?tab=readme-ov-file#-prerequisites
```bash
> dnf install -y osbuild-selinux
```

## 6. Containerfile 작성
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

## 7. Build Config
- kickstart를 활용한 config 설정을 통해서, 기본 사용자를 생성
```sh
cat <<EOF > ./config.toml
[[customizations.user]]
name = "test"
password = "testtest"
groups = ["wheel"]
EOF
```

## 8. Build
- `build-anaconda-iso.sh`
```bash
#!/bin/bash

sudo podman run \
--rm \
--privileged \
--pull=newer \
--security-opt label=type:unconfined_t \
-v ./config.toml:/config.toml:ro \
-v ./output:/output \
-v /var/lib/containers/storage:/var/lib/containers/storage \
quay.io/centos-bootc/bootc-image-builder:latest \
--type anaconda-iso \
--rootfs btrfs \
quay.io/fedora/fedora-bootc:42
```

- Build
```bash
> sh build-anaconda-iso.sh
```

- Build 결과
```bash
...

Build complete!
Results saved in .

> ls -R output/
output/:
bootiso  manifest-anaconda-iso.json

output/bootiso:
install.iso

# iso 파일 이름 변경
> mv install.iso fedora-bootc-42-custom-20250927.iso
```

## 9. proxmoxVE로 업로드
- proxmox VE iso 디렉터리 경로
	- `/mnt/hdd01_1TB/template/iso`

- `scp`로 전송
```bash
> scp fedora-bootc-42-custom-20250920.iso root@192.168.35.225:/mnt/hdd01_1TB/template/iso/
```

## 10. Custom OS VM 생성
- 생성한 커스텀 OS iso 파일을 기반으로 VM을 생성
- OS 설치 자동 진행

## 11. VM 접속 및 확인
- 빌드 과정에서 `config.toml`로 생성했던 `test` 유저로 접속

- 로그인 시 출력되는 메세지
	- 다음의 메세지는 bootc로 생성된 custom OS는 기본적으로 Read-Only이기 때문에 출력되는 메세지이다.
		- 시스템 유닛인 `systemd-remount-fs.service`는 부팅 시 `/etc/fstab`에 정의된 내용을 기반으로 파일시스템을 `rw` 모드로 remount 하는 역할을 한다.
		- 그런데, bootc로 생성된 custom OS는 `/var` 하위를 제외한 다른 파일시스템들은 `ro` 모드이기 때문에 동작이 실패하는 것이다.
```bash
> ssh test@192.168.35.102
...
[systemd]
Failed Units: 1
  systemd-remount-fs.service
```

- `/etc/fstab`
```bash
> cat /etc/fstab
UUID=dea5e061-4149-4375-ab08-e42b54dd74d6 / btrfs subvol=root,compress=zstd:1,ro 0 0
UUID=f6ca51b2-942c-4547-852f-e3702e51370c /boot                   ext4    defaults        1 2
```

- 따라서, 해당 메세지는 무시해도 된다. 필요하다면 `systemd-remount-fs.service`를 disable (bootc 이미지 빌드 시점 또는 VM 생성 후)해서 메시지를 없앨 수 있다.
