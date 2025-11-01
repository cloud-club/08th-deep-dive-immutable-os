## 1. 패키지 설치: bootc 기반 OS vs 일반 OS
---
**일반 OS**
- `dnf install` 명령 입력으로 바로 패키지 설치 가능하고, 루트 파일시스템에 적용됨

**bootc 기반**
- 루트 파일시스템이 불변 상태라서 `dnf install`을 직접 실행해도 파일시스템에 쓸 수 없으니 설치가 안됨
- rpm ostree를 통해 설치가 가능한데, 이때 dnf나 yum처럼 패키지를 바로 설치하는 게 아니라,
- 기존 os 스냅샷을 바탕으로 선택된 RPM 패키지들을 반영한 rootfs를 만들어
- 이를 새로운 OSTree 커밋으로 저장한 뒤 부팅 시 선택 가능하게 해줌
    
    
## 2. bootc 기반 OS 내부 패키지 설치 결과
---

- `dnf install` → 권한 문제로 안됨
  ``` bash
  Error: this bootc system is configured to be read-only. For more information, run `bootc --help`.
  ```    
- `rpm-ostree intall` → 설치 명령은 동작하지만, 즉시 적용은 안되고 재부팅 필요

  ``` bash
  
  sudo rpm-ostree install tree
  rpm-ostree status
  sudo reboot
  ```            
    
## 3. bootc switch 수행
---

### 1. 이미지 A, B 준비 & 레지스트리 push
  ``` bash 
  # A: 기본 버전 
  podman tag localhost/sy-bootc-httpd:latest quay.io/7910trio/sy-bootc-httpd:base
  podman push quay.io/7910trio/sy-bootc-httpd:base

  # B: tcpdump 추가 버전
  podman tag localhost/sy-bootc-httpd:latest quay.io/7910trio/sy-bootc-httpd:tcpdump
  podman push quay.io/7910trio/sy-bootc-httpd:tcpdump
  ```
### 2. A로 만든 AMI로 EC2 서버 띄움
### 3. B 태그로 전환
  ``` bash
  sudo bootc switch quay.io/7910trio/sy-bootc-httpd:tcpdump 
  ```
  
**switch 명령어 흐름 정리**

a. 이미지 다운로드
- 지정한 OCI 레지스트리 이미지를 pull함
- 컨테이너 이미지 안의 rootfs 내용을 ostree 레이어로 변환할 준비를 함

b. ostree commit 생성
- pull받은 컨테이너 이미지 내부의 파일시스템을 ostree 레이어로 적용하여 새로운 커밋을 생성

c. 다음 부팅 예약
- bootloader 설정을 바꾸어 새 커밋이 다음 부팅 시 사용되도록 표시
- 현재 os에 바로 적용되지는 않음 -> 재부팅 시 bootloader가 새 커밋으로 부팅

### 4. 재부팅 후 B 버전 확인
``` bash
sudo reboot

# 확인
[fedora@ip-172-31-32-103 ~]$ rpm-ostree status
State: idle
Deployments:
● ostree-unverified-registry:quay.io/7910trio/sy-bootc-httpd:tcpdump
                   Digest: sha256:660309363c68124f9913b8b4c25fc899cedf94eaa8f3239e3d89ed45820b1632
                  Version: 42.20250930.0 (2025-10-03T00:26:25Z)

  ostree-unverified-registry:quay.io/7910trio/sy-bootc-httpd:latest
                   Digest: sha256:e6b268a4b4b7c90d2145b5b72a9b01af72691be2250be13da38e49aeb73d81c6
                  Version: 42.20250917.0 (2025-09-17T16:45:10Z)
          LayeredPackages: tree
```
- A에서 B 이미지로 switch하기 전 설치한 tree 사용 불가 (설치 안된 상태)

### 5. 롤백
``` bash
sudo rpm-ostree rollback
sudo reboot
```
- 다시 tree 사용 가능