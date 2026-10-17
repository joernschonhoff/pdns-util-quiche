FROM rust:1.99.1-trixie@sha256:e259494b14672950a909b4c54527e19d29cae6ebf980672114c8bb85e5594e4a AS quiche-builder
COPY VERSION /VERSION
RUN QUICHE_VERSION=$(cat /VERSION) && test -n "${QUICHE_VERSION}" || { echo "QUICHE_VERSION build-arg is required"; exit 1; }

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
	&& apt-get install -y --no-install-recommends \
        cmake \
        clang-19 \
        git

RUN QUICHE_VERSION=$(cat /VERSION) && git clone --recursive --depth 1 --branch ${QUICHE_VERSION} https://github.com/cloudflare/quiche.git /src
WORKDIR /src

COPY build_quiche.sh /build_quiche.sh
RUN export QUICHE_VERSION=$(cat /VERSION) \
    && chmod +x /build_quiche.sh \
    && /build_quiche.sh

FROM scratch
COPY --from=quiche-builder /quiche_lib/ /quiche_lib/