# opentofu — Repo-Kontext

> **Onboarding-Handshake:** Lies in dieser Reihenfolge:
> 1. [`Projects/CLAUDE.md`](https://git.mon.k8b.co/) (globale Standards)
> 2. [`tcwlab/CLAUDE.md`](https://git.mon.k8b.co/tcwlab/) (Toolchain-Kontext)
> 3. Diese Datei (opentofu-spezifisches)

---

## Was ist `opentofu`?

`opentofu` ist das Container-Image-Wrapper-Repo, das in der tcwlab-Toolchain die OpenTofu-CLI in einer gepinnten Version bereitstellt. Konsumenten verwenden das Image als `container:` in Forgejo-Workflows, wenn sie IaC-Code validieren, formatieren oder planen wollen — typischerweise im `iac-ci.yml`-Template.

Das Image ist bewusst minimal (Alpine 3.23, ein Tofu-Binary, ein paar Helper-Pakete für Checkout im Container-Job). Es ist kein generisches IaC-Image (kein Terragrunt, kein OpenTofu-Provider-Cache) — wenn solche Layer gebraucht werden, baut sich das Konsumenten-Repo ein eigenes Layer auf Basis von `tcwlab/opentofu`.

### Konsumenten

Hauptkonsumenten sind alle Repos mit IaC-Anteil — derzeit `K8Box/provisioning`, `K8Box/infra`, plus jedes Vertical, das eigene OpenTofu-Module hat (z.B. Bucket-Provisioning, DNS-Records, S3-Backup-Buckets). Auch hier konsumiert `tcwlab`-intern: das Image wird für Smoke-Tests im eigenen `ci.yml` verwendet.

---

## Was ist drin?

Multi-Stage [Dockerfile](https://git.mon.k8b.co/tcwlab/opentofu/src/branch/main/Dockerfile):

- **Stage 1 — `base`**: `alpine:3.23`, `apk add curl unzip git bash ca-certificates`, `apk upgrade`. BUILDPLATFORM-aware für Multi-Arch.
- **Stage 2 — `dependencies`**: arch-detect (`aarch64` → `arm64`, `x86_64` → `amd64`), Download des OpenTofu-Release-Zips von GitHub, Unzip nach `/usr/local/bin/tofu`, `tofu version`-Smoke-Test.
- **Stage 3 — `release`**: leeres Alpine-Base mit OCI-Labels, kopiert nur das `tofu`-Binary aus Stage 2 ein. Non-root user `tofuusr`. Workdir `/workspace`. ENTRYPOINT `tofu`.

Plattformen: `linux/amd64`, `linux/arm64`. Buildx multi-arch.

---

## Tool-Versionen und Pinning-Strategie

Das Image-Tag ist 1:1 mit der OpenTofu-Version: `tcwlab/opentofu:1.11.6` enthält OpenTofu 1.11.6.

### Update-Disziplin

Bei jedem OpenTofu-Release:

1. PR auf `claude/bump-tofu-<version>`: `ARG TOFU_VERSION=<x.y.z>` ändern (zwei Stellen: `dependencies` + `release`).
2. CI baut, smoke-tested (`tofu version` in der Pipeline).
3. semantic-release tagged `v<version>` und pusht `tcwlab/opentofu:<x.y.z>` plus `tcwlab/opentofu:latest`.
4. [`tcwlab/versions.yaml`](https://git.mon.k8b.co/tcwlab/) im Top-Level-Workspace aktualisieren.
5. Konsumenten-Repos können dann ihre `OPENTOFU_VERSION`-Werte in `.forgejo/workflows/ci.yml` hochziehen — kontrolliert, per PR.

OpenTofu-Major-Releases (z.B. 1.x → 2.x) erfordern **immer** koordinierte Konsumenten-Migration plus Sammeln von Provider-Kompatibilitäts-Notes. Im tcwlab-Workspace eine ADR-light-Notiz dazu in der Commit-Message hinterlassen.

---

## Release-Verfahren

Konfiguriert wie alle anderen Image-Repos: [`semantic-release`](https://git.mon.k8b.co/tcwlab/opentofu/src/branch/main/.releaserc) mit Forgejo-Plugin (`@saithodev/semantic-release-gitea`), Auto-Tag, Auto-Release. Pipeline-Pattern aus [`templates/docker-image-ci.yml`](https://git.mon.k8b.co/tcwlab/templates) übernommen: Lint → Build-Test → Trivy-Scan → Auto-Tag + Publish nach `tcwlab/opentofu:<x.y.z>`.

---

## Was bei Versions-Bump zu tun ist

1. PR mit `ARG TOFU_VERSION` umstellen (zwei Stellen!).
2. CI durchlaufen lassen — Trivy-Scan muss grün sein, Smoke-Test muss `tofu version` ausgeben.
3. Bei Bedarf: Konsumenten-Repos ankündigen (z.B. K8Box-Slack), wenn der Bump Provider-Kompatibilität betrifft.
4. Nach Merge: `versions.yaml` auf Top-Level pflegen.

---

## Was explizit NICHT in dieses Image gehört

- **Provider-Cache** (kein vorgewärmter `~/.terraform.d/`). Provider werden zur Laufzeit im Konsumenten-Repo geholt. Für Air-Gapped-Setups: dediziertes Konsumenten-Image auf Basis von `tcwlab/opentofu`.
- **Terragrunt**, **OpenTofu-Wrapper-Skripte**, **Atlantis-Hooks**. `tcwlab/opentofu` ist die nackte Tofu-CLI, nichts mehr.
- **Cloud-Provider-CLIs** (aws, gcloud, az, hcloud). Wenn ein Konsument das braucht, baut er ein Layer-Image.
- **kubectl, helm**. Diese gehören entweder zu K8Box-internen Build-Images oder zu einem dedizierten tcwlab-`k8s`-Image (siehe `legacy/k8s/` für die Vergangenheits-Referenz, aber aktiv ist sowas derzeit nicht).
- **Editor / Shell-Helper**. Image bleibt minimal — kein vim, kein bash-completion, keine Profile.

---

## Konsumenten-Snippets

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

### Komplett aus `templates/iac-ci.yml`

Siehe [`templates/iac-ci.yml`](https://git.mon.k8b.co/tcwlab/templates/src/branch/main/iac-ci.yml). Drop-in nach `.forgejo/workflows/ci.yml` und `OPENTOFU_VERSION` auf den aktuellen Wert aus `versions.yaml` setzen.

---

## Bekannte Schmerzpunkte / offene Themen

- **OpenTofu-Versionsdrift mit AWS-/Hetzner-Provider**: Provider-Bumps in Konsumenten-Repos machen manchmal vor einem Tofu-Bump Lock-File-Probleme. Empfehlung: bei OpenTofu-Bump auch eine Sammel-PR-Welle für Konsumenten-Repos planen.
- **Provider-Plugin-Cache**: Wir cachen aktuell nicht. Bei großen IaC-Repos verlängert das CI-Zeit. Refactoring-Idee: dediziertes `tcwlab/opentofu-with-cache`-Image — aktuell zurückgestellt, weil Konsumenten-Pipelines den Cache lieber via `actions/cache` selbst handhaben.
- **`tofu init -backend=false`-Trick**: für Validate-Jobs ohne Backend-Zugriff. Funktioniert, aber pro-`init` braucht jedes Modul-Verzeichnis seinen eigenen `init`. In großen IaC-Repos ist das langsam — siehe `templates/iac-ci.yml` für effiziente Implementierung.
