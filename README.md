# tcwlab/opentofu

Minimales Alpine-Image mit gepinnter [OpenTofu](https://opentofu.org/)-CLI für CI-Pipelines.
Teil der [tcwlab](https://git.mon.k8b.co/tcwlab) Open-Source-Toolchain.

[![Docker Hub](https://img.shields.io/badge/docker-tcwlab%2Fopentofu-blue)](https://hub.docker.com/r/tcwlab/opentofu)
[![License: Apache 2.0](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](LICENSE)

## Was steckt drin?

Ein einziger gepinnter Tofu-Binary in einem schlanken `alpine:3.23`-Image, gebaut für `linux/amd64` und `linux/arm64`. Der Image-Tag entspricht 1:1 der OpenTofu-Version — also `tcwlab/opentofu:1.11.6` enthält genau OpenTofu 1.11.6.

Dazu nur das Nötigste: `curl`, `unzip`, `git`, `bash`, `ca-certificates`. Bewusst keine Provider-Caches, keine Cloud-CLIs, keine Helper-Skripte — wenn du das brauchst, baust du dir ein Layer-Image auf Basis von `tcwlab/opentofu`.

## Verwendung in CI

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

Vollständiges Pipeline-Skelett: [`templates/iac-ci.yml`](https://git.mon.k8b.co/tcwlab/templates/src/branch/main/iac-ci.yml).

## Verfügbare Versionen

| Tag | OpenTofu-Version |
|-----|------------------|
| `tcwlab/opentofu:1.11.6` | OpenTofu 1.11.6 (aktuell) |
| `tcwlab/opentofu:latest` | rolling, identisch zur jüngsten getaggten Version |

Konsumenten **immer** auf konkrete Version pinnen, nie auf `latest`.

## Update-Strategie

OpenTofu-Releases werden manuell gemerged: PR mit `ARG TOFU_VERSION=<x.y.z>`, semantic-release erzeugt den passenden Image-Tag. Maschinenlesbarer Snapshot der jeweils aktuellen Version: [`tcwlab/versions.yaml`](https://git.mon.k8b.co/tcwlab/).

## Lokaler Build

```bash
docker build --build-arg TOFU_VERSION=1.11.6 -t tcwlab/opentofu:1.11.6 .
```

Multi-Arch:

```bash
docker buildx build --platform linux/amd64,linux/arm64 \
  --build-arg TOFU_VERSION=1.11.6 \
  -t tcwlab/opentofu:1.11.6 --push .
```

## Lizenz

Apache-2.0 — The Chameleon Way. OpenTofu selbst steht unter MPL-2.0 (siehe [opentofu/opentofu](https://github.com/opentofu/opentofu)).
