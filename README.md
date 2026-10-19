# flutter-builder

Flutter SDK builder image for AO Cyber Systems CI and Docker builds.

```
ghcr.io/aocyberai/flutter:3.47.5   # Flutter 3.47.5 stable, Dart 3.13.4
ghcr.io/aocyberai/flutter:3.47     # moving tag: newest 3.47.x we published
```

Platforms: `linux/amd64`, `linux/arm64`. Public — pulls need no registry credentials
(GitHub Actions, DigitalOcean App Platform, local Docker). There is deliberately no
`:latest` tag.

## Why

`ghcr.io/cirruslabs/flutter` stopped at 3.44.0, and our apps need 3.47.x. This image
replaces cirruslabs for our builds. It is also far smaller (~2 GB vs ~20 GB) because it
carries only what `flutter build web` needs — no Android SDK.

## Usage

```dockerfile
FROM ghcr.io/aocyberai/flutter:3.47.5@sha256:<digest> AS builder
WORKDIR /app
COPY . .
RUN flutter pub get && flutter build web --release
```

**Pin by digest.** Tags are mutable; the digest for each release is printed in the
publish workflow's run summary, or:

```sh
docker buildx imagetools inspect ghcr.io/aocyberai/flutter:3.47.5
```

Verify the signature (cosign keyless, signed by this repo's publish workflow):

```sh
cosign verify ghcr.io/aocyberai/flutter:3.47.5 \
  --certificate-identity-regexp '^https://github.com/AOCyber-OSS/flutter-builder/\.github/workflows/publish\.yml@refs/tags/v' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

SBOM and SLSA provenance are attached as BuildKit attestations
(`docker buildx imagetools inspect <ref> --format '{{json .SBOM}}'`).

## What's inside

| | |
|---|---|
| Base | `debian:bookworm-slim` |
| User | `root` |
| `WORKDIR` | `/app` |
| Flutter SDK | `/sdks/flutter` (`FLUTTER_HOME`, `FLUTTER_ROOT`), on `stable` |
| `PATH` | `/sdks/flutter/bin`, `/sdks/flutter/bin/cache/dart-sdk/bin`, `/root/.pub-cache/bin` |
| `PUB_CACHE` | `/root/.pub-cache` |
| Tools | `git`, `openssh-client`, `curl`, `unzip`, `xz-utils`, `zip`, `ca-certificates` |
| Precached | web (`flutter precache --web`); analytics disabled for flutter and dart |

`git config --system safe.directory '*'` is set so the root-owned SDK and bind-mounted
checkouts work for non-root users too.

### Differences from cirruslabs/flutter

- **Web only.** No Android SDK/Java, no Linux desktop toolchain (clang/cmake/ninja/gtk),
  no Chrome. `flutter build apk` / `flutter build linux` / `flutter test --platform chrome`
  will not work without adding those.
- Same user (root), same SDK path (`/sdks/flutter`), `flutter`/`dart` on `PATH`.
  cirruslabs does not set a `WORKDIR`; this image sets `/app` (a `WORKDIR` in your
  Dockerfile overrides it).

## Publishing a new Flutter version

1. Edit `Dockerfile`: `ARG FLUTTER_VERSION=` and `ARG EXPECTED_DART_VERSION=`
   (the build fails if the SDK reports anything else).
2. Build and smoke-test locally:
   ```sh
   docker build -t flutter-local .
   docker run --rm flutter-local flutter --version
   ```
3. Commit, push `main`, then tag with the Flutter version and push the tag:
   ```sh
   git tag -s v3.47.6 -m "Flutter 3.47.6" && git push origin v3.47.6
   ```
   The `publish` workflow checks the tag matches `FLUTTER_VERSION`, builds amd64 and
   arm64 on native runners, pushes `:3.47.6` and `:3.47`, and cosign-signs the digest.
4. Update consumers' `FROM` lines to the new digest.
