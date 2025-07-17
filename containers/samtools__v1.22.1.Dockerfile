# Copyright (C) 2025 Roberto Rossini <roberros@uio.no>
#
# SPDX-License-Identifier: MIT

FROM alpine:3.22 AS builder

ARG CONTAINER_VERSION
ARG SAMTOOLS_VER=${CONTAINER_VERSION}
ARG HTSLIB_VER=${SAMTOOLS_VER}

ARG HTSLIB_URL="https://github.com/samtools/htslib/releases/download/$HTSLIB_VER/htslib-$HTSLIB_VER.tar.bz2"
ARG HTSLIB_CHECKSUM="3dfa6eeb71db719907fe3ef7c72cb2ec9965b20b58036547c858c89b58c342f7  htslib-$HTSLIB_VER.tar.bz2"

ARG SAMTOOLS_URL="https://github.com/samtools/samtools/releases/download/$SAMTOOLS_VER/samtools-$SAMTOOLS_VER.tar.bz2"
ARG SAMTOOLS_CHECKSUM="02aa5cd0ba52e06c2080054e059d7d77a885dfe9717c31cd89dfe7a4047eda0e  samtools-$SAMTOOLS_VER.tar.bz2"

RUN if [ -z "$CONTAINER_VERSION" ]; then echo "Missing CONTAINER_VERSION --build-arg" && exit 1; fi


RUN apk add --no-cache \
    autoconf \
    bash \
    bzip2-dev \
    clang \
    curl \
    libdeflate-dev \
    make \
    ncurses-dev \
    perl \
    perl-utils \
    xz-dev \
    zlib-dev

ARG CC=clang
ARG CXX=clang++

RUN cd /tmp \
&& curl -LO "$HTSLIB_URL" \
&& echo "$HTSLIB_CHECKSUM" > checksums.sha256 \
&& shasum -a256 -c checksums.sha256 \
&& tar -xf "htslib-$HTSLIB_VER.tar.bz2"


RUN cd "/tmp/htslib-$HTSLIB_VER" \
&& ./configure --prefix=/tmp/staging \
               --with-libdeflate \
&& make -j $(nproc) test \
&& make -j $(nproc) bgzip htsfile tabix \
&& make install \
&& install -Dm0644 LICENSE /tmp/staging/share/doc/htslib/copyright

RUN cd /tmp \
&& curl -LO "$SAMTOOLS_URL" \
&& echo "$SAMTOOLS_CHECKSUM" | tee checksums.sha256 > /dev/null \
&& shasum -a256 -c checksums.sha256 \
&& tar -xf "samtools-$SAMTOOLS_VER.tar.bz2"

RUN cd "/tmp/samtools-$SAMTOOLS_VER" \
&& ./configure --prefix=/tmp/staging \
               --without-curses \
               --with-htslib="/tmp/htslib-$HTSLIB_VER" \
&& make -j "$(nproc)" samtools \
&& make -j "$(nproc)" test \
&& make install \
&& install -Dm0644 LICENSE /tmp/staging/share/doc/samtools/copyright


FROM alpine:3.22 AS base
ARG CONTAINER_VERSION
ARG CONTAINER_TITLE

COPY --from=builder "/tmp/staging/bin" "/usr/local/bin"
COPY --from=builder "/tmp/staging/include" "/usr/local/include"
COPY --from=builder "/tmp/staging/lib" "/usr/local/lib"
COPY --from=builder "/tmp/staging/share" "/usr/local/share"


RUN apk add --no-cache \
    bzip2 \
    libarchive-tools \
    libdeflate \
    libncursesw \
    perl \
    procps \
    xz-libs \
    zlib

CMD ["/usr/local/bin/samtools"]
WORKDIR /data

RUN bgzip --version
RUN htsfile --version
RUN samtools --version
RUN tabix --version

LABEL org.opencontainers.image.authors='Roberto Rossini <roberros@uio.no>'
LABEL org.opencontainers.image.url='https://github.com/robomics/compress-nfcore-hic-output'
LABEL org.opencontainers.image.documentation='https://github.com/robomics/compress-nfcore-hic-output'
LABEL org.opencontainers.image.source='https://github.com/robomics/compress-nfcore-hic-output'
LABEL org.opencontainers.image.licenses='MIT'
LABEL org.opencontainers.image.title="${CONTAINER_TITLE:-samtools}"
LABEL org.opencontainers.image.version="${CONTAINER_VERSION:-latest}"
