#Requires -Version 5.1
Set-StrictMode -Version Latest

function Sync-SessionPath {
    param(
        [string[]]$ExtraPaths = @()
    )

    $machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    $combined = @(
        ($machinePath -split ';') + ($userPath -split ';') |
            ForEach-Object { $_.Trim() } |
            Where-Object { $_ } |
            Select-Object -Unique
    )

    $candidatePaths = @(
        (Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps'),
        'C:\Program Files\Git\cmd',
        'C:\Program Files\PowerShell\7'
    )
    if ($ExtraPaths) {
        $candidatePaths = $candidatePaths + $ExtraPaths
    }

    foreach ($p in $candidatePaths) {
        if (-not [string]::IsNullOrWhiteSpace($p)) {
            if ((Test-Path -LiteralPath $p) -and ($combined -notcontains $p)) {
                $combined += $p
            }
        }
    }
    $env:Path = $combined -join ';'
}

function Save-FileSecure {
    param(
        [Parameter(Mandatory)]
        [string]$Uri,
        [Parameter(Mandatory)]
        [string]$OutFile
    )

    if (Test-Path -LiteralPath $OutFile) {
        Remove-Item -LiteralPath $OutFile -Force -ErrorAction SilentlyContinue
    }
    $success = $false
    if (Get-Command 'curl.exe' -ErrorAction SilentlyContinue) {
        & curl.exe -fSL --retry 3 --retry-delay 2 -o $OutFile $Uri
        if ($LASTEXITCODE -eq 0 -and (Test-Path -LiteralPath $OutFile) -and ((Get-Item -LiteralPath $OutFile).Length -gt 0)) {
            $success = $true
        }
    }
    if (-not $success) {
        Invoke-WebRequest -Uri $Uri -OutFile $OutFile -UseBasicParsing
    }
    if (-not (Test-Path -LiteralPath $OutFile) -or ((Get-Item -LiteralPath $OutFile).Length -eq 0)) {
        throw "Failed to download valid non-empty file from '$Uri' to '$OutFile'."
    }
}

function Install-InternalRootCA {
    param(
        [Parameter(Mandatory)]
        [string]$Name,
        [Parameter(Mandatory)]
        [string]$Base64Cert
    )

    $rawCert = [System.Convert]::FromBase64String($Base64Cert)
    $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2 (, $rawCert)
    $thumbprint = $cert.Thumbprint

    $inUser = @(Get-ChildItem Cert:\CurrentUser\Root -ErrorAction SilentlyContinue | Where-Object { $_.Thumbprint -eq $thumbprint })
    $inMachine = @(Get-ChildItem Cert:\LocalMachine\Root -ErrorAction SilentlyContinue | Where-Object { $_.Thumbprint -eq $thumbprint })
    if ($inUser.Count -gt 0 -or $inMachine.Count -gt 0) {
        Write-Output "      [OK] $Name is already trusted."
        return
    }

    Write-Output "      [+] Trusting $Name ($thumbprint)..."

    $storeLocation = [System.Security.Cryptography.X509Certificates.StoreLocation]::LocalMachine
    $store = New-Object System.Security.Cryptography.X509Certificates.X509Store('Root', $storeLocation)
    try {
        $store.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite)
        $store.Add($cert)
    }
    finally {
        $store.Close()
    }
}

function Initialize-VitePlusToolchain {
    param(
        [Parameter(Mandatory)]
        [string]$VpHome,
        [Parameter(Mandatory)]
        [string]$RepoRoot,
        [string[]]$ExtraPaths = @()
    )

    if ([Environment]::GetEnvironmentVariable('VP_HOME', 'User') -ne $VpHome) {
        Write-Output "[3/9] Setting VP_HOME to $VpHome..."
        [Environment]::SetEnvironmentVariable('VP_HOME', $VpHome, 'User')
        $env:VP_HOME = $VpHome
    }
    $env:VP_NODE_MANAGER = 'yes'
    $env:VP_PM_MANAGER = 'yes'
    if (-not (Get-Command 'vp' -ErrorAction SilentlyContinue)) {
        Write-Output '      Installing Vite+ toolchain...'
        $vpBootstrapScript = Join-Path $env:TEMP "vp-install-$(Get-Random).ps1"
        Save-FileSecure -Uri 'https://vite.plus/ps1' -OutFile $vpBootstrapScript
        try {
            & $vpBootstrapScript
        }
        finally {
            Remove-Item -LiteralPath $vpBootstrapScript -Force -ErrorAction SilentlyContinue
        }
        Sync-SessionPath -ExtraPaths $ExtraPaths
    }
    else {
        Write-Output '[3/9] Vite+ toolchain is ready.'
    }

    if (Get-Command 'vp' -ErrorAction SilentlyContinue) {
        & vp env default lts
        & vp env install lts
        & vp env install pnpm@latest

        $vpPkgJson = Join-Path $VpHome 'current\node_modules\vite-plus\package.json'
        if (-not (Test-Path -LiteralPath $vpPkgJson -PathType Leaf)) {
            $vpVerOut = @(& vp --version 2>$null)
            foreach ($line in $vpVerOut) {
                if ([string]$line -match '^vp v([^\s]+)') {
                    $verPkgJson = Join-Path $VpHome "$($Matches[1])\node_modules\vite-plus\package.json"
                    if (Test-Path -LiteralPath $verPkgJson -PathType Leaf) {
                        $vpPkgJson = $verPkgJson
                    }
                    break
                }
            }
        }

        if (Test-Path -LiteralPath $vpPkgJson -PathType Leaf) {
            $vpPkg = Get-Content -LiteralPath $vpPkgJson -Raw | ConvertFrom-Json
            if ($null -ne $vpPkg.dependencies -and $null -ne $vpPkg.dependencies.PSObject.Properties['oxfmt']) {
                $targetOxfmtVer = ([string]$vpPkg.dependencies.oxfmt).Trim() -replace '^[^0-9]*', ''
                if ($targetOxfmtVer) {
                    $vpOxfmtShim = Join-Path $VpHome 'bin\oxfmt.exe'
                    $currentOxfmtVer = ''
                    if (Test-Path -LiteralPath $vpOxfmtShim -PathType Leaf) {
                        $oxfmtVerOut = @(& $vpOxfmtShim --version 2>$null)
                        foreach ($line in $oxfmtVerOut) {
                            if ([string]$line -match '(\d+\.\d+\.\d+(?:-[^\s]+)?)') {
                                $currentOxfmtVer = $Matches[1]
                                break
                            }
                        }
                    }

                    if ((-not (Test-Path -LiteralPath $vpOxfmtShim -PathType Leaf)) -or ($currentOxfmtVer -ne $targetOxfmtVer)) {
                        Write-Output "      Aligning global oxfmt to $targetOxfmtVer..."
                        & vp install -g "oxfmt@$targetOxfmtVer"
                        Sync-SessionPath -ExtraPaths $ExtraPaths
                    }
                }
            }
        }

        $repoPkgJson = Join-Path $RepoRoot 'package.json'
        $repoLockFile = Join-Path $RepoRoot 'pnpm-lock.yaml'
        if ((Test-Path -LiteralPath $repoPkgJson -PathType Leaf) -and (Test-Path -LiteralPath $repoLockFile -PathType Leaf)) {
            Write-Output '      Installing repository Node.js dependencies via Vite+...'
            & vp -C $RepoRoot install --frozen-lockfile
        }
    }
}

function Set-GlobalGitConfiguration {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$RepoRoot
    )

    if (-not $PSCmdlet.ShouldProcess($HOME, 'Configure global Git settings and hooks')) {
        return
    }

    & git config --global user.name 'Florencea'
    & git config --global user.email 'bearflorencea@gmail.com'
    & git config --global core.editor 'code --wait'
    & git config --global core.quotepath false
    & git config --global core.longpaths true
    & git config --global core.autocrlf false

    $systemSsh = 'C:\Windows\System32\OpenSSH\ssh.exe'
    if (-not (Test-Path -LiteralPath $systemSsh)) {
        Write-Output '      Checking OpenSSH Client Capability...'
        try {
            Add-WindowsCapability -Online -Name 'OpenSSH.Client~~~~0.0.1.0' -ErrorAction Stop | Out-Null
        }
        catch {
            Write-Warning "Could not install OpenSSH Client capability: $_"
        }
    }

    if (Test-Path -LiteralPath $systemSsh) {
        & git config --global core.sshCommand 'C:/Windows/System32/OpenSSH/ssh.exe'
    }
    else {
        & git config --global --unset-all core.sshCommand 2>$null
    }

    & git config --global --unset-all core.fsmonitor 2>$null
    & git config --global --unset-all core.untrackedcache 2>$null
    & git config --global init.defaultBranch main
    & git config --global push.autoSetupRemote true
    & git config --global pull.rebase false
    & git config --global fetch.prune true
    & git config --global http.sslBackend schannel
    & git config --global alias.st 'status -sb'
    & git config --global alias.co 'checkout'
    & git config --global alias.br 'branch'
    & git config --global alias.ci 'commit'
    & git config --global alias.lg "log --color --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit"
    $gitRemoteBase = if (Test-Path -LiteralPath 'D:\') {
        'D:/Data/_GitRemote'
    }
    else {
        ($HOME -replace '\\', '/') + '/_GitRemote'
    }
    & git config --global alias.remote-init "!f() { name=`$(basename `$(pwd)); remote=$gitRemoteBase/`${name}.git; git init --bare `"`$remote`" && git remote add origin `"`$remote`" && git push -u origin --all && git push origin --tags; }; f"

    $gitHooksDir = Join-Path $HOME '.config\git\hooks'
    if (-not (Test-Path -LiteralPath $gitHooksDir)) {
        New-Item -ItemType Directory -Force -Path $gitHooksDir | Out-Null
    }
    $srcPreCommit = Join-Path $RepoRoot 'configs\git\hooks\pre-commit.sh'
    $destPreCommit = Join-Path $gitHooksDir 'pre-commit'
    if (Test-Path -LiteralPath $srcPreCommit) {
        Copy-Item -LiteralPath $srcPreCommit -Destination $destPreCommit -Force
        & git config --global core.hooksPath ($gitHooksDir -replace '\\', '/')
    }
}

function Set-TerminalAndCodeConfiguration {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    if (-not $PSCmdlet.ShouldProcess($env:LOCALAPPDATA, 'Configure Windows Terminal and VS Code defaults')) {
        return
    }
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)

    $wtLocalState = Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState'
    $wtSettings = Join-Path $wtLocalState 'settings.json'
    if (-not (Test-Path -LiteralPath $wtLocalState)) {
        $wtPkg = Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe'
        if (Test-Path -LiteralPath $wtPkg) {
            New-Item -ItemType Directory -Force -Path $wtLocalState | Out-Null
        }
    }

    if (Test-Path -LiteralPath $wtSettings) {
        try {
            $json = Get-Content -LiteralPath $wtSettings -Raw | ConvertFrom-Json
            if ($json.defaultProfile -ne '{574e775e-4f2a-5b96-ac1e-a2962a402336}') {
                $json.defaultProfile = '{574e775e-4f2a-5b96-ac1e-a2962a402336}'
                [System.IO.File]::WriteAllText($wtSettings, ($json | ConvertTo-Json -Depth 10), $utf8NoBom)
            }
        }
        catch {
            Write-Warning "Could not update Windows Terminal settings automatically: $_"
        }
    }
    elseif (Test-Path -LiteralPath $wtLocalState) {
        $initialWt = @{
            '$schema'      = 'https://aka.ms/terminal-profiles-schema'
            defaultProfile = '{574e775e-4f2a-5b96-ac1e-a2962a402336}'
        } | ConvertTo-Json
        [System.IO.File]::WriteAllText($wtSettings, $initialWt, $utf8NoBom)
    }

    $codeUserDir = Join-Path $env:APPDATA 'Code\User'
    if (-not (Test-Path -LiteralPath $codeUserDir)) {
        New-Item -ItemType Directory -Force -Path $codeUserDir | Out-Null
    }
    $codeSettings = Join-Path $codeUserDir 'settings.json'
    if (Test-Path -LiteralPath $codeSettings) {
        # Insert property textually because VS Code settings.json allows JSONC comments and trailing commas unsupported by PS 5.1 ConvertFrom-Json.
        $content = Get-Content -LiteralPath $codeSettings -Raw
        if ($content -notmatch '"terminal\.integrated\.defaultProfile\.windows"') {
            $idx = $content.LastIndexOf('}')
            if ($idx -ge 0) {
                $prefix = $content.Substring(0, $idx).TrimEnd(" `t`r`n")
                $comma = ','
                if ($prefix.EndsWith(',')) {
                    $comma = ''
                }
                $new = "$prefix$comma`r`n  `"terminal.integrated.defaultProfile.windows`": `"PowerShell`"`r`n}`r`n"
                [System.IO.File]::WriteAllText($codeSettings, $new, $utf8NoBom)
            }
        }
    }
    else {
        $initialCode = "{\r\n  `"terminal.integrated.defaultProfile.windows`": `"PowerShell`"\r\n}\r\n"
        [System.IO.File]::WriteAllText($codeSettings, $initialCode, $utf8NoBom)
    }
}

function Set-PowerShellProfileAndAnalyzer {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    if (-not $PSCmdlet.ShouldProcess('PowerShell Profile & PSScriptAnalyzer', 'Configure PowerShell profile and static analyzer')) {
        return
    }
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)

    $docsDir = [Environment]::GetFolderPath('MyDocuments')
    if (-not (Test-Path -LiteralPath $docsDir)) {
        $docsDir = Join-Path $HOME 'Documents'
    }

    $profileDirs = @(
        (Join-Path $docsDir 'PowerShell'),
        (Join-Path $docsDir 'WindowsPowerShell')
    )

    $profileContent = @'
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$env:COLORTERM = 'truecolor'
$env:FORCE_COLOR = '3'
if (Get-Module -ListAvailable -Name PSReadLine) {
    try {
        Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
        Set-PSReadLineKeyHandler -Key 'Shift+Tab' -Function TabCompletePrevious
        Set-PSReadLineOption -PredictionSource History -PredictionViewStyle InlineView -ErrorAction Stop
    }
    catch {
        Write-Verbose "PSReadLine configuration skipped: $($_.Exception.Message)"
    }
}
'@

    foreach ($pDir in $profileDirs) {
        if (-not (Test-Path -LiteralPath $pDir)) {
            New-Item -ItemType Directory -Force -Path $pDir | Out-Null
        }
        $pPath = Join-Path $pDir 'Microsoft.PowerShell_profile.ps1'
        if (Test-Path -LiteralPath $pPath) {
            $existing = Get-Content -LiteralPath $pPath -Raw
            if ($existing.Trim() -ne $profileContent.Trim()) {
                [System.IO.File]::WriteAllText($pPath, $profileContent, $utf8NoBom)
            }
        }
        else {
            [System.IO.File]::WriteAllText($pPath, $profileContent, $utf8NoBom)
        }
    }

    # Ensure PSScriptAnalyzer is installed for PowerShell static analysis.
    # In Windows PowerShell 5.1, PowerShellGet requires NuGet provider (>= 2.8.5.201) to interact with PSGallery.
    if ($PSVersionTable.PSEdition -ne 'Core') {
        $hasNuGet = @(Get-PackageProvider -ListAvailable | Where-Object { $_.Name -eq 'NuGet' -and [Version]$_.Version -ge [Version]'2.8.5.201' })
        if ($hasNuGet.Count -eq 0) {
            try {
                Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Scope CurrentUser -ErrorAction Stop | Out-Null
            }
            catch {
                Write-Warning "Failed to bootstrap NuGet package provider: $($_.Exception.Message)"
            }
        }
    }

    if (-not (Get-Module -ListAvailable -Name PSScriptAnalyzer)) {
        try {
            Install-Module -Name PSScriptAnalyzer -Scope CurrentUser -Force -SkipPublisherCheck -ErrorAction Stop
        }
        catch {
            Write-Warning "Failed to install PSScriptAnalyzer: $($_.Exception.Message)"
        }
    }

    # Also ensure PSScriptAnalyzer is installed for PowerShell 7 (pwsh) when running under 5.1
    if ($PSVersionTable.PSEdition -ne 'Core' -and (Get-Command pwsh -ErrorAction SilentlyContinue)) {
        try {
            pwsh -NoLogo -NoProfile -Command 'if (-not (Get-Module -ListAvailable -Name PSScriptAnalyzer)) { Install-Module -Name PSScriptAnalyzer -Scope CurrentUser -Force -SkipPublisherCheck }'
        }
        catch {
            Write-Warning "Failed to install PSScriptAnalyzer for PowerShell 7: $($_.Exception.Message)"
        }
    }
}

function Sync-AntigravityPlugin {
    param(
        [Parameter(Mandatory)]
        [string]$RepoRoot,
        [Parameter(Mandatory)]
        [string[]]$PluginNames
    )

    $pluginsDestRoot = Join-Path $HOME '.gemini\config\plugins'
    if (-not (Test-Path -LiteralPath $pluginsDestRoot)) {
        New-Item -ItemType Directory -Force -Path $pluginsDestRoot | Out-Null
    }

    # Clean up legacy win11-modern-tools plugin if present to prevent duplicate rules/skills
    $legacyWin11Plugin = Join-Path $pluginsDestRoot 'win11-modern-tools'
    if (Test-Path -LiteralPath $legacyWin11Plugin) {
        Remove-Item -LiteralPath $legacyWin11Plugin -Recurse -Force -ErrorAction SilentlyContinue
    }

    foreach ($pluginName in $PluginNames) {
        $srcPlugin = Join-Path $RepoRoot "plugins\$pluginName"
        $destPlugin = Join-Path $pluginsDestRoot $pluginName
        if (Test-Path -LiteralPath $srcPlugin) {
            if (Test-Path -LiteralPath $destPlugin) {
                Remove-Item -LiteralPath $destPlugin -Recurse -Force -ErrorAction SilentlyContinue
            }
            New-Item -ItemType Directory -Force -Path $destPlugin | Out-Null
            Get-ChildItem -LiteralPath $srcPlugin | ForEach-Object {
                Copy-Item -LiteralPath $_.FullName -Destination $destPlugin -Recurse -Force
            }
        }
    }

    # Clean up legacy standalone rules/skills directories if present
    foreach ($legacyDir in @('rules', 'skills')) {
        $legacyPath = Join-Path $HOME ".gemini\config\$legacyDir"
        if (Test-Path -LiteralPath $legacyPath) {
            Remove-Item -LiteralPath $legacyPath -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

function Register-RepositoryCliPath {
    param(
        [Parameter(Mandatory)]
        [string]$RepoRoot,
        [Parameter(Mandatory)]
        [string]$VpHome
    )

    $legacyCliDir = (Resolve-Path -LiteralPath (Join-Path $RepoRoot 'cli')).Path.TrimEnd('\')
    $cliBinDir = (Resolve-Path -LiteralPath (Join-Path $RepoRoot 'cli\bin')).Path.TrimEnd('\')
    $rawUserPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    $currentUserPath = @()
    if ($rawUserPath) {
        $currentUserPath = @(
            $rawUserPath -split ';' |
                ForEach-Object { $_.Trim().TrimEnd('\') } |
                Where-Object {
                    if (-not $_) {
                        return $false
                    }
                    if ($_ -eq $legacyCliDir) {
                        Write-Output "Removed legacy $legacyCliDir from User PATH."
                        return $false
                    }
                    $expanded = [Environment]::ExpandEnvironmentVariables($_)
                    Test-Path -LiteralPath $expanded
                }
        )
    }

    $vpBinDir = (Join-Path $VpHome 'bin').TrimEnd('\')
    if ((Test-Path -LiteralPath $vpBinDir -PathType Container) -and ($currentUserPath -notcontains $vpBinDir)) {
        $currentUserPath = @($vpBinDir) + $currentUserPath
        Write-Output "Added $vpBinDir to User PATH."
    }

    if ($currentUserPath -notcontains $cliBinDir) {
        $currentUserPath += $cliBinDir
        Write-Output "Added $cliBinDir to User PATH."
    }

    $cleanPath = ($currentUserPath | Select-Object -Unique) -join ';'
    [Environment]::SetEnvironmentVariable('Path', $cleanPath, 'User')
}

Export-ModuleMember -Function @(
    'Initialize-VitePlusToolchain',
    'Install-InternalRootCA',
    'Register-RepositoryCliPath',
    'Save-FileSecure',
    'Set-GlobalGitConfiguration',
    'Set-PowerShellProfileAndAnalyzer',
    'Set-TerminalAndCodeConfiguration',
    'Sync-AntigravityPlugin',
    'Sync-SessionPath'
)
