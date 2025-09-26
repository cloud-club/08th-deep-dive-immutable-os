FROM quay.io/fedora/fedora-bootc:42


LABEL containers.bootc=1

RUN mkdir -p -m 0700 /var/roothome 

RUN echo "hoy" > /etc/hostname

RUN dnf install -y nvim vim curl 

RUN set -xeuo pipefail && \
    dnf -y downgrade kernel && \
    dnf clean all && \
    bootc container lint


RUN bootc container lint