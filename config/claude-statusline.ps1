# PowerShell Claude Code Status Line — TLD Platform
# Line 1: [hostname] · dir · branch (if git) · model
# Line 2: ████░░░░░░ XX% context · $X.XX · Xm · +N/-N lines

# Read JSON payload from stdin
$INPUT_DATA = $Input | Out-String
if (-not $INPUT_DATA) {
    $INPUT_DATA = [Console]::In.ReadToEnd()
}

if (-not $INPUT_DATA) {
    exit 0
}

try {
    $InputJson = $INPUT_DATA | ConvertFrom-Json
} catch {
    exit 0
}

# ── Parse JSON fields ──────────────────────────────────────
$Model = if ($InputJson.model.display_name) { $InputJson.model.display_name } else { "Claude" }
$PctRaw = if ($InputJson.context_window.used_percentage) { $InputJson.context_window.used_percentage } else { 0 }
$Cost = if ($InputJson.cost.total_cost_usd) { $InputJson.cost.total_cost_usd } else { 0 }
$DurationMs = if ($InputJson.cost.total_duration_ms) { $InputJson.cost.total_duration_ms } else { 0 }
$LinesAdd = if ($InputJson.cost.total_lines_added) { $InputJson.cost.total_lines_added } else { 0 }
$LinesDel = if ($InputJson.cost.total_lines_removed) { $InputJson.cost.total_lines_removed } else { 0 }
$Cwd = if ($InputJson.cwd) { $InputJson.cwd } else { "." }

# ── Runtime values ────────────────────────────────────────
$HostName = [System.Net.Dns]::GetHostName()
$Dir = Split-Path -Leaf $Cwd

# ── Sanitize percentage ───────────────────────────────────
$Pct = [math]::Min(100, [math]::Max(0, [int]$PctRaw))

# ── ANSI colors ───────────────────────────────────────────
$esc = [char]27
$G = "$esc[32m"   # green
$Y = "$esc[33m"   # yellow
$R = "$esc[31m"   # red
$B = "$esc[1m"    # bold
$D = "$esc[2m"    # dim
$Z = "$esc[0m"    # reset

# ── Context bar color (conservative thresholds) ──────────
$Color = if ($Pct -lt 50) { $G } elseif ($Pct -lt 75) { $Y } else { $R }

# ── Progress bar (10 segments) ────────────────────────────
$Filled = [math]::Min(10, [int][math]::Floor($Pct * 10 / 100))
$Empty = 10 - $Filled
$Bar = ("█" * $Filled) + ("░" * $Empty)

# ── Duration formatting ──────────────────────────────────
$Ds = [int]($DurationMs / 1000)
$Dm = [int]($Ds / 60)
if ($Dm -ge 60) {
    $Dh = [int]($Dm / 60)
    $Dm = $Dm % 60
    $DFmt = "${Dh}h${Dm}m"
} elseif ($Dm -gt 0) {
    $DFmt = "${Dm}m"
} else {
    $DFmt = "${Ds}s"
}

# ── Cost formatting ──────────────────────────────────────
$CFmt = "$" + [string]::Format("{0:N2}", $Cost)

# ── Git branch (5-second cache) ───────────────────────────
$CacheDir = Join-Path $env:TEMP "claude-statusline"
if (-not (Test-Path $CacheDir)) {
    New-Item -ItemType Directory -Force -Path $CacheDir > $null
}

# Generate hash of CWD
$utf8 = [System.Text.Encoding]::UTF8.GetBytes($Cwd)
$md5 = [System.Security.Cryptography.MD5]::Create()
$hashBytes = $md5.ComputeHash($utf8)
$CacheKey = ($hashBytes | ForEach-Object { $_.ToString("x2") }) -join ""
$CacheFile = Join-Path $CacheDir $CacheKey

$GitBranch = ""
$GitStaged = 0
$GitModified = 0
$GitStash = 0

$isGit = $false
try {
    $gitDir = git -C $Cwd rev-parse --git-dir 2>$null
    if ($gitDir) { $isGit = $true }
} catch {}

if ($isGit) {
    $CacheAge = 999
    if (Test-Path $CacheFile) {
        $lastWrite = (Get-Item $CacheFile).LastWriteTime
        $CacheAge = (New-TimeSpan -Start $lastWrite -End (Get-Date)).TotalSeconds
    }

    if ($CacheAge -lt 5) {
        try {
            $cacheData = Get-Content $CacheFile -Raw | ConvertFrom-Json
            $GitBranch = $cacheData.Branch
            $GitStaged = $cacheData.Staged
            $GitModified = $cacheData.Modified
            $GitStash = $cacheData.Stash
        } catch {
            $CacheAge = 999 # force reload on error
        }
    }

    if ($CacheAge -ge 5) {
        try {
            $GitBranch = (git -C $Cwd branch --show-current 2>$null).Trim()
            $GitStaged = (git -C $Cwd diff --cached --numstat 2>$null | Measure-Object -Line).Lines
            $GitModified = (git -C $Cwd diff --numstat 2>$null | Measure-Object -Line).Lines
            $GitStash = (git -C $Cwd stash list 2>$null | Measure-Object -Line).Lines
            
            $cacheData = @{
                Branch = $GitBranch
                Staged = $GitStaged
                Modified = $GitModified
                Stash = $GitStash
            }
            $cacheData | ConvertTo-Json | Out-File $CacheFile -Encoding utf8
        } catch {}
    }
}

# ── LINE 1: [hostname] · dir · branch · model ────────────
$Sep = "${D} · ${Z}"
$L1 = "${B}[${HostName}]${Z}${Sep}${Dir}"
if ($GitBranch) {
    $L1 += "${Sep}${GitBranch}"
}
$L1 += "${Sep}${D}${Model}${Z}"
Write-Output $L1

# ── LINE 2: Context bar · cost · duration · LOC ──────────
$L2 = "${Color}${Bar}${Z} ${Color}${Pct}%${Z}"
$L2 += "${Sep}${CFmt}${Sep}${DFmt}"
if ($GitStaged -gt 0 -or $GitModified -gt 0) {
    $L2 += "${Sep}${G}✔ ${GitStaged}${Z} ${Y}✎ ${GitModified}${Z}"
}
if ($LinesAdd -gt 0 -or $LinesDel -gt 0) {
    $L2 += "${Sep}${G}+${LinesAdd}${Z}/${R}-${LinesDel}${Z}"
}
Write-Output $L2
