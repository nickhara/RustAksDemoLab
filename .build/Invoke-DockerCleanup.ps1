#requires -Version 5.1
<#
.SYNOPSIS
    Tiered, safety-first cleanup of local Docker containers, images, volumes,
    networks, and build cache.

.DESCRIPTION
    Surveys Docker disk usage and removes stale resources in three escalating
    tiers (Safe / Standard / Aggressive) plus a default Survey-only mode.

    Auto-protects:
      - Images bound to any container (running or stopped)
      - Images referenced by docker-compose*.yml files under -RepoPath
      - mcr.microsoft.com/devcontainers/* base images when any vsc-* devcontainer image is present
      - Docker Desktop Kubernetes images when current kubectl context is
        'docker-desktop' (override with -SkipKubectlProtection)
      - Anything matching -IgnoreImage (regex array)

    All actions are logged to docker_cleanup.log next to this script (rotated
    at ~5 MB, 5 backups).

.PARAMETER Mode
    Survey      Report only, make no changes (default).
    Safe        Remove exited containers older than -MaxAgeDays, dangling
                images, and unused networks. Volumes and build cache untouched.
    Standard    Safe + remove dangling/untagged (<none>) images + prune build cache.
                Volumes still untouched unless -IncludeVolumes.
    Aggressive  Standard + remove ALL unused images (including named) + prune
                unused volumes (regardless of -IncludeVolumes).

.PARAMETER DryRun
    Print every planned action without executing it. Implies non-destructive.

.PARAMETER Force
    Skip the confirmation prompt before destructive operations.

.PARAMETER MaxAgeDays
    Containers older than this many days are eligible for removal (when in exited / dead / created state).

    Default 30.


.PARAMETER IncludeVolumes
    Allow Standard mode to prune unused named volumes. Aggressive always
    includes volumes regardless of this flag.

.PARAMETER IncludeBuildCache
    Prune build cache in Standard / Aggressive modes. Default $true.

.PARAMETER RepoPath
    One or more paths containing docker-compose*.yml files whose image
    references will be auto-protected. Pass repos you actively work on.

.PARAMETER IgnoreImage
    Array of regex patterns. Any image whose 'repo:tag' or short ID matches
    is protected from removal in all modes.

.PARAMETER SkipKubectlProtection
    Don't auto-protect Docker Desktop K8s images even if the current kubectl
    context is 'docker-desktop'.

.EXAMPLE
    .\Invoke-DockerCleanup.ps1
    Survey only — no changes.

.EXAMPLE
    .\Invoke-DockerCleanup.ps1 -Mode Standard -RepoPath E:\Code\RustAksDemoLab
    Recommended cleanup. Protects images referenced by the lab's compose files.

.EXAMPLE
    .\Invoke-DockerCleanup.ps1 -Mode Aggressive -IncludeVolumes -Force
    Maximum cleanup, unattended.

.NOTES
    Author: Nick Hara (with GitHub Copilot CLI)
    Requires: Docker Desktop / Docker Engine reachable via 'docker' on PATH.
#>
[CmdletBinding()]
param(
    [ValidateSet('Survey', 'Safe', 'Standard', 'Aggressive')]
    [string] $Mode = 'Survey',

    [switch] $DryRun,
    [switch] $Force,

    [int] $MaxAgeDays = 30,

    [switch] $IncludeVolumes,
    [bool]   $IncludeBuildCache = $true,

    [string[]] $RepoPath = @(),
    [string[]] $IgnoreImage = @(),

    [switch] $SkipKubectlProtection
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------

$script:LogFile = Join-Path $PSScriptRoot 'docker_cleanup.log'
$script:LogMaxBytes = 5 * 1024 * 1024
$script:LogBackupCount = 5

function Rotate-Log {
    if (-not (Test-Path $script:LogFile)) { return }
    $size = (Get-Item $script:LogFile).Length
    if ($size -lt $script:LogMaxBytes) { return }

    for ($i = $script:LogBackupCount - 1; $i -ge 1; $i--) {
        $src = "$($script:LogFile).$i"
        $dst = "$($script:LogFile).$($i + 1)"
        if (Test-Path $src) { Move-Item $src $dst -Force }
    }
    Move-Item $script:LogFile "$($script:LogFile).1" -Force
}

function Write-Log {
    param(
        [Parameter(Mandatory)][string] $Message,
        [ValidateSet('INFO', 'WARN', 'ERROR', 'DEBUG')]
        [string] $Level = 'INFO'
    )
    $ts = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    $line = "$ts [$Level] $Message"
    Add-Content -Path $script:LogFile -Value $line
    switch ($Level) {
        'WARN'  { Write-Host $line -ForegroundColor Yellow }
        'ERROR' { Write-Host $line -ForegroundColor Red }
        'DEBUG' { Write-Verbose $line }
        default { Write-Host $line }
    }
}

Rotate-Log

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

function Invoke-Docker {
    param([Parameter(Mandatory, ValueFromRemainingArguments)][string[]] $DockerArgs)


    # Force array output so callers can safely foreach even when docker returns a single line.

    $out = @(& docker @DockerArgs 2>&1)

    if ($LASTEXITCODE -ne 0) {
        throw "docker $($DockerArgs -join ' ') failed: $($out -join [Environment]::NewLine)"

    }
    return $out
}

function ConvertFrom-DockerSize {
    param([string] $Size)
    if ([string]::IsNullOrWhiteSpace($Size)) { return 0L }
    if ($Size -match '^\s*([\d\.]+)\s*([kKmMgGtT]?B)?\s*$') {
        $n = [double]$Matches[1]
        $unit = if ($Matches[2]) { $Matches[2].ToUpperInvariant() } else { '' }
        switch ($unit) {
            'KB' { return [long]($n * 1KB) }
            'MB' { return [long]($n * 1MB) }
            'GB' { return [long]($n * 1GB) }
            'TB' { return [long]($n * 1TB) }
            default { return [long]$n }
        }
    }
    return 0L
}

function Format-Bytes {
    param([long] $Bytes)
    if ($Bytes -ge 1GB) { return "{0:N2} GB" -f ($Bytes / 1GB) }
    if ($Bytes -ge 1MB) { return "{0:N1} MB" -f ($Bytes / 1MB) }
    if ($Bytes -ge 1KB) { return "{0:N0} KB" -f ($Bytes / 1KB) }
    return "$Bytes B"
}

function Confirm-Or-Exit {
    param([string] $Prompt)
    if ($DryRun -or $Force) { return $true }
    $answer = Read-Host "$Prompt [y/N]"
    return $answer -match '^(?i)y(es)?$'
}

# ---------------------------------------------------------------------------
# Discovery
# ---------------------------------------------------------------------------

function Get-DockerSurvey {
    Write-Log "Gathering docker system df..."
    $df = Invoke-Docker system df --format '{{.Type}}|{{.TotalCount}}|{{.Active}}|{{.Size}}|{{.Reclaimable}}'

    $survey = [ordered]@{}
    foreach ($row in $df) {
        $parts = $row -split '\|'
        if ($parts.Count -ge 5) {
            $survey[$parts[0]] = @{
                Total       = [int]$parts[1]
                Active      = [int]$parts[2]
                Size        = $parts[3]
                Reclaimable = $parts[4]
            }
        }
    }
    return $survey
}

function Get-ProtectedImageIds {
    $protectedIds = New-Object System.Collections.Generic.HashSet[string]
    $reasons = @{}

    function Add-ProtectedId($id, $reason) {
        if ([string]::IsNullOrWhiteSpace($id)) { return }
        $short = $id.Substring(0, [Math]::Min(12, $id.Length))
        [void] $protectedIds.Add($short)
        if (-not $reasons.ContainsKey($short)) { $reasons[$short] = @() }
        $reasons[$short] += $reason
    }

    # 1. Images used by any container (running or not)
    $rows = Invoke-Docker ps -a --format '{{.ID}}|{{.Image}}|{{.Status}}'
    foreach ($r in $rows) {
        if ([string]::IsNullOrWhiteSpace($r)) { continue }
        $parts = $r -split '\|'
        $cid = $parts[0]; $img = $parts[1]; $status = $parts[2]
        $imgId = & docker inspect --format '{{.Image}}' $cid 2>$null
        if ($imgId) {
            $imgId = $imgId -replace '^sha256:', ''
            $tag = if ($status -like 'Up *') { "running container '$cid' ($img)" } else { "stopped container '$cid' ($img)" }
            Add-ProtectedId $imgId $tag
        }
    }

    # 2. Images referenced by docker-compose*.yml in user-provided repos
    foreach ($repo in $RepoPath) {
        if (-not (Test-Path $repo)) {
            Write-Log "RepoPath '$repo' does not exist, skipping" -Level WARN
            continue
        }
        $composeFiles = Get-ChildItem $repo -Recurse -File -Include 'docker-compose*.yml', 'docker-compose*.yaml', 'compose*.yml', 'compose*.yaml' -ErrorAction SilentlyContinue
        foreach ($f in $composeFiles) {
            $content = Get-Content $f.FullName -Raw
            # naive 'image: foo:tag' extraction; good enough for protection
            $imgMatches = [regex]::Matches($content, '(?im)^\s*image:\s*[''"]?([^\s''"#]+)')
            foreach ($m in $imgMatches) {
                $ref = $m.Groups[1].Value
                # resolve repo:tag -> image id via docker
                $resolved = & docker image inspect --format '{{.Id}}' $ref 2>$null
                if ($resolved) {
                    $id = $resolved -replace '^sha256:', ''
                    Add-ProtectedId $id "compose ref '$ref' in $($f.FullName)"
                }
            }
        }
    }

    # 3. Devcontainer base images: when any vsc-* image is in use, protect
    #    mcr.microsoft.com/devcontainers/* (the FROM lineage isn't visible to
    #    docker inspect, so we can't walk the parent chain reliably).
    $vscInUse = $false
    $allImageRefs = Invoke-Docker images --format '{{.Repository}}:{{.Tag}}'
    foreach ($img in $allImageRefs) {
        if ($img -like 'vsc-*') { $vscInUse = $true; break }
    }
    if ($vscInUse) {
        Write-Log "Detected vsc-* devcontainer image(s); auto-protecting mcr.microsoft.com/devcontainers/* bases"
        $allImages = Invoke-Docker images --format '{{.ID}}|{{.Repository}}:{{.Tag}}'
        foreach ($row in $allImages) {
            $parts = $row -split '\|'
            $id = $parts[0]; $name = $parts[1]
            if ($name -match '^mcr\.microsoft\.com/devcontainers/') {
                Add-ProtectedId $id "devcontainer base for active vsc-* image '$name'"
            }
        }
    }

    # 4. Docker Desktop Kubernetes images (when current context = docker-desktop)
    if (-not $SkipKubectlProtection) {

        $kctx = $null

        try {
            $kctx = (& kubectl config current-context 2>$null).Trim()
        } catch {
            Write-Log "kubectl not available; skipping Kubernetes image protection." -Level DEBUG
            $kctx = $null
        }
        if ($kctx -eq 'docker-desktop') {
            Write-Log "Kubectl context is 'docker-desktop'; auto-protecting Docker Desktop K8s images"
            $patterns = @(
                '^registry\.k8s\.io/',
                '^docker/desktop-',
                '^kindest/node',
                '^envoyproxy/envoy'
            )
            $allImages = Invoke-Docker images --format '{{.ID}}|{{.Repository}}:{{.Tag}}'
            foreach ($row in $allImages) {
                $parts = $row -split '\|'
                $id = $parts[0]; $name = $parts[1]
                foreach ($p in $patterns) {
                    if ($name -match $p) {
                        Add-ProtectedId $id "docker-desktop K8s image '$name'"
                        break
                    }
                }
            }
        }
    }

    # 5. User-supplied ignore patterns
    if ($IgnoreImage.Count -gt 0) {
        $allImages = Invoke-Docker images --format '{{.ID}}|{{.Repository}}:{{.Tag}}'
        foreach ($row in $allImages) {
            if ([string]::IsNullOrWhiteSpace($row)) { continue }
            $parts = $row -split '\|'
            $id = $parts[0]; $name = $parts[1]
            foreach ($p in $IgnoreImage) {
                try {
                    if ($name -match $p -or $id -match $p) {
                        Add-ProtectedId $id "user ignore pattern '$p'"
                        break
                    }
                } catch {
                    Write-Log "IgnoreImage pattern '$p' is not a valid regex; skipping" -Level WARN
                }
            }
        }
    }

    return [pscustomobject]@{ Ids = $protectedIds; Reasons = $reasons }
}

function Get-StaleContainers {
    param([int] $OlderThanDays)
    $cutoff = (Get-Date).AddDays(-$OlderThanDays)
    $rows = Invoke-Docker ps -a --filter 'status=exited' --filter 'status=dead' --filter 'status=created' `
        --format '{{.ID}}|{{.Names}}|{{.Image}}|{{.Status}}|{{.CreatedAt}}'
    $stale = @()
    foreach ($r in $rows) {
        if ([string]::IsNullOrWhiteSpace($r)) { continue }
        $parts = $r -split '\|'
        $createdRaw = $parts[4]
        $created = $null
        if ([DateTime]::TryParse($createdRaw, [ref] $created)) {
            if ($created -lt $cutoff) {
                $stale += [pscustomobject]@{
                    Id = $parts[0]; Name = $parts[1]; Image = $parts[2]
                    Status = $parts[3]; Created = $created
                }
            }
        }
    }
    return $stale
}

# ---------------------------------------------------------------------------
# Actions
# ---------------------------------------------------------------------------

function Remove-StaleContainers {
    param([object[]] $Stale)
    $Stale = @($Stale | Where-Object { $_ })
    if ($Stale.Count -eq 0) { Write-Log "No stale containers to remove."; return 0 }
    Write-Log "Removing $($Stale.Count) stale container(s) older than $MaxAgeDays days:"
    $Stale | ForEach-Object { Write-Log "  - $($_.Name) [$($_.Image)] $($_.Status)" }
    if ($DryRun) { Write-Log "  [DryRun] skipped removal"; return $Stale.Count }
    $removed = 0
    foreach ($id in ($Stale | ForEach-Object { $_.Id })) {
        $out = & docker rm $id 2>&1
        if ($LASTEXITCODE -eq 0) {
            $removed++
            $out | ForEach-Object { Write-Log "  $_" -Level DEBUG }
        } else {
            Write-Log "  could not remove container ($id): $($out -join [Environment]::NewLine)" -Level WARN
        }
    }
    return $removed
}

function Remove-Images-Unused {
    param(
        [System.Collections.Generic.HashSet[string]] $ProtectedIds,
        [hashtable] $Reasons,
        [switch] $IncludeAll
    )
    $rows = Invoke-Docker images --format '{{.ID}}|{{.Repository}}:{{.Tag}}|{{.Size}}|{{.CreatedSince}}'
    $candidates = @()
    foreach ($r in $rows) {
        if ([string]::IsNullOrWhiteSpace($r)) { continue }
        $parts = $r -split '\|'
        $id = $parts[0]; $name = $parts[1]; $size = $parts[2]; $age = $parts[3]
        if ($ProtectedIds.Contains($id)) {
            Write-Log "  protect $id  $name  (reasons: $($Reasons[$id] -join '; '))" -Level DEBUG
            continue
        }
        if (-not $IncludeAll -and $name -notmatch '<none>') {
            # Standard mode: only remove unnamed (dangling) images by default.
            # Named, unused images need Aggressive mode.
            continue
        }
        $candidates += [pscustomobject]@{ Id = $id; Name = $name; Size = $size; Age = $age }
    }
    }

    # De-dupe by image ID: a single image may have multiple tags/rows in `docker images`.
    $candidates = $candidates | Sort-Object -Property Id -Unique

    if ($candidates.Count -eq 0) {
        Write-Log "No unused images to remove."
        return @{ Count = 0; BytesFreed = 0L }
    }

    $totalBytes = ($candidates | ForEach-Object { ConvertFrom-DockerSize $_.Size } | Measure-Object -Sum).Sum
    Write-Log "Removing $($candidates.Count) image(s), approx $(Format-Bytes $totalBytes):"
    foreach ($c in $candidates) {
        Write-Log "  - $($c.Id)  $($c.Name)  $($c.Size)  ($($c.Age))"
    }
    if ($DryRun) { Write-Log "  [DryRun] skipped removal"; return @{ Count = $candidates.Count; BytesFreed = 0L } }

    $removed = 0
    $bytesFreed = 0L
    foreach ($c in $candidates) {
        $out = & docker rmi $c.Id 2>&1
        if ($LASTEXITCODE -eq 0) {
            $removed++
            $bytesFreed += ConvertFrom-DockerSize $c.Size
            Write-Log "  removed $($c.Id)  $($c.Name)"
        } else {
            Write-Log "  could not remove $($c.Id)  $($c.Name): $($out -join [Environment]::NewLine)" -Level WARN
        }
    }
    return @{ Count = $removed; BytesFreed = $bytesFreed }
}

function Invoke-DockerPrune {
    param(
        [Parameter(Mandatory)][string] $Resource,
        [switch] $All
    )
    $cmdArgs = @($Resource, 'prune', '--force')
    if ($All) { $cmdArgs += '--all' }
    Write-Log "docker $($cmdArgs -join ' ')"
    if ($DryRun) { Write-Log "  [DryRun] skipped"; return 0L }
    $out = & docker @cmdArgs 2>&1
    $out | ForEach-Object { Write-Log "  $_" -Level DEBUG }
    $reclaimedLine = $out | Where-Object { $_ -match '(?i)Total reclaimed space|reclaimed' } | Select-Object -Last 1
    if ($reclaimedLine -and $reclaimedLine -match '([\d\.]+\s*[KMGT]?B)') {
        $bytes = ConvertFrom-DockerSize $Matches[1]
        Write-Log "  reclaimed $(Format-Bytes $bytes)"
        return $bytes
    }
    return 0L
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

Write-Log "================================================================"
Write-Log "Invoke-DockerCleanup starting (Mode=$Mode, DryRun=$DryRun, MaxAgeDays=$MaxAgeDays)"
Write-Log "================================================================"

# 1. Verify docker is reachable
try {
    $ver = & docker version --format '{{.Server.Version}}' 2>&1
    if ($LASTEXITCODE -ne 0) { throw $ver }
    Write-Log "Docker server $ver reachable."
} catch {
    Write-Log "Docker not reachable: $_" -Level ERROR
    exit 2
}

# Guard against accidentally targeting a remote daemon via DOCKER_HOST.

if ($Mode -ne 'Survey' -and -not [string]::IsNullOrWhiteSpace($env:DOCKER_HOST) -and $env:DOCKER_HOST -match '^(?i)(tcp|ssh)://') {

    Write-Log "DOCKER_HOST is set to '$($env:DOCKER_HOST)'; this script can prune remote resources." -Level WARN

    # Never allow -Force to bypass the remote-engine guard. DryRun is still OK.

    $origForce = $Force

    $Force = $false

    try {

        if (-not (Confirm-Or-Exit "Proceed while DOCKER_HOST targets a remote engine")) {

            Write-Log "User declined due to remote DOCKER_HOST; exiting." -Level WARN

            exit 0

        }

    } finally {

        $Force = $origForce

    }

}

# 2. Survey (always run)
Write-Log "--- Survey ---"
$before = Get-DockerSurvey
foreach ($k in $before.Keys) {
    $v = $before[$k]
    Write-Log ("  {0,-14} total={1,4} active={2,4} size={3,-10} reclaimable={4}" -f $k, $v.Total, $v.Active, $v.Size, $v.Reclaimable)
}

if ($Mode -eq 'Survey') {
    Write-Log "Survey-only mode; exiting without changes."
    exit 0
}

# 3. Build protection set
Write-Log "--- Computing protected images ---"
$protected = Get-ProtectedImageIds
Write-Log "Protected $($protected.Ids.Count) image(s)."

# 4. Confirm
if (-not (Confirm-Or-Exit "Proceed with '$Mode' cleanup")) {
    Write-Log "User declined; exiting." -Level WARN
    exit 0
}

# 5. Execute per-mode
$summary = [ordered]@{
    StaleContainersRemoved = 0
    ImagesRemoved          = 0
    BytesFreedImages       = 0L
    BytesFreedCache        = 0L
    BytesFreedVolumes      = 0L
}

$stale = Get-StaleContainers -OlderThanDays $MaxAgeDays
$summary.StaleContainersRemoved = Remove-StaleContainers -Stale $stale

# Unused networks (always safe — only removes those with no attached containers)
$summary.BytesFreedImages += Invoke-DockerPrune -Resource 'network'

if ($Mode -eq 'Safe') {
    $r = Remove-Images-Unused -ProtectedIds $protected.Ids -Reasons $protected.Reasons
    $summary.ImagesRemoved += $r.Count
    $summary.BytesFreedImages += $r.BytesFreed
}

if ($Mode -in 'Standard', 'Aggressive') {
    $includeAll = ($Mode -eq 'Aggressive')
    $r = Remove-Images-Unused -ProtectedIds $protected.Ids -Reasons $protected.Reasons -IncludeAll:$includeAll
    $summary.ImagesRemoved += $r.Count
    $summary.BytesFreedImages += $r.BytesFreed

    if ($IncludeBuildCache) {
        $summary.BytesFreedCache += Invoke-DockerPrune -Resource 'builder' -All
    }
}

if ($Mode -eq 'Aggressive' -or ($Mode -eq 'Standard' -and $IncludeVolumes)) {
    $summary.BytesFreedVolumes += Invoke-DockerPrune -Resource 'volume'
}

# 6. Final survey + summary
Write-Log "--- Final survey ---"
$after = Get-DockerSurvey
$verb = if ($DryRun) { 'planned' } else { 'removed' }
Write-Log "  Stale containers ($verb): $($summary.StaleContainersRemoved)"
Write-Log "  Images ($verb):           $($summary.ImagesRemoved)"
foreach ($k in $after.Keys) {
    $v = $after[$k]
    Write-Log ("  {0,-14} total={1,4} active={2,4} size={3,-10} reclaimable={4}" -f $k, $v.Total, $v.Active, $v.Size, $v.Reclaimable)
}

Write-Log "================================================================"
Write-Log "RUN SUMMARY"
Write-Log "  Stale containers removed: $($summary.StaleContainersRemoved)"
Write-Log "  Images removed:           $($summary.ImagesRemoved)"
Write-Log "  Bytes freed (images+networks): $(Format-Bytes $summary.BytesFreedImages)"
Write-Log "  Bytes freed (cache):      $(Format-Bytes $summary.BytesFreedCache)"
Write-Log "  Bytes freed (volumes):    $(Format-Bytes $summary.BytesFreedVolumes)"
$total = $summary.BytesFreedImages + $summary.BytesFreedCache + $summary.BytesFreedVolumes
Write-Log "  Total freed:              $(Format-Bytes $total)"
Write-Log "================================================================"

exit 0
