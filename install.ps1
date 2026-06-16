# install.ps1 — Windows PowerShell installer/updater for toolkit-lite.
#
# Idempotent: run it once to install, re-run any time to update.

param(
    [switch]$Update,
    [string]$Only
)

# Sourcing helpers
$PSScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$PSScriptRoot/lib.ps1"

# ---------------------------------------------------------------------------
# Setup and Parameters
# ---------------------------------------------------------------------------
$Components = @("ssh-git-key", "node", "shell-prompt", "tmux", "cli-tools", "python", "gh", "acli", "docker", "ai-local", "claude-code", "codex", "opencode", "grok", "cursor", "antigravity", "kimi", "agent-settings")

function Want-Component {
    param([string]$Comp)
    if ([string]::IsNullOrEmpty($Only)) { return $true }
    $onlyList = $Only.Split(",")
    return $onlyList -contains $Comp
}

$mode = if ($Update) { "update" } else { "install" }
Write-Log "toolkit-lite — $mode on Windows"

# Verify environment directory exists
$EnvDir = Join-Path $HOME "environment"
if (-not (Test-Path $EnvDir)) {
    Write-Log "creating ~/environment"
    New-Item -ItemType Directory -Force -Path $EnvDir | Out-Null
    Write-Ok "created ~/environment"
} else {
    Write-Ok "~/environment exists"
}

# ---------------------------------------------------------------------------
# Interactive Tool Selection
# ---------------------------------------------------------------------------
$AgentComponents = @("claude-code", "codex", "opencode", "grok", "cursor", "antigravity", "kimi")
$Selected = @{}
foreach ($agent in $AgentComponents) {
    $Selected[$agent] = $true
}

$isInteractive = [bool]([Environment]::UserInteractive -and -not $Update -and [string]::IsNullOrEmpty($Only))

if ($isInteractive) {
    # Keep standard UI toggling
    while ($true) {
        Clear-Host
        Write-Log "Agentic CLI Tool Selection"
        Write-Host "Choose which agentic CLIs you would like to install/update."
        Write-Host "Toggle options by entering their number, or press [Enter] to install selected:`n"
        
        for ($i = 0; $i -lt $AgentComponents.Count; $i++) {
            $comp = $AgentComponents[$i]
            $status = if ($Selected[$comp]) { "[X]" } else { "[ ]" }
            Write-Host ("  {0} {1}) {2}" -f $status, ($i + 1), $comp)
        }
        Write-Host ""
        $choice = Read-Host "Enter number to toggle, or press [Enter] to confirm"
        if ([string]::IsNullOrEmpty($choice)) {
            break
        }
        
        $val = 0
        if ([int]::TryParse($choice, [ref]$val) -and $val -ge 1 -and $val -le $AgentComponents.Count) {
            $comp = $AgentComponents[$val - 1]
            $Selected[$comp] = -not $Selected[$comp]
        } else {
            Write-Warn "Invalid choice. Enter a number between 1 and $($AgentComponents.Count), or press Enter."
            Start-Sleep -Seconds 1
        }
    }
}

# ---------------------------------------------------------------------------
# Installer Definitions
# ---------------------------------------------------------------------------
$Installers = @{}

# ssh-git-key
$Installers["ssh-git-key"] = {
    Write-Log "ssh-git-key: setting up SSH key for Git..."
    $SshDir = Join-Path $HOME ".ssh"
    if (-not (Test-Path $SshDir)) {
        New-Item -ItemType Directory -Force -Path $SshDir | Out-Null
    }
    
    $StateDir = Join-Path $HOME ".config\toolkit-lite"
    $StateFile = Join-Path $StateDir "preferred-name"
    $prefName = ""
    if (Test-Path $StateFile) {
        $prefName = (Get-Content $StateFile -TotalCount 1).Trim()
    }
    $chosenUser = if ($prefName) { $prefName } else { $env:USERNAME.ToLower() }
    
    $PrivKey = Join-Path $SshDir "dev-key-$chosenUser.priv"
    $PubKey = Join-Path $SshDir "dev-key-$chosenUser.pub"
    
    $existingKey = $null
    if (Test-Path (Join-Path $SshDir "dev-key.priv")) {
        $existingKey = Join-Path $SshDir "dev-key.priv"
    } else {
        $keys = Get-ChildItem (Join-Path $SshDir "dev-key-*.priv") -ErrorAction SilentlyContinue
        if ($keys) { $existingKey = $keys[0].FullName }
    }
    
    if ($existingKey) {
        $PrivKey = $existingKey
        $PubKey = $existingKey.Replace(".priv", ".pub")
        Write-Ok "ssh: dev-key already exists at $PrivKey — leaving the key as-is"
    } else {
        $ans = "Y"
        if ($isInteractive) {
            $ans = Read-Host "No git SSH key found. Generate one now (for GitHub/Bitbucket/etc)? [Y/n]"
            if ([string]::IsNullOrEmpty($ans)) { $ans = "Y" }
        }
        if ($ans -like "n*") {
            Write-Log "ssh: skipped key generation"
            return $true
        }
        
        $defaultComment = "$chosenUser@$env:COMPUTERNAME-dev-key"
        $comment = $defaultComment
        if ($isInteractive) {
            $inComment = Read-Host "Label/email to tag the key with [$defaultComment]"
            if (-not [string]::IsNullOrEmpty($inComment)) { $comment = $inComment }
        }
        
        Write-Log "ssh: generating ed25519 key (no passphrase)..."
        if (-not (Confirm-Command "ssh-keygen")) {
            Write-Warn "ssh-keygen not found. Make sure Git is installed and on PATH."
            return $false
        }
        
        & ssh-keygen -t ed25519 -f $PrivKey -C $comment -N "" | Out-Null
        if (Test-Path "$PrivKey.pub") {
            Move-Item "$PrivKey.pub" $PubKey -Force
        }
        Write-Ok "ssh: dev-key created at $PrivKey"
    }
    
    try {
        $agent = Get-Service ssh-agent -ErrorAction SilentlyContinue
        if ($agent) {
            if ($agent.Status -ne "Running") {
                Set-Service ssh-agent -StartupType Automatic -ErrorAction SilentlyContinue
                Start-Service ssh-agent -ErrorAction SilentlyContinue
            }
            & ssh-add $PrivKey 2>$null
            Write-Ok "ssh: key added to ssh-agent"
        }
    } catch {
        Write-Warn "ssh-agent service start failed. Try running PowerShell as Administrator if you want to automatically start the SSH Agent service."
    }
    
    $ConfigFile = Join-Path $SshDir "config"
    if (-not (Test-Path $ConfigFile)) {
        New-Item -ItemType File -Force -Path $ConfigFile | Out-Null
    }
    
    $gitHosts = @("github.com", "bitbucket.org")
    $configContent = ""
    if (Test-Path $ConfigFile) { $configContent = Get-Content $ConfigFile -Raw }
    
    foreach ($hostName in $gitHosts) {
        if ($configContent -match "Host\s+$hostName") {
            if ($configContent -match "IdentityFile.*dev-key") {
                Write-Ok "ssh: $hostName block already points at dev-key — leaving it"
            } else {
                Write-Warn "ssh: $hostName block exists but does not point to dev-key. Please manually configure it in $ConfigFile."
            }
        } else {
            $block = @"

Host $hostName
  HostName $hostName
  User git
  IdentityFile $PrivKey
  AddKeysToAgent yes
"@
            Add-Content $ConfigFile $block
            Write-Ok "ssh: added $hostName block to $ConfigFile"
        }
    }
    
    if (Test-Path $PubKey) {
        $pubContent = Get-Content $PubKey -Raw
        Set-Clipboard -Value $pubContent.Trim()
        Write-Ok "ssh: public key copied to your clipboard — just paste it in!"
        Write-Host "`n  Public Key Content:`n  $($pubContent.Trim())`n"
    }
    
    $gitName = & git config --global user.name 2>$null
    $gitEmail = & git config --global user.email 2>$null
    if ([string]::IsNullOrEmpty($gitName) -or [string]::IsNullOrEmpty($gitEmail)) {
        if ($isInteractive) {
            Write-Log "Git Commit Attribution"
            $defaultGitName = if ($gitName) { $gitName } else { $chosenUser }
            $defaultGitEmail = if ($gitEmail) { $gitEmail } else { "$chosenUser@$env:COMPUTERNAME.local" }
            
            $inGitName = Read-Host "Git user name [$defaultGitName]"
            $chosenGitName = if ($inGitName) { $inGitName } else { $defaultGitName }
            
            $inGitEmail = Read-Host "Git email address [$defaultGitEmail]"
            $chosenGitEmail = if ($inGitEmail) { $inGitEmail } else { $defaultGitEmail }
            
            & git config --global user.name $chosenGitName
            & git config --global user.email $chosenGitEmail
            Write-Ok "Git configured: $chosenGitName <$chosenGitEmail>"
        }
    }
    return $true
}

# node
$Installers["node"] = {
    Write-Log "node: installing/updating Node.js..."
    $success = Install-WingetPackage "OpenJS.NodeJS.LTS" "node"
    if ($success) {
        try {
            & npm install -g npm@latest --silent 2>$null
            Write-Ok "npm: updated to latest"
        } catch {}
        return $true
    }
    return $false
}

# shell-prompt
$Installers["shell-prompt"] = {
    Write-Log "shell-prompt: setting up PowerShell colored prompt..."
    
    $StateDir = Join-Path $HOME ".config\toolkit-lite"
    if (-not (Test-Path $StateDir)) {
        New-Item -ItemType Directory -Force -Path $StateDir | Out-Null
    }
    
    $chosenUser = $env:USERNAME.ToLower()
    if ($isInteractive) {
        $inUser = Read-Host "Prompt username (lowercase recommended) [$chosenUser]"
        if (-not [string]::IsNullOrEmpty($inUser)) { $chosenUser = $inUser }
    }
    Set-Content (Join-Path $StateDir "preferred-name") $chosenUser
    
    $ProfileFile = $PROFILE
    if (-not (Test-Path (Split-Path $ProfileFile))) {
        New-Item -ItemType Directory -Force -Path (Split-Path $ProfileFile) | Out-Null
    }
    if (-not (Test-Path $ProfileFile)) {
        New-Item -ItemType File -Force -Path $ProfileFile | Out-Null
    }
    
    $promptBlock = @"

# >>> toolkit-lite prompt >>>
function prompt {
    `$esc = [char]27
    `$user = "$chosenUser"
    `$hostName = [System.Net.Dns]::GetHostName()
    `$path = `$pwd.Path.Replace(`$HOME, "~")
    Write-Host ("{0}`$user`@`$hostName`:{1}`$path{2} `$ " -f ("`$esc[32m"), ("`$esc[34m"), ("`$esc[0m")) -NoNewline
    return " "
}
# <<< toolkit-lite prompt <<<
"@
    $profileContent = Get-Content $ProfileFile -Raw -ErrorAction SilentlyContinue
    if ($profileContent -match "toolkit-lite prompt") {
        Write-Ok "PowerShell prompt is already configured."
    } else {
        Add-Content $ProfileFile $promptBlock
        Write-Ok "Added colored prompt to PowerShell profile ($ProfileFile)."
    }
    return $true
}

# tmux
$Installers["tmux"] = {
    Write-Warn "tmux is not natively supported on Windows. Skipping native installation."
    Write-Log "Tip: You can use tmux inside Windows Subsystem for Linux (WSL) or MSYS2."
    return $true
}

# cli-tools
$Installers["cli-tools"] = {
    Write-Log "cli-tools: installing everyday CLI utilities..."
    $Tools = @{
        "Git.Git" = "git"
        "BurntSushi.Ripgrep" = "rg"
        "sharkdp.fd" = "fd"
        "junegunn.fzf" = "fzf"
        "sharkdp.bat" = "bat"
        "GNU.Wget" = "wget"
        "GnuPG.GnuPG" = "gpg"
    }
    
    $installed = @()
    foreach ($id in $Tools.Keys) {
        $bin = $Tools[$id]
        if (Install-WingetPackage $id $bin) {
            $installed += $bin
        }
    }
    Write-Ok "cli-tools ready: $($installed -join ' ')"
    return $true
}

# python
$Installers["python"] = {
    Write-Log "python: installing uv + CPython versions..."
    
    Update-EnvPath
    if (-not (Confirm-Command "uv")) {
        Write-Log "Installing uv via astral.sh script..."
        Invoke-RestMethod https://astral.sh/uv/install.ps1 | Invoke-Expression
        Update-EnvPath
    }
    
    if (-not (Confirm-Command "uv")) {
        Write-Die "uv installation failed or not on PATH."
        return $false
    }
    Write-Ok "uv: $(uv --version)"
    
    Write-Log "uv: installing CPython 3.11, 3.12, 3.13..."
    & uv python install 3.11 3.12 3.13
    & uv python install --default 3.12
    
    $uvTools = @("ruff", "ipython", "httpie", "pre-commit")
    foreach ($tool in $uvTools) {
        $list = & uv tool list 2>$null
        if ($list -match "^$tool\s") {
            & uv tool upgrade $tool 2>$null
        } else {
            & uv tool install $tool
        }
    }
    
    Write-Ok "python: CPython versions and global tools installed successfully."
    return $true
}

# gh
$Installers["gh"] = {
    return Install-WingetPackage "GitHub.cli" "gh"
}

# acli
$Installers["acli"] = {
    Write-Warn "acli: Atlassian CLI automated Windows install not supported. Skip."
    return $true
}

# docker
$Installers["docker"] = {
    Write-Log "docker: installing Docker Desktop..."
    return Install-WingetPackage "Docker.DockerDesktop" "docker"
}

# ai-local
$Installers["ai-local"] = {
    Write-Log "ai-local: installing Ollama + Hugging Face CLI..."
    $ollamaOk = Install-WingetPackage "Ollama.Ollama" "ollama"
    
    Update-EnvPath
    if (Confirm-Command "uv") {
        $list = & uv tool list 2>$null
        if ($list -match "huggingface_hub") {
            & uv tool upgrade huggingface_hub 2>$null
        } else {
            & uv tool install "huggingface_hub[cli]"
        }
        Write-Ok "hf: huggingface_hub[cli] ready via uv."
    } elseif (Confirm-Command "pip") {
        & pip install --user -U "huggingface_hub[cli]" | Out-Null
        Write-Ok "hf: huggingface_hub[cli] ready via pip."
    }
    
    Write-Log "mlx: Apple Silicon only — skipping MLX on Windows."
    return $true
}

# claude-code
$Installers["claude-code"] = {
    Write-Log "claude-code: installing Anthropic Claude Code CLI..."
    Invoke-RestMethod https://claude.ai/install.ps1 | Invoke-Expression
    
    $ClaudeDir = Join-Path $HOME ".claude"
    if (-not (Test-Path $ClaudeDir)) {
        New-Item -ItemType Directory -Force -Path $ClaudeDir | Out-Null
    }
    
    $srcStatus = Join-Path $TOOLKIT_LITE_ROOT "config\claude-statusline.ps1"
    $dstStatus = Join-Path $ClaudeDir "statusline.ps1"
    if (Test-Path $srcStatus) {
        Copy-Item $srcStatus $dstStatus -Force
        Write-Ok "claude-code: statusline script copied to $dstStatus"
    }
    
    $settingsFile = Join-Path $ClaudeDir "settings.json"
    $settingsObj = @{}
    if (Test-Path $settingsFile) {
        try {
            $settingsObj = Get-Content $settingsFile -Raw | ConvertFrom-Json -AsHashtable
        } catch {}
    }
    
    $settingsObj["statusLine"] = @{
        type = "command"
        command = "powershell -ExecutionPolicy Bypass -File `"$dstStatus`""
        padding = 1
    }
    
    $settingsObj | ConvertTo-Json -Depth 5 | Out-File $settingsFile -Encoding utf8
    Write-Ok "claude-code: custom statusline configured in settings.json"
    return $true
}

# codex
$Installers["codex"] = {
    Write-Log "codex: installing OpenAI Codex CLI..."
    Require-Command "npm"
    & npm install -g @openai/codex --silent
    if (Confirm-Command "codex") {
        Write-Ok "codex ready: $(codex --version 2>$null)"
        return $true
    }
    return $false
}

# opencode
$Installers["opencode"] = {
    Write-Log "opencode: installing sst/opencode CLI..."
    Require-Command "npm"
    & npm install -g opencode-ai --silent
    if (Confirm-Command "opencode") {
        Write-Ok "opencode ready: $(opencode --version 2>$null)"
        return $true
    }
    return $false
}

# grok
$Installers["grok"] = {
    Write-Log "grok: installing xAI Grok CLI..."
    Invoke-RestMethod https://x.ai/cli/install.ps1 | Invoke-Expression
    return $true
}

# cursor
$Installers["cursor"] = {
    Write-Log "cursor: installing Cursor IDE..."
    return Install-WingetPackage "Anysphere.Cursor" "cursor"
}

# antigravity
$Installers["antigravity"] = {
    Write-Log "antigravity: installing Google Antigravity CLI..."
    Invoke-RestMethod https://antigravity.google/cli/install.ps1 | Invoke-Expression
    return $true
}

# kimi
$Installers["kimi"] = {
    Write-Log "kimi: installing Moonshot Kimi CLI..."
    Invoke-RestMethod https://code.kimi.com/kimi-code/install.ps1 | Invoke-Expression
    return $true
}

# agent-settings
$Installers["agent-settings"] = {
    Write-Log "agent-settings: disabling AI git commit signatures/attribution..."
    
    $ClaudeDir = Join-Path $HOME ".claude"
    $claudeSettings = Join-Path $ClaudeDir "settings.json"
    if (Test-Path $claudeSettings) {
        try {
            $settingsObj = Get-Content $claudeSettings -Raw | ConvertFrom-Json -AsHashtable
            $settingsObj["includeCoAuthoredBy"] = $false
            $settingsObj | ConvertTo-Json -Depth 5 | Out-File $claudeSettings -Encoding utf8
            Write-Ok "agent-settings: Claude includeCoAuthoredBy set to false."
        } catch {
            Write-Warn "agent-settings: Failed to update Claude settings.json."
        }
    }
    
    $CodexDir = Join-Path $HOME ".codex"
    $codexConfig = Join-Path $CodexDir "config.toml"
    if (-not (Test-Path $CodexDir)) {
        New-Item -ItemType Directory -Force -Path $CodexDir | Out-Null
    }
    
    $attributionStr = 'commit_attribution = ""'
    if (Test-Path $codexConfig) {
        $content = Get-Content $codexConfig -Raw
        if ($content -match 'commit_attribution\s*=') {
            $content = $content -replace 'commit_attribution\s*=.*', $attributionStr
        } else {
            $content = $attributionStr + "`r`n" + $content
        }
        Set-Content $codexConfig $content
    } else {
        Set-Content $codexConfig $attributionStr
    }
    Write-Ok "agent-settings: Codex commit_attribution disabled."
    return $true
}

# ---------------------------------------------------------------------------
# Run Components
# ---------------------------------------------------------------------------
$Ran = @()
$Failed = @()

foreach ($c in $Components) {
    if (-not (Want-Component $c)) { continue }
    
    # If it is an agent CLI, check if selected
    if ($AgentComponents -contains $c) {
        if (-not $Selected[$c]) { continue }
    }
    
    Write-Host ""
    $script = $Installers[$c]
    if ($script) {
        try {
            $success = &$script
            if ($success) {
                $Ran += $c
            } else {
                $Failed += $c
                Write-Warn "$c failed"
            }
        } catch {
            $Failed += $c
            Write-Warn "$c threw an error: $_"
        }
    }
}

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
Write-Host ""
Write-Log "summary"
Write-Host ("  installed/updated: {0}" -f ($Ran -join ' '))
if ($Failed.Count -gt 0) {
    Write-Host ("  {0}failed:{1}            {2}" -f $_C_YELLOW, $_C_RESET, ($Failed -join ' '))
}
Write-Host ""
Write-Ok "done. Open a new PowerShell window so the refreshed PATH and profile settings take effect."

if ($Failed.Count -gt 0) {
    exit 1
} else {
    exit 0
}
