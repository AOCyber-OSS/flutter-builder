# syntax=docker/dockerfile:1.7
#
# AO Cyber Systems Flutter builder image.
#
# Drop-in replacement for ghcr.io/cirruslabs/flutter for our web builds:
#   - runs as root, WORKDIR /app
#   - Flutter SDK at /sdks/flutter, `flutter` and `dart` on PATH
#   - git, openssh-client, curl, unzip, xz-utils, zip preinstalled
#   - web artifacts precached (no Android SDK, no Linux desktop toolchain)
#
# The SDK is installed from a shallow git clone of the release tag rather than
# the release tarball, because the tarball is x64-only; the clone works on both
# linux/amd64 and linux/arm64 (the Dart SDK is fetched per-arch on first run).
#
# Bumping Flutter is a one-line change: FLUTTER_VERSION (+ EXPECTED_DART_VERSION).
# The build FAILS if the installed SDK does not report exactly these versions.

FROM debian:bookworm-slim

ARG FLUTTER_VERSION=3.47.5
ARG EXPECTED_DART_VERSION=3.13.4

LABEL org.opencontainers.image.title="flutter" \
      org.opencontainers.image.description="Flutter SDK builder image for AO Cyber Systems CI and Docker builds" \
      org.opencontainers.image.source="https://github.com/AO-Cyber-Systems/flutter-builder" \
      org.opencontainers.image.vendor="AO Cyber Systems" \
      org.opencontainers.image.version="${FLUTTER_VERSION}"

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    FLUTTER_HOME=/sdks/flutter \
    FLUTTER_ROOT=/sdks/flutter \
    PUB_CACHE=/root/.pub-cache \
    CI=true \
    PATH=/sdks/flutter/bin:/sdks/flutter/bin/cache/dart-sdk/bin:/root/.pub-cache/bin:$PATH

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        bash ca-certificates curl git openssh-client unzip xz-utils zip \
        libglu1-mesa libstdc++6 && \
    rm -rf /var/lib/apt/lists/* && \
    # The SDK is owned by root; allow non-root users / bind-mounted checkouts
    # to use git without "dubious ownership" failures (flutter shells out to git).
    git config --system --add safe.directory '*'

RUN git clone --depth 1 --branch "${FLUTTER_VERSION}" \
        https://github.com/flutter/flutter.git "${FLUTTER_HOME}" && \
    # A tag clone is a detached HEAD, which Flutter reports as channel
    # "[user-branch]". Name the branch "stable" so it reports "channel stable",
    # matching the official SDK and the cirruslabs images.
    git -C "${FLUTTER_HOME}" checkout -q -b stable && \
    flutter config --no-analytics --no-cli-animations --enable-web && \
    flutter precache --web && \
    dart --disable-analytics && \
    flutter --version && \
    VERSION_JSON="$(flutter --version --machine)" && \
    echo "${VERSION_JSON}" | grep -q "\"frameworkVersion\": \"${FLUTTER_VERSION}\"" || \
        { echo "FATAL: Flutter is not ${FLUTTER_VERSION}: ${VERSION_JSON}" >&2; exit 1; } && \
    DART_VERSION="$(dart --version 2>&1)" && \
    echo "${DART_VERSION}" | grep -q "Dart SDK version: ${EXPECTED_DART_VERSION} " || \
        { echo "FATAL: Dart is not ${EXPECTED_DART_VERSION}: ${DART_VERSION}" >&2; exit 1; } && \
    rm -rf /root/.cache /tmp/* && \
    (flutter doctor -v || true)

WORKDIR /app
