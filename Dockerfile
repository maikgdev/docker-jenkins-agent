ARG FROM_TAG=4.9-1-alpine

FROM jenkins/inbound-agent:${FROM_TAG}

ARG GOSU_VERSION=1.13
ARG DOCKER_CHANNEL=stable
ARG DOCKER_VERSION=19.03.15
ARG TINY_VERSION=0.19.0

USER root

RUN \
    # alpine only glibc
    if [ -f /etc/alpine-release ] ; then \
        echo "Alpine" ; \
    elif [ -f /etc/debian_version ] ; then \
        echo "Debian, setting locales" \
        && apt-get update \
        && apt-get install -y --no-install-recommends locales \
        && localedef  -i en_US -f UTF-8 en_US.UTF-8 \
        && rm -rf /var/lib/apt/lists/* \
        ; \
    fi

ENV LANG=en_US.UTF-8

RUN \
    echo "Installing required packages" \
    ; \
    if [ -f /etc/alpine-release ] ; then \
        apk add --no-cache curl shadow iptables \
        ; \
    elif [ -f /etc/debian_version ] ; then \
        apt-get update \
        && apt-get install -y --no-install-recommends curl iptables \
        && rm -rf /var/lib/apt/lists/* \
        ; \
    fi


RUN \
    echo "Installing tiny and gosu" \
    ; \
    curl -SsLo /usr/bin/gosu https://github.com/tianon/gosu/releases/download/${GOSU_VERSION}/gosu-amd64 \
    && chmod +x /usr/bin/gosu \
    && curl -SsLo /usr/bin/tiny https://github.com/krallin/tini/releases/download/v${TINY_VERSION}/tini-amd64 \
    && chmod +x /usr/bin/tiny


RUN \
    echo "Installing docker" \
    ; \
    curl -Ssl "https://download.docker.com/linux/static/${DOCKER_CHANNEL}/x86_64/docker-${DOCKER_VERSION}.tgz" | \
    tar -xz  --strip-components 1 --directory /usr/bin/

RUN \
    echo "Installing docker-compose" \
    ; \
    export CRYPTOGRAPHY_DONT_BUILD_RUST=1; \
    if [ -f /etc/alpine-release ] ; then \
        apk add --no-cache python3 py3-pip \
        \
        && apk add --no-cache --virtual .build-deps \
            python3-dev libffi-dev openssl-dev gcc libc-dev make \
        && pip3 install --upgrade --no-cache-dir pip wheel \
        && pip3 install --upgrade --no-cache-dir docker-compose \
        && apk del .build-deps \
        ; \
    elif [ -f /etc/debian_version ] ; then \
        buildDeps="python3-dev libffi-dev gcc make" \
        && apt-get update \
        && apt-get install -y --no-install-recommends python3 python3-pip python3-setuptools \
        \
        && apt-get install -y --no-install-recommends $buildDeps \
        && pip3 install --upgrade --no-cache-dir pip wheel \
        && pip3 install --upgrade --no-cache-dir docker-compose \
        && apt-get purge -y --auto-remove \
                  -o APT::AutoRemove::RecommendsImportant=false \
                  $buildDeps \
        && rm -rf /var/lib/apt/lists/* \
        ; \
    fi

COPY entrypoint.sh /entrypoint.sh

COPY modprobe.sh /usr/local/bin/modprobe

COPY wrapdocker.sh /usr/local/bin/wrapdocker

VOLUME /var/lib/docker

ENTRYPOINT [ "tiny", "--", "/entrypoint.sh" ]
