# lib.ps1 — shared helpers for toolkit-lite on Windows.
#
# Sourced by install.ps1 and bootstrap.ps1.

# ---------------------------------------------------------------------------
# Colors and Logging
# ---------------------------------------------------------------------------
$esc = [char]27
$_C_CYAN = "$esc[36m"
$_C_GREEN = "$esc[32m"
$_C_YELLOW = "$esc[33m"
$_C_RED = "$esc[31m"
$_C_BOLD = "$esc[1m"
$_C_RESET = "$esc[0m"

function Write-Log {
    param([string]$Message)
    Write-Host ("{0}==>{1} {2}" -f ($_C_CYAN + $_C_BOLD), $_C_RESET, $Message)
}

function Write-Ok {
    param([string]$Message)
    Write-Host ("  {0}ok{1} {2}" -f $_C_GREEN, $_C_RESET, $Message)
}

function Write-Warn {
    param([string]$Message)
    Write-Warning ("{0}!!{1} {2}" -f $_C_YELLOW, $_C_RESET, $Message)
}

function Write-Die {
    param([string]$Message)
    Write-Error ("{0}xx{1} {2}" -f $_C_RED, $_C_RESET, $Message)
    exit 1
}

# ---------------------------------------------------------------------------
# Path and Environment Helpers
# ---------------------------------------------------------------------------
function Update-EnvPath {
    # Refresh the Path environment variable in the current session
    $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $paths = @()
    if ($userPath) { $paths += $userPath -split ';' }
    if ($machinePath) { $paths += $machinePath -split ';' }
    $uniquePaths = $paths | Where-Object { $_ -and (Test-Path -Path $_ -ErrorAction SilentlyContinue) } | Select-Object -Unique
    $env:Path = $uniquePaths -join ';'
}

function Confirm-Command {
    param([string]$Cmd)
    return [bool](Get-Command $Cmd -ErrorAction SilentlyContinue)
}

function Require-Command {
    param([string]$Cmd)
    if (-not (Confirm-Command $Cmd)) {
        Write-Die "missing required command: $Cmd"
    }
}

# ---------------------------------------------------------------------------
# Package Installer (winget)
# ---------------------------------------------------------------------------
function Install-WingetPackage {
    param(
        [string]$PackageId,
        [string]$BinaryName
    )

    # Refresh path to see if it is already installed in this run or previously
    Update-EnvPath

    if (Confirm-Command $BinaryName) {
        Write-Ok "$BinaryName is already installed."
        return $true
    }

    Write-Log "winget: installing package $PackageId..."
    
    # Run winget with standard silent/consent flags
    $process = Start-Process winget -ArgumentList "install --id $PackageId --exact --silent --accept-package-agreements --accept-source-agreements" -NoNewWindow -PassThru -Wait
    
    Update-EnvPath

    if (Confirm-Command $BinaryName) {
        Write-Ok "$BinaryName installed successfully."
        return $true
    } else {
        Write-Warn "Failed to install $PackageId or find $BinaryName on PATH after installation."
        return $false
    }
}

# Setup the root variable
$TOOLKIT_LITE_ROOT = Split-Path -Parent $MyInvocation.MyCommand.Path
$env:TOOLKIT_LITE_ROOT = $TOOLKIT_LITE_ROOT
