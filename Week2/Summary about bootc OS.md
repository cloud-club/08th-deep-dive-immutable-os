# What is bootc?

Linux 컨테이너는 일반적으로 호스트 OS와 커널을 공유하므로, 가상 머신보다 더 가볍고 빠른 컨테이너 생성 가능

bootc 프로젝트는 이 방법을 역으로 이용해서 Linux 컨테이너 (LNC) 기술을 이용해 OS 생성

bootc가 사용하는 기본 OCI 컨테이너는 아래 포함

- linux kernel
- Bootloader
- systmed
- 시스템 유틸리티 및 드라이버

# 1. bootc기반 OS 실행 과정

bootc 기반 OS의 원리를 이해하기 위해 스크래치 Containerfile를 이용해서 아래 단계별로 어떻게 작동되는지 정리했습니다. 

1. Containerfile 작성
2. 이미지 빌드
3. ISO 이미지 생성 과정
4. VM부팅 과정

## 1. Containerfile 작성

최소 Containerfile

```bash
ARG BASE=quay.io/fedora/fedora-bootc:42

# 베이스 이미지 선택
FROM ${BASE}

# "부팅 가능한 컨테이너" 라는 표시
LABEL containers.bootc=1
```

### What is Containerfile?

- 컨테이너 이미지를 만드는 설계도
- 쉽게 생각하면 “Dockerfile”과 동일하다. 단지 Docker에서는 Dockerfile, Podman/OCI에서는 Containerfile이라고 부를 뿐
- Containerfile에 적힌 지시어 기반으로 빌더가 Layer를 쌓아 이미지를 생성함.

### Why we write Containerfile?

- 내가 원하는 OS 베이스를 선언적(**Declarative**)으로 작성하기 위함
    - 어떤 OS를 쓸지 (FORM)
    - 어떤 패키지를 설치할 지
    - 어떤 기본 설정을 할지
    - 서비스 활성화 등등
- 이렇게 작성된 Containerfile은 재현성(Reproducibility)이 좋음
    - 동일한 Containerfile로 같은 OS를 다시 만들 수 있음

## 2. 이미지 빌드 (Containerfile → 이미지 빌드)

### Containerfile 이미지 빌드

```bash
# 현재 디렉토리에 있는 Containerfile 빌드
# -t 태그 이름
podman build -t my-bootc:latest .
```

진행 과정

1. 빌드 컨텍스트 수집 : 현재 디렉토이가 빌드 컨텍스트로 지정
    - 컨텍스트 : 빌드 시 참조할 수 있는 범위
2. Containerfile 파싱 → 레이어 생성 : 
    1. Builder가 순서대로 지시어를 실행
    2. 지시어 하나가 하나의 레이어가 됨
3. 베이스 이미지 확보(FROM)
4. 최종 이미지 생성 : 모든 지시어 적용 후 OCI 이미지 생성

### 이미지 목록 확인

```bash
podman images
```

### podman build 자주 사용되는 옵션

```bash
podman build \
  -t my-bootc:dev \        # 태그 이름
  -f Containerfile \       # 파일 이름(기본은 ./Containerfile or ./Dockerfile)
  --pull=always \          # 베이스 최신 풀 강제(재현성 필요하면 생략/고정)
  --no-cache \             # 캐시 무시(클린 빌드)
  --build-arg FOO=bar \    # ARG 전달
  --platform=linux/amd64 \ # (Mac M1/M2 등) 타깃 아키 지정
  .
```

## 3. ISO 이미지 생성 과정

- `podman build`로 만든 건 OCI 컨테이너 이미지라서 부팅으로 사용할 수 없음
- 부팅 가능한 매체(ISO, qcow2, raw 디스크 이미지)로 변환해줘야 함.

| 출력 타입 | 설명 | 사용처 |
| --- | --- | --- |
| **iso** | CD/DVD 이미지 | VM 설치/테스트 시 주로 사용 |
| **raw** | 디스크 전체 이미지 | qemu/KVM에서 바로 부팅, 베어메탈 디스크에 dd 가능 |
| **qcow2** | QEMU/KVM용 디스크 | Proxmox, libvirt에 최적 |
| **vmdk** | VMware용 디스크 | VMware Workstation/ESXi |
| **ami** | AWS AMI 형태 | 클라우드 배포용 |

### 1. ISO 기본 생성 방법

```bash
podman run --rm \
  -v /var/lib/containers/storage:/var/lib/containers/storage \
  -v $(pwd)/output:/output \
  quay.io/centos-bootc/bootc-image-builder:latest \
  --type iso --rootfs ext4 my-bootc:local
```

ISO 생성 과정

1. Build Container 실행: 
    - 이미지(my-bootc)를 찾아서 rootfs를 풀 준비함
2. rootfs 추출:
    - rootfs(root filesystme) : root 디렉토리에 마운트 되는 파일 시스템 (`/usr`, `/bin`, `/lib`, `/etc` 등)
    - 빌드한 컨테이너 이미지를 풀어서 “루트 파일시스템”으로 사용
3. 부트로더/커널 준비
    - 빌더가 베이스 이미지에 있는 커널을 ISO 표준 부팅 구조로 맞게 배치
4. 디스크 포맷 설정 (—rootfs ext4)
5. ISO 생성:
    - 최종적으로 `output/` 디렉토리에 ISO파일 생성

### 2. ISO 생성 시 - config.toml 사용 방법

- `confimg.toml` 은 `bootc-image-builder` 가 이해하는 설정 파일
- ISO 기본 설정을 세밀하게 제어 가능
    - 디스크 크기, 파티션, 파일시스템, 루트 크기
    - 초기 사용자/비밀번호/SSH키 등
    - 추가 패키지 설치/삭제
- 재현성 유지 가능

최소 `config.toml` 파일

```bash
[output]
type = "iso"
rootfs = "ext4"
```

**ISO 빌드 실행**

```bash
podman run --rm \
  -v /var/lib/containers/storage:/var/lib/containers/storage \
  -v $(pwd)/output:/output \
  -v $(pwd)/config.toml:/config.toml:ro \
  quay.io/centos-bootc/bootc-image-builder:latest \
  --config /config.toml my-bootc:local
```

## 4. VM 부팅 완료

- VM 부팅은 크게 **부트로더 → 커널 → initramfs(초기 루트 환경) → rootfs → systemd → 서비스/로그인** 순서.
- bootc의 차별점은 rootfs가 **컨테이너 이미지에서 불변 형태로 마운트**된다는 점.

---

# 2. 일반 OCI Container VS bootc Container

일반 OCI 컨테이너와 bootc 컨테이너는 동일한 OCI 규격을 따르지만 목적과 동작이 다름.

## 일반 OCI Container

일반적으로 Docker Container, Podman Container

### 동작

- Layer 파일 시스템으로 구성
- 런타임 시 :
    1. 커널은 호스트(리눅스)의 커널을 공유 → 자체 커널 없음
    2. rootfs + namespace + cgroup 을 합친 작은 리눅스 환경
    3. PID 1번이 실행시킬 애플리케이션임
- ➕ 컨테이너 런타임(docker, podman)위에서 실행

### 목적

- OS 전체가 아니라 앱에 실행할 필요한 부분만 가져옴. → 특정 앱을 실행하기 위한 패키징
- 즉, 앱을 실행하기위한 단위 임

## bootc Conatiner

bootable container 줄임말

즉, 컨테이너 이미지를 OS 부팅 이미지로 쓸 수 있는 형태 ⇒ OS 전체를 컨테이너 이미지로 패키징

### 동작

- containerfile에 명시한 bootc 베이스 이미지 사용
- 런타임 시:
    - rootfs는 컨테이너 이미지 그대로 사용, 기본은 읽기 전용(immutable)
    - /PID 1번은 **systemd** (앱이 아니라 OS init 프로세스)
- ➕ 하이퍼바이저/베어메탈 부팅 환경 위에서 동작

### 목적

- 애플리케이션 단위가 아니라 운영체제(OS) 전체를 컨테이너 이미지로 패키징
- OS를 불변(Immutable)하게 배포 → 즉, OS 배포 단위로 사용하기 위한 컨테이너

---

# 3. 일반 OS VS bootc 기반 OS

일반 OS : 필요에 의한 변경이 있을 시, 패키지를 직접 설치 or 업데이트해서 운영 → Mutable

bootc OS :

- 컨테이너 이미지 단위로 OS 자체를 배포하고, 업데이트는는 기존 이미지에 업데이트하는 방식
- → immutable(내가 지키고 싶은 설정은 유지 가능)

---

# 4. bootc 솔루션의 장점

1. 불변성
    - 루트 파일시스템(`/`)은 **읽기 전용** → 런타임 변경 최소화
        - 일반 OS에서는 `/usr`, `/bin`, `/lib` 디렉토리에 프로그램, 라이브러리 설치
    - `/etc`, `/var`만 쓰기 가능 → 설정과 데이터는 분리
        - `/etc` : 각 서버의 설정 파일 저장 ex: fstab, 네트워크 설정
        - `/var` : 가변 데이터 저장 → 로그, 캐시 등
2. 업데이트 & 롤백 가능
    - Containerfile기반으로 새로운 이미지로 교체 후 재부팅
    - 문제가 생기면 롤백으로 **이전 버전 복구** 가능