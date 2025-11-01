# 클라우드 클럽 8기 스터디 - deep-dive-immutable-OS

## Introduction

> [!IMPORTANT]
> 본 스터디는 진윤태/박천수의 [YOB: Your own OS using bootc](https://github.com/yureutaejin/yob) Repository를 베이스로 진행됩니다.

> [!NOTE]
> 멤버별 작업 내용 요약 브랜치
>
> - [이서영](https://github.com/cloud-club/08th-deep-dive-immutable-os/tree/SeoyoungLee)
> - [장욱](https://github.com/cloud-club/08th-deep-dive-immutable-os/tree/UkJang)
> - [손빈](https://github.com/cloud-club/08th-deep-dive-immutable-os/tree/been)
> - [성나영](https://github.com/cloud-club/08th-deep-dive-immutable-os/tree/nayoung)
> - [문영호](https://github.com/cloud-club/08th-deep-dive-immutable-os/tree/youngho)
> - [정현주](https://github.com/cloud-club/08th-deep-dive-immutable-os/tree/hyeonju)

### bootc?

> [!NOTE]
>
> 7기 [init-os-image 스터디](https://github.com/cloud-club/init-os-image)에 이어 8기에서는 [bootc](https://github.com/bootc-dev/bootc), [libostree](https://ostreedev.github.io/ostree/), [ComposeFS](https://github.com/composefs/composefs) 등의 원리를 더 깊이 파고들어, 엔터프라이즈 환경에 도입을 시도할 수 있는 정도의 역량을 키우는게 목표입니다.

> [!TIP]
> CNCF에서나 Sandbox지, RedHat과 Fedora에서는 atomic/container optimized OS에 대해 bootc 전환을 확정지었습니다.
> ([TalOS](https://www.talos.dev/)나 [AWS Bottlerocket OS](https://tech.inflab.com/20250421-bottlerocket-volume-image-cache/#bottlerocket-os) 등 K8s Cluster에서 쓰이는 타사/진영 Container Optimized OS가 뜨고 있고, RedHet은 이에 대해 bootc/rpm-ostree 기반 CoreOS를 내세우고 있습니다. 실제 OpenShift 환경에서는 CoreOS가 쓰입니다.)

![bootc container](https://developers.redhat.com/sites/default/files/styles/article_floated/public/image1_62.png.webp?itok=c0vYglLs)

- 어렵게 생각할 것 없이, docker로 custom OS 만드는 기술이라고 생각하고 접근하면 될 것 같습니다.
- Linux Container(Docker, Podman…) 기술로 OS를 개발하는 기술 (bootable container라는 특수한 container → OS)
- OCI spec을 만족하기 때문에 OCI Registry(Docker Hub, ECR, Artifact Registry, quay)에 layer 형태로 저장이 가능.
- OSTree 기반 Atomic update, rootfs readonly, OCI 이미지 기반 단일 커밋 단위 관리 등으로 불변성(immutability)이 보장되고 Reliability, Security, Maintainability, Predictability에 큰 이점을 가집니다

### 🕑 Schedule

- **기간**: 2025.09 ~ 2025.10
- **시간**: 매주 토요일 오전 10:00 ~ 13:00
- **장소**: 온라인 /오프라인 (삼각지 공익활동 공간)

### Who need this study?

- 커스텀 Linux OS를 만들어보고 싶은 사람
  - 온프레미스, 홈랩, AMI 등
- Private OS 구성 및 배포 자주하는데 지치고 화가난 사람
  - Packer/Ansible 등
- 회사/취직과 별개로 새로운 기술에 대해 열려있는 사람
- 회사가 아닌, 본인의 생각을 말할 수 있는 사람
- 책으로 지루하게 리눅스 시스템을 공부하는 것이 아닌, 실습을 하며 시스템을 공부하고 싶은 사람.
- 토의/토론 등에 참여가 가능하신 분

## 👽 Our Squad

<table>
  <tr>
    <td align="center"><a href="https://github.com/yureutaejin"><img src="https://avatars.githubusercontent.com/u/85734054?v=4" width="100px;" alt=""/><br /><sub><b>
진윤태</b></sub></a><br /></td>
    <td align="center"><a href="https://github.com/charlie3965"><img src="https://avatars.githubusercontent.com/u/19777578?v=4" width="100px;" alt=""/><br /><sub><b>
박천수</b></sub></a><br /></td>
    <td align="center"><a href="https://github.com/ansdudgh98"><img src="https://avatars.githubusercontent.com/u/52616389?v=4" width="100px;" alt=""/><br /><sub><b>
문영호</b></sub></a><br /></td>
    <td align="center"><a href="https://github.com/7910trio"><img src="https://avatars.githubusercontent.com/u/189601225?v=4" width="100px;" alt=""/><br /><sub><b>이서영</b></sub></a><br /></td>
  </tr>
  <tr>
    <td align="center"><a href="https://github.com/Uk-jake"><img src="https://avatars.githubusercontent.com/u/100981076?v=4" width="100px;" alt=""/><br /><sub><b>
장욱</b></sub></a><br /></td>
    <td align="center"><a href="https://github.com/beengineer500"><img src="https://avatars.githubusercontent.com/u/99883918?v=4" width="100px;" alt=""/><br /><sub><b>
손빈</b></sub></a><br /></td>
    <td align="center"><a href="https://github.com/hyeonju9705"><img src="https://avatars.githubusercontent.com/u/48791736?v=4" width="100px;" alt=""/><br /><sub><b>
정현주</b></sub></a><br /></td>
    <td align="center"><a href="https://github.com/na3150"><img src="https://avatars.githubusercontent.com/u/64996121?v=4" width="100px;" alt=""/><br /><sub><b>
성나영</b></sub></a><br /></td>
  </tr>
</table>

## 스터디 방식

오프라인 주차: 스터디 리더 (진윤태, 박천수)가 사전에 먼저 공부하고, 오프라인에서 구성원들에게 전파하는 방식으로 진행합니다.

1. 문제(리더가 제시)에 대해 자신의 생각을 근거와 함께 정리해옴
2. 해당 문제에 대해서 오프라인에서 다 같이 토의
3. 기술의 필요성(타당성)을 이해하고 오프라인에서 실습 진행.

온라인 주차: 과제 구현 및 발표

1. 리더가 과제를 제시합니다. ( ex. 컨테이너 이미지 → OS 이미지 전환을 수행하는 GitHub Actions를 개발해오세요)
2. 각자 구현
3. 온라인 주차에 해당 리포에 브랜치 만들고 진행 내용 요약한 마크다운 커밋
4. 발표

## Reference

- [bootc docs](https://bootc-dev.github.io/bootc/)
- [멀티 클라우드 환경에 호환가능한 클라우드 이미지 개발](https://www.youtube.com/watch?v=OxG_OfOH5h8)

## Misc

> [!WARNING]
>
> **출석 규정**
>
> 3회 이상 불참 시 7기를 수료할 수 없습니다.  
> 각 스터디 모임에 참여하지 못할 경우, 사전에 Slack으로 사유를 작성해주세요.
