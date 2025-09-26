# 최소 구성: SSH(key-only), root 잠금, dev 계정
ARG BASE=quay.io/fedora/fedora-bootc:42
FROM ${BASE}

# bootc용 메타(부팅 가능한 컨테이너임을 표시)
LABEL containers.bootc=1

# SSH 서버만 설치하고 부팅 시 활성화
RUN dnf -y install openssh-server && \
    systemctl enable sshd && \
    dnf clean all && rm -rf /var/cache/libdnf5

# root 비밀번호 로그인 잠금
RUN passwd -l root

# dev 계정 생성 (+ sudo 무비번; 필요 없으면 아래 2줄 삭제 가능)
ARG DEV_USER=dev
RUN useradd -m -d /var/home/${DEV_USER} -s /bin/bash ${DEV_USER} && \
    echo "${DEV_USER} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/99-${DEV_USER} && \
    chmod 0440 /etc/sudoers.d/99-${DEV_USER}

# 빌드 시 공개키를 주입 (빌드할 때 ARG로 전달)
#   podman build --build-arg DEV_AUTHKEY="$(cat ~/.ssh/id_ed25519.pub)" -t my-fedora-bootc:dev .
ARG DEV_AUTHKEY
RUN install -d -m 700 -o ${DEV_USER} -g ${DEV_USER} /var/home/${DEV_USER}/.ssh && \
    if [ -n "$DEV_AUTHKEY" ]; then \
      printf '%s\n' "$DEV_AUTHKEY" > /var/home/${DEV_USER}/.ssh/authorized_keys && \
      chown ${DEV_USER}:${DEV_USER} /var/home/${DEV_USER}/.ssh/authorized_keys && \
      chmod 600 /var/home/${DEV_USER}/.ssh/authorized_keys ; \
    fi

# sshd 설정: 비밀번호 로그인 차단 + root 접속 차단
RUN sed -ri 's/^#?PasswordAuthentication .*/PasswordAuthentication no/' /etc/ssh/sshd_config && \
    sed -ri 's/^#?PermitRootLogin .*/PermitRootLogin no/' /etc/ssh/sshd_config && \
    sed -ri 's/^#?ChallengeResponseAuthentication .*/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config && \
    sed -ri 's/^#?UsePAM .*/UsePAM yes/' /etc/ssh/sshd_config && \
    sed -ri 's/^#?UseDNS .*/UseDNS no/' /etc/ssh/sshd_config
  
# 배너 등 설정 파일 주입
COPY motd /etc/motd

# (선택) 이미지 메타데이터
LABEL org.opencontainers.image.title="my-fedora-bootc"
LABEL org.opencontainers.image.version="0.1"
LABEL org.opencontainers.image.description="Immutable OS built with bootc (minimal)"
