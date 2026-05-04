# tcwlab/opentofu

> Pinned [OpenTofu](https://opentofu.org/) CLI in a hardened Alpine container for reproducible IaC pipelines. Image tag = OpenTofu version. Drop-in for Forgejo/GitHub Actions container jobs that need deterministic toolchain versions.

[![Docker Pulls](https://img.shields.io/docker/pulls/tcwlab/opentofu?label=pulls)](https://hub.docker.com/r/tcwlab/opentofu)
[![Image Size](https://img.shields.io/docker/image-size/tcwlab/opentofu/latest?label=size)](https://hub.docker.com/r/tcwlab/opentofu/tags)
[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](LICENSE)

---

## Quick start

```bash
docker pull tcwlab/opentofu:1.11.6

# Run against the current directory
docker run --rm -v "$PWD:/workspace" tcwlab/opentofu:1.11.6 version
```

Or as a Forgejo / GitHub Actions container job:

```yaml
tofu-validate:
  runs-on: ubuntu-22.04
  container:
    image: tcwlab/opentofu:1.11.6
  steps:
    - uses: https://data.forgejo.org/actions/checkout@v4
    - run: tofu fmt -check -recursive
    - run: |
        find . -name '*.tf' -execdir tofu init -backend=false \; \
                            -execdir tofu validate \;
```

---

## Tags

| Tag | Description |
|-----|-------------|
| `1.11.6`, `1.11`, `1` | Concrete SemVer (recommended for production pipelines) |
| `latest` | Rolling reference; always points at the newest release |

**Always pin a concrete version in production.** `latest` is fine for local experiments, but pinning protects your pipeline from a toolchain bump that lands without a PR. The major/minor floating tags (`1`, `1.11`) are convenient for internal use; external consumers should pin the full SemVer.

The `opentofu` image tag **mirrors** the OpenTofu CLI version exactly. When OpenTofu 1.11.6 is released, `tcwlab/opentofu:1.11.6` contains that exact version (not a wrapper SemVer).

---

## Supported architectures

- `linux/amd64`
- `linux/arm64`

Every tag is a multi-arch manifest list. Docker pulls the right architecture automatically.

---

## What's included

| Tool | Version | Purpose |
|------|---------|---------|
| [`opentofu`](https://opentofu.org/) | `1.11.6` | Infrastructure-as-Code CLI |
| `curl` | from Alpine 3.23 apk | Download support |
| `unzip` | from Alpine 3.23 apk | Archive extraction |
| `git` | from Alpine 3.23 apk | Git operations in containers |
| `bash` | from Alpine 3.23 apk | Shell compatibility |
| `ca-certificates` | from Alpine 3.23 apk | TLS/SSL certificate validation |

Base image: `alpine:3.23`. Default workdir: `/workspace`. Default user: `tofuusr` (non-root, uid auto-assigned).

---

## Usage

### Validate Terraform/OpenTofu code

```bash
docker run --rm -v "$PWD:/workspace" tcwlab/opentofu:1.11.6 \
  sh -c 'find . -name "*.tf" -execdir tofu init -backend=false \; -execdir tofu validate \;'
```

### Format check

```bash
docker run --rm -v "$PWD:/workspace" tcwlab/opentofu:1.11.6 fmt -check -recursive
```

### Forgejo workflow — full snippet

```yaml
lint:
  name: OpenTofu Format
  runs-on: ubuntu-22.04
  container:
    image: tcwlab/opentofu:1.11.6
  steps:
    - uses: https://data.forgejo.org/actions/checkout@v4
    - name: Format check
      run: tofu fmt -check -recursive

validate:
  name: OpenTofu Validate
  runs-on: ubuntu-22.04
  needs: lint
  container:
    image: tcwlab/opentofu:1.11.6
  steps:
    - uses: https://data.forgejo.org/actions/checkout@v4
    - name: Validate
      run: |
        find . -name '*.tf' -execdir tofu init -backend=false \; \
                            -execdir tofu validate \;
```

---

## Configuration

### Volume mount points

| Path | Purpose |
|------|---------|
| `/workspace` | Default workdir; mount your IaC repo here |

### Environment variables

The image passes all environment variables directly to OpenTofu. Common patterns:

| Variable | Example | Purpose |
|----------|---------|---------|
| `TF_LOG` | `DEBUG` | Enable OpenTofu debug logging |
| `TF_VAR_*` | `TF_VAR_region=us-east-1` | Pass input variables |
| `TF_CLI_ARGS` | `-no-color` | Global CLI arguments |

### Working directory

The image runs with `WORKDIR /workspace`. If your IaC files are in a subdirectory, use:

```yaml
- run: |
    cd ./infra
    tofu init -backend=false
    tofu validate
```

---

## Why `tcwlab/opentofu` and not upstream images?

Pinning discipline. Public OpenTofu images (Docker Hub official, GitHub Container Registry) often use `latest` or floating major versions, which means your CI toolchain can silently advance to a new OpenTofu version without a PR. `tcwlab/opentofu` enforces the principle that **every tool version is explicit** — the image tag is the version, and upgrades happen via PR.

Additional benefits:

- **Deterministic builds** — same tag always pulls the exact OpenTofu version (no surprises).
- **Consistent Alpine base** — all tcwlab images use Alpine 3.23, minimal and hardened identically.
- **Multi-arch by default** — `linux/amd64` and `linux/arm64` in every release.
- **Security scanning** — each build is scanned with Trivy before publication.

---

## Source, issues, contributing

- **Source (canonical)**: [`git.mon.k8b.co/tcwlab/opentofu`](https://git.mon.k8b.co/tcwlab/opentofu)
- **Source (mirror)**: [`github.com/tcwlab/opentofu`](https://github.com/tcwlab/opentofu)
- **Issues / feature requests**: [`github.com/tcwlab/opentofu/issues`](https://github.com/tcwlab/opentofu/issues)
- **Docker Hub**: [`hub.docker.com/r/tcwlab/opentofu`](https://hub.docker.com/r/tcwlab/opentofu)

The Forgejo repo on `git.mon.k8b.co` is the source of truth. The GitHub mirror exists so external consumers have a public-facing copy with an issue tracker; please open issues there.

---

## Build, supply chain

Every release is built and published by the repo's own [`.forgejo/workflows/ci.yml`](https://git.mon.k8b.co/tcwlab/opentofu/src/branch/main/.forgejo/workflows/ci.yml) on a Forgejo runner:

- Multi-arch build (`linux/amd64`, `linux/arm64`) via `docker buildx` with `--sbom=true --provenance=mode=max`.
- Trivy vulnerability scan on `HIGH`/`CRITICAL` severity (failures show up as PR comments).
- Self-lint via `betterlint` running against the Dockerfile.

The `opentofu` image version is cut by `semantic-release` from Conventional Commits on `main`. The version exactly mirrors the OpenTofu CLI version (e.g., release of OpenTofu 1.11.6 triggers a new `tcwlab/opentofu:1.11.6` image).

---

## License

Apache License 2.0. See [`LICENSE`](LICENSE) for the full text.

OpenTofu itself is licensed under MPL-2.0. See [`opentofu/opentofu`](https://github.com/opentofu/opentofu) for details.
