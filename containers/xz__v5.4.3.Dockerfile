# Copyright (C) 2023 Roberto Rossini <roberros@uio.no>
#
# SPDX-License-Identifier: MIT



FROM curlimages/curl:8.2.0 AS downloader

ARG CONTAINER_VERSION
ARG XZ_VER=${CONTAINER_VERSION}
ARG XZ_SHA256
ARG XZ_URL="https://tukaani.org/xz/xz-$XZ_VER.tar.gz"
ARG XZ_CHECKSUM="${XZ_SHA256:-1c382e0bc2e4e0af58398a903dd62fff7e510171d2de47a1ebe06d1528e9b7e9}  xz-${XZ_VER}.tar.gz"

RUN if [ -z "$CONTAINER_VERSION" ]; then echo "Missing CONTAINER_VERSION --build-arg" && exit 1; fi

RUN echo "$XZ_CHECKSUM" > /tmp/checksum.sha256

RUN cd /tmp \
&& curl -LO "$XZ_URL" \
&& sha256sum -c checksum.sha256


FROM ubuntu:22.04 AS builder

RUN apt-get update \
&& apt-get install -y build-essential

ARG CONTAINER_VERSION
ARG XZ_VER=${CONTAINER_VERSION}
ARG ARCHIVE="xz-${XZ_VER}.tar.gz"

COPY --from=downloader "/tmp/$ARCHIVE" /tmp/

RUN tar -C /tmp -xf "/tmp/$ARCHIVE" \
&& cd "/tmp/${ARCHIVE%.tar.gz}" \
&& ./configure \
&& make -j $(nproc) \
&& make check -j $(nproc) \
&& make install

FROM ubuntu:22.04 AS base

ENV LD_LIBRARY_PATH="/usr/local/lib"
ENV PATH="/usr/local/bin:$PATH"
CMD ["/usr/local/bin/xz"]
WORKDIR /data


ARG CONTAINER_VERSION
ARG CONTAINER_TITLE

COPY --from=builder /usr/local /usr/local

RUN xz --version | grep -q "$CONTAINER_VERSION"

LABEL org.opencontainers.image.authors='Roberto Rossini <roberros@uio.no>'
LABEL org.opencontainers.image.url='https://github.com/robomics/compress-nfcore-hic-output'
LABEL org.opencontainers.image.documentation='https://github.com/robomics/compress-nfcore-hic-output'
LABEL org.opencontainers.image.source='https://github.com/robomics/compress-nfcore-hic-output'
LABEL org.opencontainers.image.licenses='MIT'
LABEL org.opencontainers.image.title="${CONTAINER_TITLE:-xz}"
LABEL org.opencontainers.image.version="${CONTAINER_VERSION:-latest}"
