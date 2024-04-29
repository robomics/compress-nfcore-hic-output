# Copyright (C) 2023 Roberto Rossini <roberros@uio.no>
#
# SPDX-License-Identifier: MIT

FROM ubuntu:24.04 AS builder

ARG CONTAINER_VERSION
ARG SAMTOOLS_VER=${CONTAINER_VERSION}
ARG HTSLIB_VER=${SAMTOOLS_VER}

ARG HTSLIB_URL="https://github.com/samtools/htslib/releases/download/$HTSLIB_VER/htslib-$HTSLIB_VER.tar.bz2"
ARG HTSLIB_CHECKSUM="e52d95b14da68e0cfd7d27faf56fef2f88c2eaf32a2be51c72e146e3aa928544  htslib-$HTSLIB_VER.tar.bz2"

ARG SAMTOOLS_URL="https://github.com/samtools/samtools/releases/download/$SAMTOOLS_VER/samtools-$SAMTOOLS_VER.tar.bz2"
ARG SAMTOOLS_CHECKSUM="c71be865e241613c2ca99679c074f1a0daeb55288af577db945bdabe3eb2cf10  samtools-$SAMTOOLS_VER.tar.bz2"

RUN if [ -z "$CONTAINER_VERSION" ]; then echo "Missing CONTAINER_VERSION --build-arg" && exit 1; fi

RUN apt-get update \
&& apt-get install -y autoconf \
                      bzip2 \
                      curl \
                      gawk \
                      g++ \
                      make \
                      perl \
                      libbz2-dev \
                      libdeflate-dev \
                      liblzma-dev \
                      libncurses5-dev \
                      zlib1g-dev

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

FROM ubuntu:24.04 AS base
ARG CONTAINER_VERSION
ARG CONTAINER_TITLE

COPY --from=builder "/tmp/staging/bin" "/usr/local/bin"
COPY --from=builder "/tmp/staging/include" "/usr/local/include"
COPY --from=builder "/tmp/staging/lib" "/usr/local/lib"
COPY --from=builder "/tmp/staging/share" "/usr/local/share"

RUN apt-get update \
&& apt-get install -y perl \
                      bzip2 \
                      libdeflate0 \
                      libncurses6 \
                      lzma \
                      procps \
                      zlib1g \
&& rm -rf /var/lib/apt/lists/*

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
