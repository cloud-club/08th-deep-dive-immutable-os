# 1. bootc 기반 OS에서 패키지 설치와 일반 OS에서의 패키지 설치 간 차이점
- 일반 OS
  - 사용자에게 권한이 적절히 부여돼 있다면, 파일 시스템 내 모든 영역에 대해서 Write 작업이 가능하다. 따라서, yum, dnf 와 같은 패키지 매니저를 통해 필요한 패키지 설치가 가능하다.
- Bootc 기반 OS
  - Immutable을 보장하기 위해, 파일 시스템 내 특정 영역은 Read-Only 상태이다. 사용자에게 권한이 부여돼있더라도 해당 영역을 Write 작업을 하지 못한다. 일반적으로 패키지들을 구성하는 바이너리 파일들은 리눅스 내에서 `/usr` 하위 영역에 위치한다. 그런데 Bootc 기반 OS 에서는 `/usr` 영역이 Read-Only라, 패키지 파일들이 저장될 수 없다.
  - 따라서 `rpm-ostree`를 사용하여 파일 시스템 단위로 비교를 하고, 필요한 패키지를 포함하는 파일 시스템 레이어를 더하는 방식으로 패키지를 설치해야 한다.

# 2. bootc 기반 OS 내부에서 패키지를 설치
- bootc 기반 OS에서는 위의 내용에 따라, 패키지 매니저를 통해서 패키지를 설치하는 것이 불가능하다.
- `sysstat` 패키지 설치 시도
```bash
> dnf list sysstat
Updating and loading repositories:
Repositories loaded.
Available packages
sysstat.x86_64 12.7.7-1.fc42 fedora

> dnf list --installed sysstat
No matching packages to list

> dnf install -y sysstat
Updating and loading repositories:
Repositories loaded.
Package                           Arch      Version                           Repository             Size
Installing:
 sysstat                          x86_64    12.7.7-1.fc42                     fedora              1.7 MiB
Installing dependencies:
 lm_sensors-libs                  x86_64    3.6.0-22.fc42                     fedora             85.8 KiB
 pcp-conf                         x86_64    6.3.7-8.fc42                      updates            78.9 KiB
 pcp-libs                         x86_64    6.3.7-8.fc42                      updates             1.5 MiB

Transaction Summary:
 Installing:         4 packages

Total size of inbound packages is 1 MiB. Need to download 1 MiB.
After this operation, 3 MiB extra will be used (install 3 MiB, remove 0 B).
Error: this bootc system is configured to be read-only. For more information, run `bootc --help`.
```


# 3. bootc switch 를 통한 OS 변경

## Pushing Custom OS
- podman이 현재 사용 중인 레지스트리 목록 확인
```bash
> podman info | grep -A5 registries
registries:
  search:
  - registry.fedoraproject.org
  - registry.access.redhat.com
  - docker.io
store:
```

- `Containerfile` 작성
```bash
vi Containerfile
---
ARG BASE="quay.io/fedora/fedora-bootc:42"

FROM ${BASE}

LABEL containers.bootc=1

RUN mkdir -p /var/roothome

RUN curl -fsSL https://pkgs.tailscale.com/stable/fedora/tailscale.repo \
    -o /etc/yum.repos.d/tailscale.repo

RUN dnf install -y \
@core \
@development-tools \
openssh-server \
tailscale \
podman \
lshw sysstat \
&& dnf clean all \
&& rm -rf /var/cache/libdnf5

RUN systemctl enable podman sshd tailscaled
---
```

- Container image build & Tagging
```bash
# Container Image Build
> podman build -t beenginner-fedora-bootc:42 .

# 확인
> podman images
REPOSITORY                                TAG         IMAGE ID      CREATED        SIZE
localhost/beenginner-fedora-bootc         42          bee93edb9c66  2 minutes ago  2.67 GB
quay.io/fedora/fedora-bootc               42          7bb89b545afe  5 days ago     1.87 GB
quay.io/centos-bootc/bootc-image-builder  latest      19c4c21656d0  9 days ago     817 MB

# Tagging
> podman tag localhost/beenginner-fedora-bootc:42 quay.io/beengineer/bgnr-fedora-bootc-42:1.0-20251002
```

- push
```bash
> podman push quay.io/beengineer/bgnr-fedora-bootc-42:1.0-20251002
```

## 현재 OS 확인
```bash
> bootc status
● Booted image: quay.io/fedora/fedora-bootc:42
        Digest: sha256:42003245e199e410d244c85cd8800a1b3ebc938ed2ff917823fbd308e43b9279 (amd64)
       Version: 42.20250930.0 (2025-09-30T11:07:38Z)

  Rollback image: quay.io/fedora/fedora-bootc:42
          Digest: sha256:19ee5ca4f818862abe18bb7cd52e27cb9d6608c0641e31d87b23a7bf1755cacf (amd64)
         Version: 42.20251001.0 (2025-10-01T11:06:21Z)
```

## OS Switch
#### Image pulling
```bash
podman pull quay.io/beengineer/bgnr-fedora-bootc-42:1.0-20251002
Trying to pull quay.io/beengineer/bgnr-fedora-bootc-42:1.0-20251002...
```

- 확인
```bash
podman images
REPOSITORY                               TAG           IMAGE ID      CREATED      SIZE
quay.io/beengineer/bgnr-fedora-bootc-42  1.0-20251002  bee93edb9c66  5 hours ago  2.67 GB
```

### OS Switching
- Container Image를 Pull 받았기 때문에, 로컬에 있는 이미지를 바로 사용하도록 옵션을 부여하여 OS Switching 수행
```bash
> bootc switch --transport containers-storage quay.io/beengineer/bgnr-fedora-bootc-42:1.0-20251002

layers already present: 52; layers needed: 17 (527.9 MB)
Fetching layers █████████████████░░░ 15/17
 └ Fetching █████████████████░░░ 260.76 MiB/295.72 MiB (18.16 MiB/s) layer 3fb399fe86cf44780747e

layers already present: 52; layers needed: 17 (527.9 MB)
Fetched layers: 503.48 MiB in 41 seconds (12.15 MiB/s)
⠈ Deploying

Pruned images: 0 (layers: 0, objsize: 33.3 MB)
Queued for next boot: ostree-unverified-image:containers-storage:quay.io/beengineer/bgnr-fedora-bootc-42:1.0-20251002
  Version: 42.20250926.0
  Digest: sha256:9da64856e63f3166ee822e7122d717d7b42731da4ee11314a414e8d4620edc24
```

```bash
> bootc status
  Staged image: containers-storage:quay.io/beengineer/bgnr-fedora-bootc-42:1.0-20251002
        Digest: sha256:9da64856e63f3166ee822e7122d717d7b42731da4ee11314a414e8d4620edc24 (amd64)
       Version: 42.20250926.0 (2025-10-02T10:28:09Z)

● Booted image: quay.io/fedora/fedora-bootc:42
        Digest: sha256:42003245e199e410d244c85cd8800a1b3ebc938ed2ff917823fbd308e43b9279 (amd64)
       Version: 42.20250930.0 (2025-09-30T11:07:38Z)

  Rollback image: quay.io/fedora/fedora-bootc:42
          Digest: sha256:19ee5ca4f818862abe18bb7cd52e27cb9d6608c0641e31d87b23a7bf1755cacf (amd64)
         Version: 42.20251001.0 (2025-10-01T11:06:21Z)
```

- `reboot`
```bash
> reboot
```

- 확인
```bash
> bootc status
● Booted image: containers-storage:quay.io/beengineer/bgnr-fedora-bootc-42:1.0-20251002
        Digest: sha256:9da64856e63f3166ee822e7122d717d7b42731da4ee11314a414e8d4620edc24 (amd64)
       Version: 42.20250926.0 (2025-10-02T10:28:09Z)

  Rollback image: quay.io/fedora/fedora-bootc:42
          Digest: sha256:42003245e199e410d244c85cd8800a1b3ebc938ed2ff917823fbd308e43b9279 (amd64)
         Version: 42.20250930.0 (2025-09-30T11:07:38Z)
```

- Container Image Build 과정에서 추가시킨 패키지들 정상 설치 여부 확인
```bash
# podman
systemctl status podman
○ podman.service - Podman API Service
     Loaded: loaded (/usr/lib/systemd/system/podman.service; enabled; preset: disabled)
    Drop-In: /usr/lib/systemd/system/service.d
             └─10-timeout-abort.conf
     Active: inactive (dead) since Thu 2025-10-02 15:42:43 UTC; 6min ago


# tailscale
> systemctl status tailscaled
● tailscaled.service - Tailscale node agent
     Loaded: loaded (/usr/lib/systemd/system/tailscaled.service; enabled; preset: disabled)
    Drop-In: /usr/lib/systemd/system/service.d
             └─10-timeout-abort.conf
     Active: active (running) since Thu 2025-10-02 15:42:40 UTC; 5min ago
```

# 4. bootc rollback
```bash
bootc status
● Booted image: containers-storage:quay.io/beengineer/bgnr-fedora-bootc-42:1.0-20251002
        Digest: sha256:9da64856e63f3166ee822e7122d717d7b42731da4ee11314a414e8d4620edc24 (amd64)
       Version: 42.20250926.0 (2025-10-02T10:28:09Z)

  Rollback image: quay.io/fedora/fedora-bootc:42
          Digest: sha256:42003245e199e410d244c85cd8800a1b3ebc938ed2ff917823fbd308e43b9279 (amd64)
         Version: 42.20250930.0 (2025-09-30T11:07:38Z)
```

```bash
> bootc rollback
Next boot: rollback deployment
```

```bash
> reboot
```

- 확인
```bash
bootc status
● Booted image: quay.io/fedora/fedora-bootc:42
        Digest: sha256:42003245e199e410d244c85cd8800a1b3ebc938ed2ff917823fbd308e43b9279 (amd64)
       Version: 42.20250930.0 (2025-09-30T11:07:38Z)

  Rollback image: containers-storage:quay.io/beengineer/bgnr-fedora-bootc-42:1.0-20251002
          Digest: sha256:9da64856e63f3166ee822e7122d717d7b42731da4ee11314a414e8d4620edc24 (amd64)
         Version: 42.20250926.0 (2025-10-02T10:28:09Z)
```

- `tailscale` 유무 확인
```bash
> systemctl status tailscale
Unit tailscale.service could not be found.
```
