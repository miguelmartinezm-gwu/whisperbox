# syntax=docker/dockerfile:1
# Whisperbox M6 interim — Mojo + Python interop HTTP server, with the Fog
# FHE toolchain baked in (M6 Option A per Grok: temporary, to be removed
# in M6b when whisperbox-fog-worker Job takes over the Fog compute step).

# -----------------------------------------------------------------------------
# Build
# -----------------------------------------------------------------------------
FROM ubuntu:24.04 AS build

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl ca-certificates clang build-essential \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://pixi.sh/install.sh | sh
ENV PATH="/root/.pixi/bin:${PATH}"

WORKDIR /build

COPY pixi.toml ./

RUN pixi add mojo python && pixi install

COPY main.mojo .

RUN pixi run mojo build main.mojo -o main \
 && test -x /build/main \
 && find /build/.pixi/envs/default/lib -name 'libpython*' -ls

# -----------------------------------------------------------------------------
# Runtime
# -----------------------------------------------------------------------------
FROM ubuntu:24.04

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl jq \
    && rm -rf /var/lib/apt/lists/*

COPY --from=build /build/main /main
COPY --from=build /build/.pixi/envs/default /opt/pixi-env

# M6 interim: Fog FHE toolchain (binaries + OpenFHE libs). Keys fetched
# at startup from private GCS, NOT baked into this image.
COPY fog-bin/dot8_server /fog/dot8_server
COPY fog-bin/dot8_decrypt /fog/dot8_decrypt
COPY fog-bin/nbcc_fhetch_replay /fog/nbcc_fhetch_replay
COPY fog-bin/fog /fog/fog
COPY fog-lib/ /fog/lib/
COPY entrypoint.sh /entrypoint.sh

RUN chmod +x /fog/dot8_server /fog/dot8_decrypt /fog/nbcc_fhetch_replay /entrypoint.sh

ENV PATH="/opt/pixi-env/bin:/fog:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
ENV LD_LIBRARY_PATH="/opt/pixi-env/lib:/fog/lib"
ENV PYTHONHOME="/opt/pixi-env"
ENV PYTHONPATH="/opt/pixi-env/lib/python3.14"
ENV LD_PRELOAD="/opt/pixi-env/lib/libpython3.14.so.1.0"
ENV FOG_KEYS_BUCKET="whisperbox-510521-fog-keys"
ENV FOG_KEYS_DIR="/fog/dot8_keys"

ENV PORT=8080
EXPOSE 8080

ENTRYPOINT ["/entrypoint.sh"]
