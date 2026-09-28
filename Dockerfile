# syntax=docker/dockerfile:1
#
# Eiwa Browser Worker: headless Chromium + engine (spec §§28-29).
# Internal trusted network only: no ingress, no auth (§38).
#
# Usage:
#   docker build -t eiwac/browser-worker .
#   docker run --rm -p 8080:8080 eiwac/browser-worker
#   docker run --rm -p 8080:8080 -e PORT=8080 eiwac/browser-worker
#
# Multi-arch (linux/amd64, linux/arm64) via buildx in release.yml.
# The builder uses the official Eiwa toolchain image, so no local
# toolchain is needed. EIWA_BASELINE_CPU is already set there for
# portable binaries under emulation.

ARG EIWA_VERSION=latest

FROM eiwac/eiwa:${EIWA_VERSION} AS builder
WORKDIR /src
# System deps first: this layer only rebuilds when the Dockerfile changes.
RUN apt-get update && apt-get install -y --no-install-recommends chromium \
    && rm -rf /var/lib/apt/lists/*
COPY eiwa.yaml eiwa.yaml
COPY protocol protocol
COPY src src
COPY tests tests
# Live proof: run the FULL suite, including the real CDP session (goto +
# title on example.com). A broken engine fails the image build here.
RUN eiwa test
# NOTE: `eiwa build -o` rejects absolute paths (mkdir -p with empty
# operand; CLI bug filed upstream), so build relative then move.
RUN eiwa build -o worker && mkdir -p /out && mv worker /out/worker

FROM debian:trixie-slim
# Native worker links Boehm GC + OpenSSL (crypto dep) at runtime.
RUN apt-get update && apt-get install -y --no-install-recommends \
        chromium \
        fonts-liberation \
        ca-certificates \
        libgc1 \
        libssl3 \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /out/worker /usr/local/bin/worker

# Wiring hook for the engine's Chromium launcher.
ENV CHROMIUM_EXE=/usr/bin/chromium
ENV PORT=8080
EXPOSE 8080
ENTRYPOINT ["/usr/local/bin/worker"]
