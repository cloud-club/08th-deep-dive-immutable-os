### Fedora 접속해보기

```bash
podman run -itd --rm --name test quay.io/fedora/fedora-bootc:42 /bin/bash
podman exec -it test /bin/bash
```

## Containerfile

```docker
ROM quay.io/fedora/fedora-bootc:42

# bootc 호환 이미지임을 명시
LABEL containers.bootc 1

# 추가 메타데이터 (선택사항)
LABEL version="1.0"
LABEL description="Nayoung's first custom bootc OS"

# 다음과 같이 반드시 이 구분이 무조건 들어가야 한다.
# fedora의 특정 -> google fedora root home
RUN mkdir -p /var/roothome

RUN dnf install -y vim && dnf clean all
RUN bootc container lint                       
```

### BootC Image 빌드하기 및 quay push
```bash
podman build -t nayoung-bootc-fedora-vim .
```

```bash
podman tag  nayoung-bootc-fedora-vim quay.io/na3150/immutable-os:v1.0
podman tag  quay.io/na3150/immutable-os:v1.0 quay.io/na3150/immutable-os
podman push quay.io/na3150/immutable-os:v1.0
```

```bash
$ podman images
REPOSITORY                   TAG         IMAGE ID      CREATED         SIZE
quay.io/na3150/immutable-os  v1.0        029db7dc3fdc  37 minutes ago  1.97 GB
quay.io/fedora/fedora-bootc  42          f48e6f138ea0  18 hours ago    1.89 GB
```

### AMI 만들기
```bash
podman --connection podman-machine-default-root pull quay.io/na3150/immutable-os
```

```bash
podman --connection podman-machine-default-root run --rm -it --privileged \
  -v /var/lib/containers/storage:/var/lib/containers/storage \
  -v ~/bootc-output:/output \
  quay.io/centos-bootc/bootc-image-builder:latest \
  --type ami \
  --rootfs ext4 \
  --output /output \
  quay.io/na3150/immutable-os
```

```bash
[\] Disk image building step
[4 / 4] Pipeline image [---------------------------------------------------------------------------------------------------->] 100.00%
[12 / 12] Stage org.osbuild.selinux [--------------------------------------------------------------------------------------->] 100.00%
Message: Results saved in /output
```
`disk.raw` 파일 생성

```bash
$ ls -la ~/bootc-output/
total 40
drwxr-xr-x@  4 nayoung  staff    128 Sep 20 00:59 .
drwxr-x---+ 82 nayoung  staff   2624 Sep 20 01:01 ..
drwxr-xr-x   3 nayoung  staff     96 Sep 20 00:57 image
-rw-r--r--   1 nayoung  staff  18721 Sep 20 00:56 manifest-ami.json
find ~/bootc-output/ -name "*.img" -o -name "*.raw" -o -name "*.ami"
/Users/nayoung/bootc-output/image/disk.raw
```

### S3 버킷 생성
```bash
aws s3 mb s3://immutable-os-ami-bucket
```

```bash
aws s3 cp ~/bootc-output/image/disk.raw s3://immutable-os-ami-bucket/immutable-os.raw
```

### AMI 이미지 생성
```bash
aws ec2 import-image \
  --description "Immutable OS bootc AMI" \
  --architecture x86_64 \
  --platform Linux \
  --disk-containers Format=RAW,UserBucket='{S3Bucket=immutable-os-ami-bucket,S3Key=immutable-os.raw}'
```
이미지 생성 결과
```bash
$ aws ec2 describe-import-image-tasks --import-task-ids import-ami-d1974645895f0b04t
{
    "ImportImageTasks": [
        {
            "Description": "Immutable OS bootc AMI",
            "ImageId": "",
            "ImportTaskId": "import-ami-d1974645895f0b04t",
            "SnapshotDetails": [
                {
                    "DiskImageSize": 10737418240.0,
                    "Format": "RAW",
                    "Status": "completed",
                    "UserBucket": {
                        "S3Bucket": "immutable-os-ami-bucket",
                        "S3Key": "immutable-os.raw"
                    }
                }
            ],
            "Status": "deleted",
            "StatusMessage": "CLIENT_ERROR : ClientError: Unknown OS / Missing OS files.",
            "Tags": []
        }
    ]
}
```

