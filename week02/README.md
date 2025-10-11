## bootc 기반 OS 구축 흐름
### 1. bootc 기반 컨테이너 이미지 빌드
- 베이스 이미지 pull
``` bash
# podman 설치
sudo apt update
sudo apt install podman

podman pull quay.io/fedora/fedora-bootc:42
```

- `Containerfile` 작성
``` yaml 
# 기존 bootc 이미지 기반
FROM quay.io/fedora/fedora-bootc:42
LABEL containers.bootc="1"

ARG GIT_COMMIT_HASH
LABEL org.opencontainers.image.revision=${GIT_COMMIT_HASH}

# 패키지 설치
RUN mkdir -p /var/roothome && \
	dnf -y install cloud-init httpd openssh-server vim && \
    dnf clean all 
    
# systemd 서비스 활성화
RUN systemctl enable httpd \
    && systemctl enable cloud-init \
    && systemctl enable sshd

# 사용자 HTML 복사
COPY index.html /var/www/html/index.html

# 부팅 시 init 시작
CMD ["/sbin/init"]

```
- 웹 서버 커스터마이징을 위해 같은 위치에 `index.html` 생성
``` bash
echo "<h1>Hello BootC</h1>" > index.html
```
- 빌드
``` bash
nano Containerfile

podman build -t sy-bootc-httpd:latest .
```

### 2. quay 레지스트리 push
``` bash
podman tag localhost/sy-bootc-httpd:latest quay.io/7910trio/sy-bootc-httpd:latest

podman login 

podman push quay.io/7910trio/sy-bootc-httpd:latest
```

### 3. AWS 작업 수행
- S3 버킷 생성
- [AWS 공식 문서 : Required permissions for VM Import/Export](https://docs.aws.amazon.com/vm-import/latest/userguide/required-permissions.html)를 참고하여 AMI를 생성하는 데 필요한 IAM 역할 생성

### 4. bootc-image-builder로 디스크 이미지 생성
``` bash
# quay
sudo podman pull quay.io/7910trio/sy-bootc-httpd:latest
  
sudo podman run \
  --rm \
  -it \
  --privileged \
  --pull=newer \
  --security-opt label=type:unconfined_t \
  -v $HOME/.aws:/root/.aws:ro \
  -v /var/lib/containers/storage:/var/lib/containers/storage \
  --env AWS_PROFILE=default \
  quay.io/centos-bootc/bootc-image-builder:latest \
  --type ami \
  --aws-ami-name sy-bootc-httpd-ami \
  --aws-bucket sy-bootc-import-bucket \ # 위에서 생성한 S3 버킷 이름
  --aws-region ap-northeast-2 \ 
  --rootfs btrfs \
  quay.io/7910trio/sy-bootc-httpd:latest
  
```
1. 



