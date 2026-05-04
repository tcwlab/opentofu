# opentofu — Repo context

> **Onboarding handshake:** Read in this order:
> 1. [`Projects/CLAUDE.md`](https://git.mon.k8b.co/) (global standards)
> 2. [`tcwlab/CLAUDE.md`](https://git.mon.k8b.co/tcwlab/) (toolchain context)
> 3. This file (opentofu-specific)

---

## What is `opentofu`?

`opentofu` is the container image wrapper repo that supplies the OpenTofu CLI in a pinned version within the tcwlab toolchain. Consumers use this image as `container:` in Forgejo workflows when they want to validate, format, or plan IaC code — typically via the `iac-ci.yml` template.

The image is intentionally minimal (Alpine 3.23, one tofu binary, a few helper packages for container job checkout). It is not a generic IaC image (no Terragrunt, no OpenTofu provider cache) — if those layers are needed, consumer repos build their own layer on top of `tcwlab/opentofu`.

### Consumers

Primary consumers are all repos with IaC content — currently `K8Box/provisioning`, `K8Box/infra`, plus any vertical with its own OpenTofu modules (e.g., bucket provisioning, DNS records, S3 backup buckets). tcwlab consumes this internally too: the image is used for smoke tests in its own `ci.yml`.

---

## What's inside?

Multi-stage [Dockerfile](https://git.mon.k8b.co/tcwlab/opentofu/src/branch/main/Dockerfile):

- **Stage 1 — `base`**: `alpine:3.23`, `apk add curl unzip git bash ca-certificates`, `apk upgrade`. BUILDPLATFORM-aware for multi-arch.
- **Stage 2 — `dependencies`**: arch-detect (`aarch64` → `arm64`, `x86_64` → `amd64`), download OpenTofu release zip from GitHub, unzip to `/usr/local/bin/tofu`, `tofu version` smoke test.
- **Stage 3 — `release`**: lean Alpine base with OCI labels, copies only the `tofu` binary from stage 2. Non-root user `tofuusr`. Workdir `/workspace`. ENTRYPOINT `tofu`.

Platforms: `linux/amd64`, `linux/arm64`. Buildx multi-arch.

---

## Tool versions and pinning strategy

The image tag is 1:1 with the OpenTofu version: `tcwlab/opentofu:1.11.6` contains exactly OpenTofu 1.11.6.

### Update discipline

For each OpenTofu release:

1. PR on `claude/bump-tofu-<version>`: change `ARG TOFU_VERSION=<x.y.z>` (two locations: `dependencies` + `release`).
2. CI builds and smoke-tests (`tofu version` in the pipeline).
3. semantic-release tags `v<version>` and pushes `tcwlab/opentofu:<x.y.z>` plus `tcwlab/opentofu:latest`.
4. Update [`tcwlab/versions.yaml`](https://git.mon.k8b.co/tcwlab/) at the workspace top level.
5. Consumer repos can then bump their `OPENTOFU_VERSION` values in `.forgejo/workflows/ci.yml` — controlled, via PR.

OpenTofu major releases (e.g., 1.x → 2.x) **always** require coordinated consumer migration plus collection of provider-compatibility notes. Leave an ADR-light note in the commit message in the tcwlab workspace.

---

## Release procedure

Configured like all other image repos: [`semantic-release`](https://git.mon.k8b.co/tcwlab/opentofu/src/branch/main/.releaserc) with Forgejo plugin (`@saithodev/semantic-release-gitea`), auto-tag, auto-release. Pipeline pattern from [`templates/docker-image-ci.yml`](https://git.mon.k8b.co/tcwlab/templates): Lint → Build-Test → Trivy-Scan → Auto-Tag + Publish to `tcwlab/opentofu:<x.y.z>`.

---

## What to do on version bump

1. PR to change `ARG TOFU_VERSION` (two locations!).
2. Let CI run — Trivy scan must be green, smoke test must output `tofu version`.
3. If needed: announce to consumer repos (e.g., K8Box Slack) if the bump affects provider compatibility.
4. After merge: maintain `versions.yaml` at the top level.

---

## What explicitly does NOT belong in this image

- **Provider cache** (no pre-warmed `~/.terraform.d/`). Providers are fetched at runtime in the consumer repo. For air-gapped setups: build a dedicated consumer image on top of `tcwlab/opentofu`.
- **Terragrunt**, **OpenTofu wrapper scripts**, **Atlantis hooks**. `tcwlab/opentofu` is the bare tofu CLI, nothing more.
- **Cloud provider CLIs** (aws, gcloud, az, hcloud). If a consumer needs this, they build a layer image.
- **kubectl, helm**. These belong either in K8Box-internal build images or a dedicated tcwlab `k8s` image (see `legacy/k8s/` for historical reference, but nothing active currently).
- **Editor / shell helpers**. Image stays minimal — no vim, no bash-completion, no profiles.

---

## Consumer snippets

### `tofu fmt -check`

```yaml
tofu-fmt:
  name: Tofu fmt
  runs-on: ubuntu-22.04
  container:
    image: tcwlab/opentofu:1.11.6
  steps:
    - uses: https://data.forgejo.org/actions/checkout@v4
    - run: tofu fmt -check -recursive
```

### `tofu validate`

```yaml
tofu-validate:
  name: Tofu validate
  runs-on: ubuntu-22.04
  container:
    image: tcwlab/opentofu:1.11.6
  steps:
    - uses: https://data.forgejo.org/actions/checkout@v4
    - run: |
        find . -name '*.tf' -execdir tofu init -backend=false \; -execdir tofu validate \;
```

### Complete from `templates/iac-ci.yml`

See [`templates/iac-ci.yml`](https://git.mon.k8b.co/tcwlab/templates/src/branch/main/iac-ci.yml). Drop-in to `.forgejo/workflows/ci.yml` and set `OPENTOFU_VERSION` to the current value from `versions.yaml`.

---

## Known pain points / open topics

- **OpenTofu version drift with AWS/Hetzner providers**: Provider bumps in consumer repos sometimes cause lock-file issues ahead of a tofu bump. Recommendation: when bumping OpenTofu, plan a coordinated PR wave across consumer repos.
- **Provider plugin cache**: We don't cache currently. For large IaC repos, this extends CI time. Refactoring idea: dedicated `tcwlab/opentofu-with-cache` image — currently deferred because consumer pipelines prefer to handle caching themselves via `actions/cache`.
- **`tofu init -backend=false` trick**: for validate jobs without backend access. Works, but each `init` per module directory needs its own invocation. In large IaC repos this is slow — see `templates/iac-ci.yml` for efficient implementation.
