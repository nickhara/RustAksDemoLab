---
name: docker-cleanup
description: >-
    Skill for reclaiming local Docker disk space — stale containers, unused
    images, dangling networks, build cache, and (opt-in) volumes — via the
    `Invoke-DockerCleanup.ps1` automation in this repository
    (`.build\Invoke-DockerCleanup.ps1`). Use when the user mentions "clean up
    docker", "docker disk space", "prune docker", "Invoke-DockerCleanup",
    "remove stale containers/images", "reclaim disk", or asks to free up
    Docker resources on this machine. Covers a survey-first preview, tiered
    cleanup (Safe / Standard / Aggressive), auto-protection of in-use and
    repo-referenced images, and a structured post-run summary.
user-invocable: true
---

# Docker cleanup runbook

This skill drives **`.build\Invoke-DockerCleanup.ps1`** (relative to this
repository's root), a safety-first PowerShell tool that surveys local Docker
disk usage and removes stale resources in three escalating tiers. The full
runbook is at [`docs/DockerCleanup.md`](../../../../docs/DockerCleanup.md).

The script auto-protects images that are currently in use; the skill layers
**repo awareness** and **kubectl context awareness** on top so you don't have
to remember which compose files or clusters depend on which images.

## When to use this skill

Trigger when the user asks to:

- "Clean up Docker" / "free up Docker disk space" / "reclaim disk"
- "Prune docker images/containers/cache"
- "Remove stale/exited containers" / "delete unused images"
- "Run DockerCleanup" / "Invoke-DockerCleanup"
- Investigate where Docker disk usage is going

Do NOT use this skill for:

- Stopping or removing **running** containers — those are user-managed
- Removing images in **remote** registries (use `container-security-upgrade`
  for ACR work, or the registry's own UI/CLI)
- Cleaning Docker artifacts inside a container (devcontainer-in-DinD has its
  own daemon — this skill only sees the host)

## Repo / paths

| Thing | Repo-relative |
|---|---|
| Script | `.build\Invoke-DockerCleanup.ps1` |
| Runbook | `docs\DockerCleanup.md` |
| Log file (created on first run; gitignored) | `.build\docker_cleanup.log` |

To resolve the script reliably regardless of cwd, prefer
`Resolve-Path (Join-Path $RepoRoot '.build\Invoke-DockerCleanup.ps1')`.
If you're already standing in the repo root, just use
`.\.build\Invoke-DockerCleanup.ps1`.

## Prerequisite checks (always do these first)

```powershell
# 1. Docker daemon reachable?
docker version --format 'Client: {{.Client.Version}} | Server: {{.Server.Version}}'

# 2. Script visible? (cwd assumed to be repo root)
Test-Path '.\.build\Invoke-DockerCleanup.ps1'

# 3. Active kubectl context (for protection logic)?
kubectl config current-context
```

Resolution table:

| Failure | Fix |
|---|---|
| Docker daemon not running | Start Docker Desktop: `Start-Process "C:\Program Files\Docker\Docker\Docker Desktop.exe" -ArgumentList "-Autostart"` and poll `docker version` for up to 120s. Don't proceed until the server responds. |
| Script path missing | Either the cwd isn't the repo root, or you're in a different repo. `git rev-parse --show-toplevel` to confirm. If you're in another repo, either `cd` to a clone of this repo, or stop and tell the user. |
| `kubectl` not installed | Fine — the script will skip K8s protection automatically. Note this in the report. |

## Recommended workflow

Always run a Survey first, then escalate. Do not jump straight to Aggressive.

### Step 1: Survey (mandatory)

```powershell
# from the repo root
.\.build\Invoke-DockerCleanup.ps1
```

This runs `docker system df` plus a per-resource breakdown, makes no changes,
and exits 0. Use the output to:

1. Read the totals (Images / Containers / Volumes / Build cache) and the
   per-type **reclaimable** number.
2. Identify the biggest fish: usually devcontainer images, build cache, or
   stale compose stacks.
3. Decide which mode to recommend (see decision table below).

### Step 2: Decide the mode

| Situation | Recommend |
|---|---|
| User just wants "the safe stuff" / first run | **Safe** |
| Periodic maintenance / general "clean up Docker" / build cache is large | **Standard** (default for most asks) |
| User explicitly wants maximum reclaim, or disk pressure is high | **Aggressive** (volumes are always pruned; confirm first) |
| Just curious / wants to see what would happen | **Standard** or **Aggressive** with `-DryRun` |

### Step 3: Identify protection scopes

Before running the cleanup, look up:

1. **Active repos with compose files.** Always pass the current repo via
   `-RepoPath` so its `docker-compose*.yml`-referenced images are protected.
   For this repo specifically, that includes `rust-api`, `csharp-api`,
   `worker-service`, `rabbitmq:4.1-management`, and any pinned base images.
   - Quick check: `Get-ChildItem -Recurse -File -Include 'docker-compose*.yml','compose*.yml' -ErrorAction SilentlyContinue | Select-Object FullName`
   - Default to passing `$PWD` if it's the repo root.
   - If the user is also working in other repos with their own compose stacks,
     pass them too: `-RepoPath $PWD,'E:\Code\OtherRepo'`.

2. **Active kubectl context.** If `kubectl config current-context` is
   `docker-desktop`, the script auto-protects Docker Desktop K8s images. For
   `kind-*` / `minikube` contexts, the script does NOT auto-detect — pass the
   relevant image patterns via `-IgnoreImage`, e.g.:
   ```
   -IgnoreImage '^kindest/node','^k8s\.gcr\.io/','^registry\.k8s\.io/'
   ```

3. **Anything the user explicitly told you to keep.** E.g. a custom base
   image they're iterating on. Add to `-IgnoreImage` as a regex.

> **Implicit auto-protections** (no flag needed): images bound to any
> container (running or not); `mcr.microsoft.com/devcontainers/*` whenever a
> `vsc-*` devcontainer image is present locally (Docker can't see a child
> image's `FROM` chain, so Aggressive mode would otherwise delete the multi-GB
> devcontainer base out from under VS Code).

### Step 4: Execute

```powershell
.\.build\Invoke-DockerCleanup.ps1 `
    -Mode Standard `
    -RepoPath $PWD `
    -MaxAgeDays 30
```

The script will prompt for confirmation unless `-Force` is given. In
autonomous/scheduled mode pass `-Force`; otherwise allow the prompt.

### Step 5: Verify and report

After the script exits:

1. Read the boxed `RUN SUMMARY` from the tail of the log:
   ```powershell
   Get-Content '.\.build\docker_cleanup.log' -Tail 60
   ```
2. Run `docker system df` to confirm the new totals.
3. Confirm the running devcontainer (or whatever the user cares about) is
   still up: `docker ps`.

Then synthesize a short markdown report for the user:

```
Docker cleanup @ <timestamp>  (Mode=<mode>)
Reclaimed: <total>
  Images:   <bytes> across <N> removed
  Cache:    <bytes>
  Volumes:  <bytes>
Stale containers removed: <N>
Now using: <total GB> across <image count> images
Protected: <reason summary>
```

## Modes (quick reference)

| Mode | Removes containers (exited > MaxAgeDays) | Removes dangling images | Removes unused unnamed images | Removes unused named images | Prunes build cache | Prunes volumes |
|---|---|---|---|---|---|---|
| Survey | — | — | — | — | — | — |
| Safe | ✓ | ✓ | — | — | — | — |
| Standard | ✓ | ✓ | ✓ | — | ✓ (if `-IncludeBuildCache`) | only if `-IncludeVolumes` |
| Aggressive | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ (always) |

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `docker not reachable` exit 2 | Docker Desktop not started, or WSL2 backend not ready | Start Docker Desktop, wait for it to be healthy, retry |
| `Error response from daemon: conflict: unable to delete <id>` | Image is referenced by a stopped container the script didn't classify as stale (e.g. younger than `-MaxAgeDays`) | Lower `-MaxAgeDays`, or `docker rm <container>` manually first |
| `image is being used by running container` | Auto-protection should have caught it; if it didn't, the container started after the protection scan | Re-run the script |
| `volume in use` during prune | A stopped (but recent) container still references it | The volume prune skips it — safe; revisit later |
| Compose-referenced image got deleted anyway | The compose file path wasn't passed via `-RepoPath`, or the image isn't pulled locally yet | Re-pull (`docker compose pull`) — protection only works on *locally present* images |

## Scheduled / unattended runs

When invoked from a scheduled prompt or by autopilot:

- Always start with **Survey**. If the survey shows < 1 GB reclaimable, stop
  and report — there is nothing to do.
- Use `-Force` to skip the confirmation prompt.
- Default to `-Mode Standard` for routine maintenance. Only escalate to
  Aggressive if the user has previously asked for it or disk pressure is acute.
- Never use `-IncludeVolumes` unattended without the user having explicitly
  opted in beforehand — losing a volume is the worst-case outcome of this skill.
- Always pass `-RepoPath $PWD` from a clone of this repo so its compose
  stacks are protected.

## Things this skill must not do

- **Don't touch running containers.** The skill only ever removes resources
  in exited / dead / dangling states. If the user wants to stop something,
  they ask explicitly.
- **Don't delete volumes by default in Standard mode.** Volume removal is opt-in via
  `-IncludeVolumes`; **Aggressive always prunes unused volumes**, so only recommend it after explicit user confirmation and flag it in the summary.
- **Don't bypass the protection logic.** If a user asks "just delete
  everything", confirm the request and use `-Mode Aggressive -Force`, but never edit the protection lists at runtime.
- **Don't restart Docker Desktop unattended** to "fix" cleanup failures.
  Surface the failure and let the user decide.
- **Don't run on remote daemons.** This is a workstation-cleanup tool. If
  `DOCKER_HOST` is set to a remote engine, stop and confirm with the user.
