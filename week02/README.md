# Week 02 - bootc 기반 OS 커스터마이징 및 보안 개선

## 프로젝트 개요

Java Spring Boot 애플리케이션을 위한 bootc 기반 Immutable OS 구축 및 SSH Key 기반 보안 인증 구현

---

## 1. bootc 기반 OS를 어떻게 구축/배포했나요?

### 1.1 Containerfile 작성

**기본 구성:**

- Base Image: `quay.io/fedora/fedora-bootc:42`
- Java 21 OpenJDK 설치 (Spring Boot 3.x 호환)
- 개발/운영 도구 설치 (vim, git, htop, net-tools, bind-utils)
- Spring Boot 전용 사용자 및 디렉토리 구성
- systemd 서비스 설정

**주요 구성 요소:**

```docker
# Java 환경
RUN dnf install -y java-21-openjdk java-21-openjdk-devel

# Spring Boot 디렉토리
RUN mkdir -p /opt/springboot /var/log/springboot

# 서비스 사용자
RUN useradd -r -s /bin/false -d /opt/springboot springboot

# 관리자 계정 (SSH Key 전용)
RUN useradd -m -G wheel admin

```

### 1.2 빌드 프로세스

```bash
# 1. 이미지 빌드 (AWS Ubuntu 서버)
sudo podman build -f SpringBootContainerfile -t quay.io/tkaqhcjstk/springboot-bootc:1.0 .

# 2. 태그 지정
podman tag localhost/springboot-bootc:latest quay.io/tkaqhcjstk/springboot-bootc:1.0

# 3. Registry Push
podman push quay.io/tkaqhcjstk/springboot-bootc:1.0

```

### 1.3 disk.raw 생성

**bootc-image-builder 사용:**

```bash
sudo podman run --rm -it \
  --privileged \
  --security-opt label=type:unconfined_t \
  -v /var/lib/containers/storage:/var/lib/containers/storage \
  -v $(pwd)/output:/output \
  -v $(pwd)/config.toml:/config.toml:ro \
  quay.io/centos-bootc/bootc-image-builder:latest \
  --type raw \
  --rootfs xfs \
  --config /config.toml \
  quay.io/tkaqhcjstk/springboot-bootc:1.0

```

**주요 옵션:**

- `-type raw`: RAW 디스크 이미지 포맷
- `-rootfs xfs`: XFS 파일시스템 사용
- `-config /config.toml`: 런타임 설정 주입

### 1.4 배포 및 부팅

**QEMU 환경에서 테스트:**

```bash
sudo qemu-system-x86_64 -m 2048 \
  -drive file=./image/disk-springboot.raw,format=raw \
  -nographic \
  -netdev user,id=net0,hostfwd=tcp::2222-:22 \
  -device virtio-net-pci,netdev=net0

```

---

## 2. 일반적인 OCI 컨테이너와 bootc 컨테이너의 차이

### 2.1 일반 OCI 컨테이너

**목적:** 애플리케이션 실행 환경
**수명:** 단기, 일시적 (stateless)
**시스템:** systemd 불필요, 단일 프로세스

**예시:**

```docker
FROM node:18
WORKDIR /app
COPY . .
CMD ["node", "server.js"]
```

### 2.2 bootc 컨테이너

**목적:** OS 전체 이미지
**수명:** 장기, 영구적
**시스템:** systemd 필수, 다중 서비스

**특징:**

- `LABEL containers.bootc=1` 필수
- systemd 서비스 관리
- bootc container lint 검증
- 부팅 가능한 완전한 OS

**차이점 비교:**

| 항목 | 일반 OCI 컨테이너 | bootc 컨테이너 |
| --- | --- | --- |
| 용도 | 앱 실행 | OS 이미지 |
| Init | 불필요 | systemd |
| 부팅 | 불가 | 가능 |
| 서비스 관리 | 단일 프로세스 | systemd units |
| 검증 | 선택 | bootc lint 필수 |

---

## 3. 일반적인 OS와 bootc 기반 OS의 차이

### 3.1 일반 OS (전통적 방식)

**패키지 관리:**

```bash
# 직접 패키지 설치/제거
sudo dnf install nginx
sudo dnf remove nginx

# 시스템 전체가 변경됨
# 롤백 불가능
```

**업데이트:**

- 개별 패키지 단위 업데이트
- 의존성 충돌 가능
- 상태 일관성 보장 어려움

### 3.2 bootc 기반 OS

**Immutable 특성:**

```bash
# OS 파일시스템 읽기 전용
[admin@fedora ~]$ mount | grep ostree
/dev/vda4 on / type xfs (ro,relatime,...)

# /var, /etc는 쓰기 가능
/dev/vda4 on /var type xfs (rw,relatime,...)

```

**패키지 관리:**

```bash
# rpm-ostree로 레이어 기반 관리
sudo rpm-ostree install nginx

# 새 deployment 생성
# 재부팅 필요
# 이전 버전 자동 보존

```

**실제 사용 경험:**

1. **파일시스템 구조:**

```bash
[admin@fedora ~]$ ls -la /
drwxr-xr-x.  ostree/deploy/fedora/deploy/[hash]
lrwxrwxrwx.  /usr -> ostree/...
drwxr-xr-x.  /var
drwxr-xr-x.  /etc

```

1. **부팅 엔트리 관리:**

```bash
[admin@fedora ~]$ rpm-ostree status
State: idle
Deployments:
● fedora:fedora/x86_64/bootc
  Version: 42 (2024-10-06)
  Commit: abc123def456...

```

1. **업그레이드/롤백:**

```bash
# 새 버전으로 업그레이드
sudo bootc upgrade

# 문제 발생 시 이전 버전으로 롤백
sudo bootc rollback

```

**주요 차이점:**

| 특성 | 일반 OS | bootc OS |
| --- | --- | --- |
| 파일시스템 | 읽기/쓰기 | 읽기 전용 (/) |
| 패키지 설치 | dnf/apt | rpm-ostree |
| 업데이트 단위 | 패키지 | OS 이미지 |
| 롤백 | 불가능 | 가능 (자동) |
| 일관성 | 불확실 | 보장됨 |
| 재부팅 | 선택적 | 필수 |

---

## 4. 다른 솔루션 대비 bootc 솔루션의 장점

### 4.1. bootc 솔루션 vs 전통적 VM 이미지 (AMI, qcow2)

**전통적 방식의 문제:**

- Packer 등으로 이미지 빌드 → 복잡한 스크립트
- 버전 관리 어려움
- 이미지 빌드 시간 오래 걸림
- 컨테이너 워크플로우와 단절

**bootc 장점:**

```
Containerfile → Container Image → Bootable OS
      ↓              ↓                ↓
   익숙함        OCI Registry      다양한 포맷

```

- ✅ Dockerfile/Containerfile 문법 활용
- ✅ 컨테이너 레지스트리 활용 (Quay, Docker Hub)
- ✅ 빠른 빌드 (레이어 캐싱)
- ✅ GitOps 워크플로우 자연스럽게 적용

### 4.2 bootc 솔루션 vs Kubernetes + Container

**K8s 방식:**

- 앱만 컨테이너화
- OS는 별도 관리 (Node OS 업데이트)
- 인프라/앱 분리

**bootc 방식:**

- OS 자체가 컨테이너
- 앱 + OS 통합 관리
- 단일 워크플로우

**장점:**

- ✅ OS 업데이트도 GitOps로 관리
- ✅ 앱과 OS 의존성 일치 보장
- ✅ Edge/IoT 등 K8s 불필요한 환경에 적합

### 4.3 bootc 솔루션 vs CoreOS/Flatcar

**유사점:**

- Immutable OS
- 자동 업데이트/롤백

**bootc 차이점:**

- ✅ 표준 OCI 이미지 사용 (lock-in 없음)
- ✅ Fedora/RHEL 생태계 활용
- ✅ rpm-ostree 기반 (기존 RPM 패키지 활용)
- ✅ 더 유연한 커스터마이징

### 4.4 bootc 솔루션 vs Docker/Podman Container 직접 실행

**Container 직접 실행:**

```bash
podman run -d myapp:latest

```

**문제:**

- systemd 관리 복잡
- 여러 서비스 orchestration 어려움
- 부팅 시 자동 시작 설정 복잡

**bootc 방식:**

```bash
# OS 부팅 = 모든 서비스 자동 시작
systemctl enable myapp.service

```

**장점:**

- ✅ systemd 네이티브 통합
- ✅ 전통적인 서버 관리 방식 유지
- ✅ 다중 서비스 관리 용이

### 4.5 종합 비교

| 솔루션 | 용도 | 장점 | 단점 |
| --- | --- | --- | --- |
| **bootc** | Edge, 베어메탈, VM | OCI 표준, GitOps, Immutable | 새로운 패러다임 |
| **Kubernetes** | 클라우드, 마이크로서비스 | 확장성, 자동화 | 복잡도, 리소스 |
| **전통 VM** | 레거시, 범용 | 익숙함, 유연성 | 관리 어려움 |
| **CoreOS** | 컨테이너 호스트 | 자동 업데이트 | 제한적 커스터마이징 |

---

## 5. 보안 개선: Configuration 주입 방법

### 5.1 기존 방식의 문제점

**Containerfile에 평문 비밀번호 하드코딩:**

```docker
RUN echo "root:1004" | chpasswd

```

**문제:**

1. **보안:** 이미지 레이어에 평문 노출

```bash
podman history springboot-bootc
# RUN echo "root:1004" | chpasswd  ← 누구나 볼 수 있음

```

1. **캐싱:** 비밀번호 변경 시 전체 재빌드

```bash
# 비밀번호만 바꿔도...
RUN echo "root:new_password" | chpasswd
# → 이후 모든 레이어 캐시 무효화

```

1. **유연성:** 환경별 다른 설정 불가

```
개발: root:dev_pass
스테이징: root:staging_pass
프로덕션: root:prod_pass
→ 3개 이미지 필요

```

### 5.2 개선된 방식: SSH Key + config.toml

**1. SSH Key 생성 (런타임):**

```bash
ssh-keygen -t rsa -b 4096 -f ~/.ssh/bootc_key -N ""

```

**2. config.toml 작성:**

```toml
[[customizations.user]]
name = "admin"
groups = ["wheel"]
key = "ssh-rsa AAAAB3NzaC1yc2EAAA..."

```

**3. 빌드 시 주입:**

```bash
sudo podman run ... \
  -v $(pwd)/config.toml:/config.toml:ro \
  --config /config.toml \
  quay.io/tkaqhcjstk/springboot-bootc:1.0

```

**장점:**

| 항목 | 하드코딩 | SSH Key |
| --- | --- | --- |
| 보안 | ❌ 평문 노출 | ✅ Private Key만 보호 |
| 캐싱 | ❌ 변경 시 재빌드 | ✅ 이미지 재사용 |
| 유연성 | ❌ 이미지마다 다름 | ✅ 동일 이미지, config만 변경 |
| 감사 | ❌ 어려움 | ✅ Key 관리 가능 |

### 5.3 추가 개선 방안

**1. Secrets Management 통합:**

```bash
# AWS Secrets Manager
aws secretsmanager get-secret-value \
  --secret-id bootc/ssh-key \
  --query SecretString \
  | jq -r .public_key > config.toml

```

**2. Cloud-init 활용:**

```yaml
#cloud-config
users:
  - name: admin
    sudo: ALL=(ALL) NOPASSWD:ALL
    ssh_authorized_keys:
      - ssh-rsa AAAAB3NzaC1yc2EAAA...

```

**3. SSH Certificate Authority:**

```bash
# 단기 인증서 발급
ssh-keygen -s ca_key -I admin@bootc -n admin -V +1d admin_key.pub

```

---

## 6. 실습 환경 및 검증

### 6.1 환경 구성

**Host:** AWS EC2 Ubuntu Server (t3.small, 2GB RAM)
**Guest:** QEMU VM (Fedora bootc OS, 2GB RAM)
**네트워크:** Port forwarding (2222 → 22)

### 6.2 검증 결과

**1. SSH Key 인증 성공:**

```bash
ubuntu@aws$ ssh -i ~/.ssh/bootc_key -p 2222 admin@localhost
[admin@fedora ~]$

```

**2. Java 환경 확인:**

```bash
[admin@fedora ~]$ java -version
openjdk version "21.0.5" 2024-10-15
OpenJDK Runtime Environment (Red_Hat-21.0.5.0.11-1) (build 21.0.5+11)

```

**3. Spring Boot 디렉토리:**

```bash
[admin@fedora ~]$ ls -la /opt/springboot/
drwxr-xr-x. springboot springboot  /opt/springboot

[admin@fedora ~]$ systemctl status springboot
● springboot.service - Spring Boot Application
     Loaded: loaded (/etc/systemd/system/springboot.service; disabled)

```

**4. Immutable 확인:**

```bash
[admin@fedora ~]$ mount | grep " / "
/dev/vda4 on / type xfs (ro,relatime,...)

```

---

## 7. 결론

### 7.1 학습 내용

1. **bootc 워크플로우 이해**
    - Containerfile → OCI Image → Bootable OS
    - bootc-image-builder 활용
2. **보안 개선**
    - SSH Key 기반 인증 구현
    - config.toml을 통한 런타임 주입
    - 이미지와 설정 분리
3. **Immutable OS 특성 체험**
    - 읽기 전용 루트 파일시스템
    - rpm-ostree 기반 관리
    - 롤백 가능한 업데이트

### 7.2 Next Steps

- 3주차: bootc switch/rollback 실습
- 실제 클라우드 환경 배포 (AWS EC2, Azure VM)
- 다중 버전 관리 및 A/B 테스트

---

## 참고 자료

- [bootc Documentation](https://github.com/containers/bootc)
- [bootc-image-builder](https://github.com/osbuild/bootc-image-builder)
- [Fedora bootc](https://docs.fedoraproject.org/en-US/bootc/)
- [rpm-ostree](https://coreos.github.io/rpm-ostree/)
