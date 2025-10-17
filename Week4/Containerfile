ARG BASE=quay.io/fedora/fedora-bootc:42

# 베이스 이미지 선택.
FROM ${BASE}

# "부팅 가능한 컨테이너" 라는 표시
LABEL containers.bootc=1

# root 계정 홈을 /var/roothome으로 변경
RUN mkdir -p /var/roothome

# nginx 설치 및 부팅 시 자동 실행 설정
RUN dnf install -y nginx && \
    systemctl enable nginx && \
    dnf clean all && \
    # nginx 실행에 필요한 디렉토리 생성
    mkdir -p /var/log/nginx /var/lib/nginx/tmp /var/cache/nginx && \
    chown -R nginx:nginx /var/log/nginx /var/lib/nginx /var/cache/nginx
