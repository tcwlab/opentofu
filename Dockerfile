# ─────────────────────────────────────────────────────────────────────────────
# tcwlab/opentofu
#
# Minimales Alpine-Image mit gepinnter OpenTofu-Version.
# Der Image-Tag entspricht der OpenTofu-Version: tcwlab/opentofu:1.10.0
#
# Unterstützte Plattformen: linux/amd64, linux/arm64
#
# Build (multi-arch):
#   docker buildx build --platform linux/amd64,linux/arm64 \
#     --build-arg TOFU_VERSION=1.10.0 \
#     -t tcwlab/opentofu:1.10.0 --push .
# ─────────────────────────────────────────────────────────────────────────────

#####
# STEP 1: base image
#####
FROM --platform=$BUILDPLATFORM dhi.io/alpine-base:3.23 AS base
ARG BUILDPLATFORM
RUN apk add -U --no-cache curl unzip git bash ca-certificates && \
    apk upgrade && \
    rm -rf /var/cache/apk/*

#####
# STEP 2: download OpenTofu binary (arch-aware)
#####
FROM base AS dependencies
ARG TOFU_VERSION=1.10.0
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN case "$(apk --print-arch)" in \
        aarch64) LOCAL_ARCH="arm64" ;; \
        x86_64)  LOCAL_ARCH="amd64" ;; \
        *) echo "Unsupported architecture: $(apk --print-arch)" && exit 1 ;; \
    esac && \
    curl -fsSL \
      "https://github.com/opentofu/opentofu/releases/download/v${TOFU_VERSION}/tofu_${TOFU_VERSION}_linux_${LOCAL_ARCH}.zip" \
      -o /tmp/tofu.zip && \
    unzip -q /tmp/tofu.zip tofu -d /usr/local/bin/ && \
    rm /tmp/tofu.zip && \
    chmod +x /usr/local/bin/tofu && \
    tofu version

#####
# STEP 3: production image
#####
FROM base AS release
ARG TOFU_VERSION=1.10.0

LABEL org.opencontainers.image.title="opentofu" \
      org.opencontainers.image.description="opentofu — pinned version for reproducible CI" \
      org.opencontainers.image.vendor="The Chameleon Way" \
      org.opencontainers.image.url="https://hub.docker.com/r/tcwlab/opentofu" \
      org.opencontainers.image.source="https://git.mon.k8b.co/chameleon-ci/opentofu" \
      org.opencontainers.image.version="${TOFU_VERSION}"

COPY --from=dependencies /usr/local/bin/tofu /usr/local/bin/tofu

RUN addgroup -S tofuusr && adduser -S tofuusr -G tofuusr

USER tofuusr
WORKDIR /workspace
ENTRYPOINT ["tofu"]
