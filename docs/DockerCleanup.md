# Docker Cleanup Runbook

## Overview

This document describes the process for reclaiming local Docker disk space on
a developer workstation — stale containers, unreferenced images, dangling
networks, build cache, and (opt-in) unused volumes — using the
[`Invoke-DockerCleanup.ps1`](../.build/Invoke-DockerCleanup.ps1) automation.

The script is safety-first: it always runs a survey by default, supports a
dry-run flag, and auto-protects images that are in use by containers,
referenced by this repo's `docker-compose*.yml` files, or part of the running
devcontainer / Docker Desktop Kubernetes stack.

A companion [Copilot CLI skill](../.github/copilot/skills/docker-cleanup/SKILL.md)
drives this script with contextual checks and produces a structured post-run
summary.

## Quick start

```powershell
# Survey only — no changes (always safe to run)
.\.build\Invoke-DockerCleanup.ps1

# Recommended cleanup, protecting images referenced by this repo's compose files
.\.build\Invoke-DockerCleanup.ps1 -Mode Standard -RepoPath $PWD

# Maximum cleanup, unattended
.\.build\Invoke-DockerCleanup.ps1 -Mode Aggressive -IncludeVolumes -Force

# Preview an aggressive cleanup without touching anything
.\.build\Invoke-DockerCleanup.ps1 -Mode Aggressive -IncludeVolumes -DryRun
```

## Modes

| Mode | Containers | Images | Build cache | Volumes |
|---|---|---|---|---|
| **Survey** (default) | report only | report only | report only | report only |
| **Safe** | exited > `-MaxAgeDays` | dangling only | — | — |
| **Standard** | exited > `-MaxAgeDays` | dangling + unused unnamed | pruned (`-IncludeBuildCache`) | only if `-IncludeVolumes` |
| **Aggressive** | exited > `-MaxAgeDays` | **all unused** (incl. named) | pruned | **pruned always** |

The "stale containers" filter requires a container to be older than
`-MaxAgeDays` (default 30) **and** in exited / dead / created state.

## Auto-protection

The script protects images from removal when any of the following apply.
Override with `-SkipKubectlProtection` (for kubectl) or by omitting `-RepoPath`.

| Source | What it protects |
|---|---|
| `docker ps -a` | Every image currently bound to a container (running or stopped) |
| `-RepoPath` | Every image referenced as `image: foo:tag` in `docker-compose*.yml` / `compose*.yml` under the path |
| `docker images` shows a `vsc-*` image (VS Code devcontainer build) | Auto-protects `mcr.microsoft.com/devcontainers/*` base images — Docker can't walk a child image's `FROM` chain, so without this Aggressive mode would delete the (14+ GB) base on its own |
| `kubectl config current-context` = `docker-desktop` | Images matching `registry.k8s.io/*`, `docker/desktop-*`, `kindest/node`, `envoyproxy/envoy` |
| `-IgnoreImage <regex>` | Manual user override (any image whose `repo:tag` or ID matches) |

## Parameters

| Name | Type | Default | Notes |
|---|---|---|---|
| `-Mode` | string | `Survey` | One of `Survey`, `Safe`, `Standard`, `Aggressive` |
| `-DryRun` | switch | off | Prints every planned action without executing |
| `-Force` | switch | off | Skip the confirmation prompt |
| `-MaxAgeDays` | int | `30` | Stale-container age cutoff |
| `-IncludeVolumes` | switch | off | Allow volume prune in Standard mode |
| `-IncludeBuildCache` | bool | `$true` | Prune build cache in Standard/Aggressive |
| `-RepoPath` | string[] | `@()` | Repo(s) whose compose files protect images |
| `-IgnoreImage` | string[] | `@()` | Regex patterns to protect |
| `-SkipKubectlProtection` | switch | off | Disable Docker Desktop K8s auto-protection |

## Output

- All actions append to `docker_cleanup.log` next to the script in `.build\`
  (~5 MB rotation, 5 backups). The log file is excluded by `.gitignore`.
- Console output mirrors the log with color-coded INFO / WARN / ERROR.
- A boxed `RUN SUMMARY` is emitted at the end with counts and bytes reclaimed.

## Exit codes

| Code | Meaning |
|---|---|
| `0` | Survey complete, or cleanup ran (possibly with per-item warnings) |
| `2` | Docker daemon not reachable — nothing attempted |

## Safety notes

- **Volumes are opt-in.** Standard mode never touches them unless
  `-IncludeVolumes` is given; Aggressive always prunes unused volumes (warn
  the user).
- **Build cache is pruned aggressively.** `docker builder prune --all --force`
  removes everything not currently in use; this is normally what you want but
  can slow down the very next `docker build` because layers must be re-downloaded.
- **kubectl context detection** is best-effort. If you use a non-`docker-desktop`
  cluster (kind, minikube, AKS) and want its images protected, pass them via
  `-IgnoreImage`. The script does not run `kubectl get pods` to enumerate
  in-use images.
- The script never elevates and never restarts Docker Desktop.

## Recommended workflow for this repo

Because this repository is the active home of several long-lived compose
stacks (`docker-compose.yml`, `docker-compose.api.yml`, etc.) and a
devcontainer, always pass `-RepoPath` so its compose-referenced images
(`rust-api`, `csharp-api`, `worker-service`, `rabbitmq:4.1-management`,
`postgres:*`, etc.) are protected from Aggressive mode.

```powershell
# From the repo root
.\.build\Invoke-DockerCleanup.ps1 `
    -Mode Standard `
    -RepoPath $PWD `
    -MaxAgeDays 30
```

## Files

| File | Purpose |
|---|---|
| `.build\Invoke-DockerCleanup.ps1` | The automation script |
| `.build\docker_cleanup.log[.1-.5]` | Rotated run log (created on first run, gitignored) |
| `.github\copilot\skills\docker-cleanup\SKILL.md` | Copilot CLI skill that drives the script |
| `docs\DockerCleanup.md` | This runbook |
