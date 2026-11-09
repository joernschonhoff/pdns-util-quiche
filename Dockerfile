FROM rust:1.99.1-trixie@sha256:8a4e90c7946b74626488b1446f712c0fe0ed1a596cbd3d871684bc9c5433ae07 AS quiche-builder
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