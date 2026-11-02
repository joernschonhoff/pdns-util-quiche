FROM rust:1.99.1-trixie@sha256:09027f873d45b8ecd1dc86f1fa13b7a62b875c961f017a0e331267b350430137 AS quiche-builder
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