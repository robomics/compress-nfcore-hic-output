# Copyright (C) 2023 Roberto Rossini <roberros@uio.no>
#
# SPDX-License-Identifier: MIT



FROM curlimages/curl:8.10.1 AS downloader

ARG CONTAINER_VERSION
ARG XZ_VER=${CONTAINER_VERSION}
ARG XZ_SHA256
ARG XZ_URL="https://github.com/tukaani-project/xz/archive/refs/tags/v$XZ_VER.tar.gz"
ARG XZ_CHECKSUM="${XZ_SHA256:-60831005fddb270824fa9f7cdd28a59da8757fe95466ed5b10bcfe23379f17d9}  v${XZ_VER}.tar.gz"

RUN if [ -z "$CONTAINER_VERSION" ]; then echo "Missing CONTAINER_VERSION --build-arg" && exit 1; fi

RUN echo "$XZ_CHECKSUM" > /tmp/checksum.sha256

RUN cd /tmp \
&& curl -LO "$XZ_URL" \
&& sha256sum -c checksum.sha256


FROM ubuntu:24.04 AS builder

RUN apt-get update \
&& apt-get install -y autoconf autopoint build-essential doxygen libtool po4a

ARG CONTAINER_VERSION
ARG XZ_VER=${CONTAINER_VERSION}
ARG ARCHIVE="v${XZ_VER}.tar.gz"

COPY --from=downloader "/tmp/$ARCHIVE" /tmp/

RUN tar -C /tmp -xf "/tmp/$ARCHIVE" \
&& cd /tmp/xz-* \
&& ./autogen.sh \
&& ./configure --prefix=/usr/local/ \
&& make -j $(nproc) \
&& make check -j $(nproc) \
&& make install

FROM ubuntu:24.04 AS base

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
