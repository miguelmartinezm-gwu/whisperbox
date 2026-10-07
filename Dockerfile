# syntax=docker/dockerfile:1
# Whisperbox M1 — Mojo 1.1 + Python interop HTTP server for Cloud Run

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
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY --from=build /build/main /main
COPY --from=build /build/.pixi/envs/default /opt/pixi-env

ENV PATH="/opt/pixi-env/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
ENV LD_LIBRARY_PATH="/opt/pixi-env/lib"
ENV PYTHONHOME="/opt/pixi-env"
ENV PYTHONPATH="/opt/pixi-env/lib/python3.14"
ENV LD_PRELOAD="/opt/pixi-env/lib/libpython3.14.so.1.0"

ENV PORT=8080
EXPOSE 8080

ENTRYPOINT ["/main"]
