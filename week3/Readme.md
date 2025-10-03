# 3주차

### 이전 주차까지의 follow-up

`Containerfile`

```docker
FROM quay.io/fedora/fedora-bootc:42

LABEL containers.bootc=1
LABEL description="Nayoung's Custom BootC OS"

RUN mkdir -p /var/roothome

# 필수 패키지만 설치
RUN dnf -y install \
        cloud-init \
        openssh-server \
        vim \
        nginx && \
    dnf clean all 

RUN systemctl enable cloud-init && \
    systemctl enable sshd && \
    systemctl enable nginx

# 부팅 시 init 시작
CMD ["/sbin/init"]
```

podman containerfile bootc 이미지 빌드

```docker
podman build -t immutable-os:latest .
```

```docker
podman tag localhost/immutable-os:latest quay.io/na3150/immutable-os:latest
```

`config.toml`

```bash
[[customizations.user]]
name = "nayoung"  
groups = ["wheel"] 
key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCWqcxXTF8p0hL3stpSndZrj2YgenbqX+rmT3WpEhBJJi54DwDlqTQUmr2yOtQ2NSa2i1bpEzQoqxzUQSGq9QmDy3VbxE/jZ/icDJxuoDwUmJ23Dm8Kng9dU12wc+Znkr2wTh3LpDi+IiW2tn14dyQtuIrBpnPqa3BMd3udiOnETy/l2YL6rU4ol7Dw5HDDPLs57KT7JggkhHp2p9zDuGJLMQuajSb/dIeRoyCmo+g1c17+Pu2oHBc882dK0CmEkgZCIhL0pNDXedeKDSuaGKW125UK68DnNRc8Q8fazT5GqcfAEwfDOZ035+T89pHCm2hcYp3rPdC40kWn70KSKArf"

[customizations]
hostname = "nayoung-bootc"
```

AMI 생성

```bash
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
  quay.io/na3150/immutable-os:latest
```

결과

```bash
 0 B p/sDeleted S3 object immutable-os-ami-bucket:230e8bd4-cfe5-4016-8c9e-1583489f6c04-immutable-os-ami
AMI registered: ami-08bd552f7ae87d609
Snapshot ID: snap-0833dd5255539b756
10.00 GiB / 10.00 GiB [----------------------------------------------------------------------------------------------] 100.00% 13.28 MiB p/s
```

S3 업로드 확인

![image.png](https://github.com/user-attachments/assets/7f030e4e-01c3-4bfa-a6c0-eadb3e790417)

AMI 생성 확인

![스크린샷 2025-10-03 오후 7.28.11.png](https://github.com/user-attachments/assets/ec2e2e77-18b3-4add-8050-b0456dd479f6)

AWS EC2 부팅

![image.png](https://github.com/user-attachments/assets/6393441d-6f67-4af4-a039-681c097ea8aa)

nayoung으로 접속

```bash
ssh -i "../immutable-os-keypair.pem" **nayoung**@ec2-43-203-240-243.ap-northeast-2.compute.amazonaws.com
```

---

### Week3

[3주차 오프라인 이후 숙제]

아래 과제를 README.md로 만들어 마찬가지로 클클 깃 리포 브랜치에 커밋으로 넣어주시면 감사하겠습니다

1. bootc 기반 OS에서 패키지 설치와 일반 OS 패키지 설치가 무엇인 다를까요?
2. bootc 기반 OS 내부에서 패키지를 설치해보세요 (롤백/업그레이드). 어떻게 되었나요?
3. 빌드해본 bootc container를 두 개 버전으로 구성해서 OCI registry public repo에 다른 태그(A, B)로 올려보세요. A 태그 컨테이너를 OS로 만들어서 부팅 후, B 태그 컨테이너를 A 컨테이너 기반 OS에서 가져와서 바로 B 컨테이너 기반 OS로 변경해보세요. (bootc switch)
4. 3번 과정을 롤백해보세요 (bootc rollback)

## 🌳 BootC 기반 OS에서 패키지 설치와 OS 패키지 설치가 무엇이 다를까?

### 1. **패키지 설치** (일반 OS)

> 전통적인 방식
> 

```bash
*# 런타임에 패키지 설치*
ssh into-server
sudo dnf install nginx
```

- ✅ 즉시 설치 가능
- ❌ 서버마다 상태가 달라질 수 있음
- ❌ "누가 언제 뭘 설치했지?" 추적 어려움

### 2. **OS 패키지 설치** (BootC)

> 컨테이너 이미지 방식
> 

```bash
*# Containerfile에서 선언*
RUN dnf install nginx
```

- ✅ 이미지에 포함되어 불변(immutable)
- ✅ 모든 서버가 동일한 상태
- ✅ Git으로 **버전 관리 가능**
    
    ## 📊 버전 관리 비교
    
    | 기능 | VM Snapshot | BootC |
    | --- | --- | --- |
    | Diff 확인 | ❌ 불가능 (바이너리) | ✅ `git diff` |
    | 변경 이유 | ❌ 알 수 없음 | ✅ commit message |
    | 변경자 | ❌ 추적 어려움 | ✅ `git blame` |
    | 코드 리뷰 | ❌ 불가능 | ✅ Pull Request |
    | 롤백 | AMI ID 찾아서 | `git revert` |
    | 브랜치 | ❌ 없음 | ✅ dev/staging/prod |
    | 태그 | AMI 이름으로만 | ✅ v1.2.3 시맨틱 버전 |
- ✅ 완벽하게 재현 가능

| 구분 | 전통적 패키지 설치 | BootC OS 패키지 설치 |
| --- | --- | --- |
| **설치 시점** | 런타임 (서버 접속 후) | 빌드 타임 (이미지 생성 시) |
| **설치 장소** | 각 서버에서 개별 설치 | Containerfile에 선언 |
| **일관성** | 서버마다 다를 수 있음 | 모든 서버 동일 보장 |
| **변경 방법** | `dnf install` | 이미지 재빌드 |
| **롤백** | 어려움 | 이전 이미지로 쉽게 롤백 |
| **추적성** | 로그 확인 필요 | Dockerfile 보면 끝 |

## 🌳 BootC 기반 OS 내부에서 패키지를 설치해보세요 (롤백/업그레이드).  어떻게 되었나요?

`htop` 설치 시도했으나 실패했다.

```bash
[nayoung@ip-172-31-13-197 ~]$ sudo dnf install htop
.... 

Error: t**his bootc system is configured to be read-only.** For more information, run `bootc --help`.
```

<aside>
💡

BootC는 읽기 전용 시스템(변경사항은 **이미지 빌드 시에만** 가능)이기 때문에, 런타임에 패키지 설치가 불가능하다.

</aside>

`rpm-ostree` 를 사용하면 설치가 가능하다.

```bash
sudo rpm-ostree install htop
```

> `rpm-ostree` 란 전통적인 패키지 관리자(dnf/yum)와 달리, **OS 전체를 하나의 이미지처럼** 관리하는 시스템 
⇒ OS 전체 스냅샷을 버전 관리
> 

`rpm-ostree status` 로 상태를 보면, `LayeredPackages: htop` 를 확인할 수 있다.

```bash
[nayoung@ip-172-31-13-197 ~]$ rpm-ostree status
State: idle
Deployments:
  ostree-unverified-registry:quay.io/na3150/immutable-os:latest
                   Digest: sha256:1ee2d77aedea97beb8610d03f5898cc00de064dea800bf66b721edff478c9616
                  Version: 42.20250912.0 (2025-10-03T09:46:41Z)
                     Diff: 2 added
          LayeredPackages: **htop**

● ostree-unverified-registry:quay.io/na3150/immutable-os:latest
                   Digest: sha256:1ee2d77aedea97beb8610d03f5898cc00de064dea800bf66b721edff478c9616
                  Version: 42.20250912.0 (2025-10-03T09:46:41Z)
```

`rpm-ostree` 를 사용하면, 즉시 적용은 안되며 재부팅해야 한다.

```bash
sudo systemctl reboot
```

재접속 후, `htop` 명령어 사용이 가능했다.

```bash
htop
```

이제 다시, `htop` 가 설치되기 전의 버전으로 rollback 해보자.

```bash
sudo rpm-ostree rollback
```

```bash
Moving '40390c6f9365c67f3c0b6f5fadb771b194e430b6174130c036731b9e4481cf86.0' to be first deployment
Transaction complete; bootconfig swap: no; bootversion: boot.0.0, deployment count change: 0
Removed:
  htop-3.4.1-1.fc42.aarch64
  hwloc-libs-2.12.0-1.fc42.aarch64
Changes queued for next boot. Run "systemctl reboot" to start a reboot
```

rollback 및 reboot 후, `htop` 명령어 사용이 불가능했다!

```bash
$ htop
bash: htop: command not found
```

<aside>
💡

BootC는 읽기 전용 시스템이라 런타임 설치 `dnf install`은 불가능했고, `rpm-ostree install` + 재부팅으로만 패키지 설치/롤백이 가능했다.

</aside>

## 🌳 빌드해본 BootC Container를 2개의 버전으로 구성해서 OCI Registry Public Repo에 다른 태그(A, B)로 올려보세요. A 태그 컨테이너를 OS로 만들어서 부팅 후, B 태그 컨테이너를 A 컨테이너 기반 OS에서 가져와서 바로 B 컨테이너 기반 OS로 변경해보세요 (BootC Switch)

A버전은 기존의 이미지를 사용하고, `htop` 를 추가한 2번째 이미지를 생성했다.

```bash
podman build -t immutable-os:htop -f Containerfile.B
podman tag localhost/immutable-os:htop quay.io/na3150/immutable-os:htop
podman push quay.io/na3150/immutable-os:htop
```

현재(A버전) bootc 상태 확인

```bash
$ sudo bootc status
[sudo] password for nayoung: 
● Booted image: quay.io/na3150/immutable-os:latest
        Digest: sha256:1ee2d77aedea97beb8610d03f5898cc00de064dea800bf66b721edff478c9616 (arm64)
       Version: 42.20250912.0 (2025-10-03T09:46:41Z)

  Rollback ostree
           Commit: 0babc7a7bfd41a1dbfcad37f210911c1b020cd5a92927bec6994c8f0db1d010
```

버전 B로 switch

```bash
$ sudo bootc switch quay.io/na3150/immutable-os:htop
layers already present: 66; layers needed: 2 (50.2 MB)
Fetched layers: 47.86 MiB in 25 seconds (1.88 MiB/s)                                                                                  Deploying: done (8 seconds)                                                                                                       Queued for next boot: quay.io/na3150/immutable-os:htop
  Version: 42.20250912.0
  Digest: sha256:fe233335993dafc0f9d476fc363b929097a02020fa3a600d9e00d46ba3d0314b
```

status 확인 (staged 상태)

```bash
$ sudo bootc status
  **Staged image: quay.io/na3150/immutable-os:htop**
        Digest: sha256:fe233335993dafc0f9d476fc363b929097a02020fa3a600d9e00d46ba3d0314b (arm64)
       Version: 42.20250912.0 (2025-10-03T11:46:25Z)

● Booted image: quay.io/na3150/immutable-os:latest
        Digest: sha256:1ee2d77aedea97beb8610d03f5898cc00de064dea800bf66b721edff478c9616 (arm64)
       Version: 42.20250912.0 (2025-10-03T09:46:41Z)

  Rollback ostree
           Commit: 0babc7a7bfd41a1dbfcad37f210911c1b020cd5a92927bec6994c8f0db1d010c
```

재부팅 후 접속

```bash
sudo systemctl reboot
```

Booted Image가 B버전인 것으로 확인 가능하고, `htop`  명령어 사용도 가능했다.

```bash
$ sudo bootc status
[sudo] password for nayoung: 
● **Booted image: quay.io/na3150/immutable-os:htop**
        Digest: sha256:fe233335993dafc0f9d476fc363b929097a02020fa3a600d9e00d46ba3d0314b (arm64)
       Version: 42.20250912.0 (2025-10-03T11:46:25Z)

  Rollback image: quay.io/na3150/immutable-os:latest
          Digest: sha256:1ee2d77aedea97beb8610d03f5898cc00de064dea800bf66b721edff478c9616 (arm64)
         Version: 42.20250912.0 (2025-10-03T09:46:41Z)
```

## 🌳 3번 과정을 롤백해보세요.

rollback 명령을 실행하면, 다음 부팅 시 롤백되는 것으로 예약된다.

```bash
$ sudo bootc rollback
Next boot: rollback deployment
```

다시 접속하면, 이전 버전(A 버전)으로 롤백된 것을 확인할 수 있다. 

`htop` 명령어 사용도 불가능했다.

```bash
$ sudo bootc status
[sudo] password for nayoung: 
**● Booted image: quay.io/na3150/immutable-os:latest**
        Digest: sha256:1ee2d77aedea97beb8610d03f5898cc00de064dea800bf66b721edff478c9616 (arm64)
       Version: 42.20250912.0 (2025-10-03T09:46:41Z)

  Rollback image: quay.io/na3150/immutable-os:htop
          Digest: sha256:fe233335993dafc0f9d476fc363b929097a02020fa3a600d9e00d46ba3d0314b (arm64)
         Version: 42.20250912.0 (2025-10-03T11:46:25Z)
```