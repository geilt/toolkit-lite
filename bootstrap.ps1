# bootstrap.ps1 — one-line remote installer for toolkit-lite on Windows.
#
# Run it straight from GitHub:
#
#   Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12; iex ((New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/geilt/toolkit-lite/main/bootstrap.ps1'))
#
# It clones (or updates) the repo into ~/environment/toolkit-lite, then runs
# .\install.ps1.

$RepoUrl = "https://github.com/geilt/toolkit-lite.git"
$Dest = Join-Path $HOME "environment\toolkit-lite"

function Write-Say {
    param([string]$Message)
    Write-Host ("`e[36m==>`e[0m {0}" -f $Message)
}

function Write-Die {
    param([string]$Message)
    Write-Error ("`e[31mxx`e[0m {0}" -f $Message)
    exit 1
}

# 1. Ensure git is installed.
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Say "git not found — attempting to install Git via winget..."
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        # Run winget installation for Git
        $process = Start-Process winget -ArgumentList "install --id Git.Git --exact --silent --accept-package-agreements --accept-source-agreements" -NoNewWindow -PassThru -Wait
        
        # Refresh Path
        $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
        $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
        $env:Path = "$userPath;$machinePath"
    }
    
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-Die "git is required but could not be installed automatically. Please install Git for Windows (https://gitforwindows.org/) and try again."
    }
}

# 2. Clone fresh, or update an existing checkout.
$DestParent = Split-Path $Dest
if (-not (Test-Path $DestParent)) {
    New-Item -ItemType Directory -Force -Path $DestParent | Out-Null
}

if (Test-Path (Join-Path $Dest ".git")) {
    Write-Say "updating existing checkout at $Dest"
    try {
        & git -C $Dest pull --ff-only
    } catch {
        Write-Say "git pull failed (local changes?) — continuing with the current checkout"
    }
} else {
    Write-Say "cloning $RepoUrl → $Dest"
    try {
        & git clone $RepoUrl $Dest
    } catch {
        Write-Die "git clone failed."
    }
}

# 3. Hand off to the installer, passing through any extra args.
Write-Say "running installer"
& "$Dest\install.ps1" $args
