#Requires -Version 5.1
<#
.SYNOPSIS
    Idempotent Windows 11 & Windows 10 IoT LTSC modern development environment setup script.
.DESCRIPTION
    Compatible with both Windows PowerShell 5.1 (in-box default on Windows 10/11) and PowerShell 7+ (pwsh).
    Strictly avoids PowerShell 7-only syntax operators (? :, ??, ?., &&, ||) so it can bootstrap a fresh machine.
    Automatically self-elevates to Administrator, bootstraps winget on LTSC, and orchestrates modular provisioning steps.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Enforce TLS 1.2 for network downloads in Windows PowerShell 5.1
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[Console]::OutputEncoding = $utf8NoBom
$OutputEncoding = $utf8NoBom

# Ensure unprivileged ExecutionPolicy is set for current process and user
if ((Get-ExecutionPolicy -Scope Process) -ne 'Bypass' -and (Get-ExecutionPolicy -Scope Process) -ne 'Unrestricted') {
    Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force -ErrorAction SilentlyContinue
}
if ((Get-ExecutionPolicy -Scope CurrentUser) -ne 'Unrestricted') {
    Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy Unrestricted -Force -ErrorAction SilentlyContinue
}

# Resolve current script path reliably
$currentScript = $PSCommandPath
if ([string]::IsNullOrWhiteSpace($currentScript)) {
    $currentScript = $MyInvocation.MyCommand.Definition
}
if ([string]::IsNullOrWhiteSpace($currentScript)) {
    $currentScript = $MyInvocation.MyCommand.Path
}

$scriptDir = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($scriptDir) -and (-not [string]::IsNullOrWhiteSpace($currentScript))) {
    $scriptDir = Split-Path -Parent $currentScript
}
if ([string]::IsNullOrWhiteSpace($scriptDir)) {
    throw 'Failed to resolve script directory from $PSScriptRoot or $currentScript.'
}
$repoRoot = Split-Path -Parent $scriptDir

# Resolve Windows 10 vs Windows 11 platform status safely across PS 5.1 and PS 7+
$isWin = ($PSVersionTable.PSEdition -ne 'Core') -or $IsWindows
$isWindows10 = $false
if ($isWin) {
    $osVer = [System.Environment]::OSVersion.Version
    if ($osVer.Major -eq 10 -and $osVer.Build -lt 22000) {
        $isWindows10 = $true
    }
}
$useWinPsBridge = $isWindows10 -and ($PSVersionTable.PSEdition -eq 'Core')

# Self-elevation to Administrator if running under standard user
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
$isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Output 'Administrator privileges required. Requesting elevation...'
    $hostProcess = (Get-Process -Id $PID).Path
    if ([string]::IsNullOrWhiteSpace($hostProcess) -or -not (Test-Path -LiteralPath $hostProcess)) {
        if ($isWindows10) {
            $hostProcess = 'powershell.exe'
        }
        elseif ($PSVersionTable.PSEdition -eq 'Core') {
            $hostProcess = 'pwsh.exe'
        }
        else {
            $hostProcess = 'powershell.exe'
        }
    }
    $elevateArgs = @('-NoLogo', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-NoExit', '-File', $currentScript)
    try {
        $startParams = @{
            FilePath         = $hostProcess
            ArgumentList     = $elevateArgs
            Verb             = 'RunAs'
            WorkingDirectory = (Get-Location).Path
        }
        Start-Process @startParams
    }
    catch {
        Write-Error "Elevation failed or was cancelled by user: $($_.Exception.Message)"
    }
    exit
}

# Ensure persistent ExecutionPolicy for machine and user levels
if ((Get-ExecutionPolicy -Scope CurrentUser) -ne 'Unrestricted') {
    Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy Unrestricted -Force -ErrorAction SilentlyContinue
}

# Configure Windows PowerShell 5.1 machine-level registry key safely
$ps51RegistryPath = 'HKLM:\SOFTWARE\Microsoft\PowerShell\1\ShellIds\Microsoft.PowerShell'
if (Test-Path -LiteralPath $ps51RegistryPath) {
    Set-ItemProperty -LiteralPath $ps51RegistryPath -Name 'ExecutionPolicy' -Value 'Unrestricted' -Force -ErrorAction SilentlyContinue
}

# Apply LocalMachine execution policy with graceful fallback for packaged PowerShell (MSIX / Store)
try {
    $isPackagedApp = ($PSHOME -like '*\WindowsApps\*')
    if (-not $isPackagedApp -and ((Get-ExecutionPolicy -Scope LocalMachine) -ne 'Unrestricted')) {
        Set-ExecutionPolicy -Scope LocalMachine -ExecutionPolicy Unrestricted -Force -ErrorAction Stop
    }
}
catch {
    Write-Verbose 'Notice: LocalMachine execution policy is protected in packaged PowerShell. CurrentUser scope is active.'
}

# Enable Windows OS LongPaths support
Set-ItemProperty -LiteralPath 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem' -Name 'LongPathsEnabled' -Value 1 -Type DWord -Force

# Enable App Sideloading and Developer Mode (required for Win10 LTSC Add-AppxPackage)
$appUnlockPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock'
if (-not (Test-Path -LiteralPath $appUnlockPath)) {
    New-Item -Path $appUnlockPath -Force | Out-Null
}
Set-ItemProperty -LiteralPath $appUnlockPath -Name 'AllowAllTrustedApps' -Value 1 -Type DWord -Force
Set-ItemProperty -LiteralPath $appUnlockPath -Name 'AllowDevelopmentWithoutDevLicense' -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue

# Workspace & VP_HOME directory resolution (Fallback to $HOME\_Workspace if E: is absent)
if (Test-Path -LiteralPath 'E:\') {
    $workspaceDir = 'E:\_Workspace'
    $vpHome = 'E:\vite-plus'
}
else {
    $workspaceDir = Join-Path $HOME '_Workspace'
    $vpHome = Join-Path $HOME '.vite-plus'
}
$vpExtraPaths = @(
    (Join-Path $vpHome 'bin'),
    (Join-Path $HOME '.vite-plus\bin')
)

# Load declarative manifest and Windows provisioning modules
$windowsModuleDir = Join-Path $scriptDir 'windows'
$packagesDataPath = Join-Path $windowsModuleDir 'Packages.psd1'
$provisioningModulePath = Join-Path $windowsModuleDir 'WindowsProvisioning.psm1'
$wingetModulePath = Join-Path $windowsModuleDir 'WinGetBootstrap.psm1'

foreach ($requiredAsset in @($packagesDataPath, $provisioningModulePath, $wingetModulePath)) {
    if (-not (Test-Path -LiteralPath $requiredAsset -PathType Leaf)) {
        throw "Missing required Windows installer asset: $requiredAsset"
    }
}

$manifest = Import-PowerShellDataFile -LiteralPath $packagesDataPath
foreach ($requiredKey in @('InternalRootCAs', 'CliPackages', 'DesktopPackages', 'AntigravityPlugins')) {
    if (-not $manifest.ContainsKey($requiredKey) -or @($manifest[$requiredKey]).Count -eq 0) {
        throw "Invalid or empty '$requiredKey' entry in $packagesDataPath"
    }
}

Import-Module -Name $provisioningModulePath -Force
Import-Module -Name $wingetModulePath -Force

# ==============================================================================
# Provisioning Steps (1-9)
# ==============================================================================

Write-Output '=== Starting Windows Modern Dev Environment Setup ==='

# 1. Workspace Directory Initialization
if (-not (Test-Path -LiteralPath $workspaceDir)) {
    Write-Output "[1/9] Creating Workspace Directory: $workspaceDir"
    New-Item -ItemType Directory -Force -Path $workspaceDir | Out-Null
}
else {
    Write-Output "[1/9] Workspace Directory verified: $workspaceDir"
}

# 2. Internal Root CAs (Private PKI for *.internal)
Write-Output '[2/9] Checking & Trusting Internal Root CAs...'
foreach ($ca in @($manifest['InternalRootCAs'])) {
    Install-InternalRootCA -Name $ca.Name -Base64Cert $ca.Base64Cert
}

# 3. Vite+ Home & Cache Relocation
Initialize-VitePlusToolchain -VpHome $vpHome -RepoRoot $repoRoot -ExtraPaths $vpExtraPaths

# 4. WinGet Bootstrap & Package Installation
Initialize-Winget -UseWindowsPowerShellBridge:$useWinPsBridge -ExtraPaths $vpExtraPaths
Initialize-MicrosoftStore -UseWindowsPowerShellBridge:$useWinPsBridge

Write-Output '[4/9] Checking & Installing Modern CLI Tools and Desktop Apps...'
foreach ($pkg in @($manifest['CliPackages'])) {
    Install-WingetIdempotent -Id $pkg.Id -Name $pkg.Name
}
foreach ($pkg in @($manifest['DesktopPackages'])) {
    Install-WingetIdempotent -Id $pkg.Id -Name $pkg.Name
}

$edgeInstalled = @(& winget list --id Microsoft.Edge -e --accept-source-agreements --disable-interactivity 2>$null)
if ($edgeInstalled -match 'Microsoft\.Edge') {
    $edgePinned = @(& winget pin list --id Microsoft.Edge --accept-source-agreements 2>$null)
    if (-not ($edgePinned -match 'Microsoft\.Edge')) {
        & winget pin add --id Microsoft.Edge --blocking 2>$null | Out-Null
    }
}
Sync-SessionPath -ExtraPaths $vpExtraPaths

# 5. Global Git Configuration & Pre-Commit Safety Hook
Write-Output '[5/9] Configuring Global Git Settings & Pre-Commit Hook...'
Set-GlobalGitConfiguration -RepoRoot $repoRoot

# 6. Windows Terminal & VS Code Configuration
Write-Output '[6/9] Configuring Terminal Defaults to PowerShell 7...'
Set-TerminalAndCodeConfiguration

# 7. PowerShell Profiles Setup ($PROFILE for PowerShell 7 and Windows PowerShell 5.1)
Write-Output '[7/9] Setting up PowerShell Profile...'
Set-PowerShellProfileAndAnalyzer

# 8. Sync Antigravity Plugins (common-modern-tools, windows-modern-tools & modern-web-stack)
Write-Output '[8/9] Syncing Antigravity Plugins...'
Sync-AntigravityPlugin -RepoRoot $repoRoot -PluginNames @($manifest['AntigravityPlugins'])

# 9. Register Repository CLI Directory & Prune Stale User PATH
Write-Output '[9/9] Registering CLI Directory and Pruning Stale User PATH Entries...'
Register-RepositoryCliPath -RepoRoot $repoRoot -VpHome $vpHome

Write-Output '=== Setup Completed Successfully! ==='
