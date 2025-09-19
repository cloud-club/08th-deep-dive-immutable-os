FROM quay.io/fedora/fedora-bootc:42
LABEL containers.bootc="1"

ARG GIT_COMMIT_HASH
LABEL org.opencontainers.image.revision=${GIT_COMMIT_HASH}

RUN mkdir -p /var/roothome && \
    dnf -y install cloud-init httpd openssh-server vim && \
    dnf clean all 

RUN systemctl enable httpd \
    && systemctl enable cloud-init \
    && systemctl enable sshd

COPY index.html /var/www/html/index.html

CMD ["/sbin/init"]

