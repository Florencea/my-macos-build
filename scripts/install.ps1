#Requires -Version 5.1
<#
.SYNOPSIS
    Idempotent Windows 11 & Windows 10 IoT LTSC modern development environment setup script.
.DESCRIPTION
    Compatible with both Windows PowerShell 5.1 (in-box default on Windows 10/11) and PowerShell 7+ (pwsh).
    Strictly avoids PowerShell 7-only syntax operators (? :, ??, ?., &&, ||) so it can bootstrap a fresh machine.
    Automatically self-elevates to Administrator, bootstraps winget on LTSC, and configures modern toolchains.
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

# ==============================================================================
# Helper Functions (Windows PowerShell 5.1 & PowerShell 7+ Compatible)
# ==============================================================================

function Sync-SessionPath {
    $machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    $combined = @(
        ($machinePath -split ';') + ($userPath -split ';') |
            ForEach-Object { $_.Trim() } |
            Where-Object { $_ } |
            Select-Object -Unique
    )

    $extraPaths = @(
        (Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps'),
        'C:\Program Files\Git\cmd',
        'C:\Program Files\PowerShell\7',
        (Join-Path $vpHome 'bin'),
        (Join-Path $HOME '.vite-plus\bin')
    )
    foreach ($p in $extraPaths) {
        if ((Test-Path -LiteralPath $p) -and ($combined -notcontains $p)) {
            $combined += $p
        }
    }
    $env:Path = $combined -join ';'
}

function Save-FileSecure {
    param(
        [string]$Uri,
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
        [string]$Name,
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

function Get-AppxPackageCompat {
    param(
        [string]$Name,
        [switch]$AllUsers
    )
    if ($isWindows10 -and ($PSVersionTable.PSEdition -eq 'Core')) {
        $allUsersArg = ''
        if ($AllUsers) {
            $allUsersArg = '-AllUsers'
        }
        $cmd = "Get-AppxPackage -Name '$Name' $allUsersArg | Select-Object -Property Name, PackageFullName, InstallLocation | ConvertTo-Json -Compress"
        $rawJson = (& powershell.exe -NoLogo -NoProfile -Command $cmd 2>$null)
        if ($rawJson) {
            try {
                return ($rawJson | ConvertFrom-Json)
            }
            catch {
                return $null
            }
        }
        return $null
    }
    if ($AllUsers) {
        return (Get-AppxPackage -Name $Name -AllUsers -ErrorAction SilentlyContinue)
    }
    return (Get-AppxPackage -Name $Name -ErrorAction SilentlyContinue)
}

function Add-AppxPackageCompat {
    param(
        [string]$Path,
        [string[]]$DependencyPath = @()
    )
    if ($isWindows10 -and ($PSVersionTable.PSEdition -eq 'Core')) {
        $depArgs = ''
        if ($DependencyPath -and ($DependencyPath.Count -gt 0)) {
            $joined = ($DependencyPath | ForEach-Object { "'$_'" }) -join ','
            $depArgs = "-DependencyPath @($joined)"
        }
        $cmd = "Add-AppxPackage -Path '$Path' $depArgs"
        & powershell.exe -NoLogo -NoProfile -Command $cmd
        if ($LASTEXITCODE -ne 0) {
            throw "Add-AppxPackage failed for '$Path'."
        }
        return
    }
    if ($DependencyPath -and ($DependencyPath.Count -gt 0)) {
        Add-AppxPackage -Path $Path -DependencyPath $DependencyPath -ErrorAction Stop
    }
    else {
        Add-AppxPackage -Path $Path -ErrorAction Stop
    }
}

function Add-AppxProvisionedPackageCompat {
    param(
        [string]$PackagePath,
        [string[]]$DependencyPackagePath = @()
    )
    if ($isWindows10 -and ($PSVersionTable.PSEdition -eq 'Core')) {
        $depArgs = ''
        if ($DependencyPackagePath -and ($DependencyPackagePath.Count -gt 0)) {
            $joined = ($DependencyPackagePath | ForEach-Object { "'$_'" }) -join ','
            $depArgs = "-DependencyPackagePath @($joined)"
        }
        $cmd = "Add-AppxProvisionedPackage -Online -PackagePath '$PackagePath' $depArgs -SkipLicense"
        & powershell.exe -NoLogo -NoProfile -Command $cmd | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw "Add-AppxProvisionedPackage failed for '$PackagePath'."
        }
        return
    }
    if ($DependencyPackagePath -and ($DependencyPackagePath.Count -gt 0)) {
        Add-AppxProvisionedPackage -Online -PackagePath $PackagePath -DependencyPackagePath $DependencyPackagePath -SkipLicense -ErrorAction Stop | Out-Null
    }
    else {
        Add-AppxProvisionedPackage -Online -PackagePath $PackagePath -SkipLicense -ErrorAction Stop | Out-Null
    }
}

function Initialize-Winget {
    if (Get-Command 'winget' -ErrorAction SilentlyContinue) {
        return
    }
    $windowsAppsDir = Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps'
    $localAppsWinget = Join-Path $windowsAppsDir 'winget.exe'
    if (Test-Path -LiteralPath $localAppsWinget) {
        if ($env:Path -notmatch [regex]::Escape($windowsAppsDir)) {
            $env:Path = "$windowsAppsDir;$env:Path"
        }
        if (Get-Command 'winget' -ErrorAction SilentlyContinue) {
            return
        }
    }

    Import-Module Appx -ErrorAction SilentlyContinue
    $existingPkg = Get-AppxPackageCompat -Name 'Microsoft.DesktopAppInstaller'
    if ($existingPkg -and $existingPkg.InstallLocation) {
        $pkgWinget = Join-Path $existingPkg.InstallLocation 'winget.exe'
        if (Test-Path -LiteralPath $pkgWinget) {
            if ($env:Path -notmatch [regex]::Escape($existingPkg.InstallLocation)) {
                $env:Path = "$($existingPkg.InstallLocation);$env:Path"
            }
            if (Get-Command 'winget' -ErrorAction SilentlyContinue) {
                return
            }
        }
    }

    Write-Output '      [+] WinGet not detected. Bootstrapping dependencies on Windows 10 LTSC...'

    # Ensure AppX Deployment Service (AppXSvc) is enabled and running
    $appxSvc = Get-Service -Name 'AppXSvc' -ErrorAction SilentlyContinue
    if ($appxSvc) {
        if ($appxSvc.StartType -eq 'Disabled') {
            Write-Output '      Enabling AppXSvc (AppX Deployment Service)...'
            Set-Service -Name 'AppXSvc' -StartupType Manual -ErrorAction SilentlyContinue
        }
        if ($appxSvc.Status -ne 'Running') {
            Write-Output '      Starting AppXSvc service...'
            Start-Service -Name 'AppXSvc' -ErrorAction SilentlyContinue
        }
    }

    $tempDir = Join-Path $env:TEMP "winget-bootstrap-$(Get-Random)"
    New-Item -ItemType Directory -Force -Path $tempDir | Out-Null
    try {
        if ([IntPtr]::Size -eq 8) {
            if ($env:PROCESSOR_ARCHITECTURE -match 'ARM64') {
                $arch = 'arm64'
            }
            else {
                $arch = 'x64'
            }
        }
        else {
            $arch = 'x86'
        }

        # Modern WinGet (v1.28+) depends on VCLibs and Microsoft.WindowsAppRuntime.1.8.
        $depsUrl = 'https://github.com/microsoft/winget-cli/releases/latest/download/DesktopAppInstaller_Dependencies.zip'
        $wingetUrl = 'https://github.com/microsoft/winget-cli/releases/latest/download/Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle'

        $depsZipPath = Join-Path $tempDir 'DesktopAppInstaller_Dependencies.zip'
        $depsExtractDir = Join-Path $tempDir 'Dependencies'
        $wingetPath = Join-Path $tempDir 'Microsoft.DesktopAppInstaller.msixbundle'

        New-Item -ItemType Directory -Force -Path $depsExtractDir | Out-Null

        Write-Output '      Downloading WinGet dependencies archive (VCLibs & WindowsAppRuntime)...'
        Save-FileSecure -Uri $depsUrl -OutFile $depsZipPath

        Write-Output '      Extracting dependencies archive...'
        $extracted = $false
        if (Get-Command 'tar.exe' -ErrorAction SilentlyContinue) {
            & tar.exe -xf $depsZipPath -C $depsExtractDir
            if ($LASTEXITCODE -eq 0) {
                $extracted = $true
            }
        }
        if (-not $extracted) {
            Expand-Archive -Path $depsZipPath -DestinationPath $depsExtractDir -Force
        }

        Write-Output '      Downloading WinGet DesktopAppInstaller package...'
        Save-FileSecure -Uri $wingetUrl -OutFile $wingetPath

        $targetArchDir = Join-Path $depsExtractDir $arch
        $depFiles = @()
        if (Test-Path -LiteralPath $targetArchDir) {
            $depFiles = @(Get-ChildItem -LiteralPath $targetArchDir -Filter '*.appx' | Sort-Object Name)
        }
        else {
            $depFiles = @(
                Get-ChildItem -LiteralPath $depsExtractDir -Recurse -Filter '*.appx' |
                    Where-Object { $_.FullName -match $arch } |
                    Sort-Object Name
            )
        }

        if ($depFiles.Count -eq 0) {
            throw "No matching dependency packages found for architecture: $arch"
        }

        $depPaths = @()
        Write-Output "      Registering framework dependencies ($arch)..."
        foreach ($dep in $depFiles) {
            Write-Output "        - Installing dependency: $($dep.Name)"
            try {
                Add-AppxPackageCompat -Path $dep.FullName
            }
            catch {
                Write-Output "          [Note] $($_.Exception.Message.Trim())"
            }
            $depPaths += $dep.FullName
        }

        Write-Output '      Registering WinGet DesktopAppInstaller package...'
        try {
            if ($depPaths.Count -gt 0) {
                Add-AppxPackageCompat -Path $wingetPath -DependencyPath $depPaths
            }
            else {
                Add-AppxPackageCompat -Path $wingetPath
            }
        }
        catch {
            Write-Output "      [!] Add-AppxPackage failed: $($_.Exception.Message). Falling back to Add-AppxProvisionedPackage..."
            try {
                if ($depPaths.Count -gt 0) {
                    Add-AppxProvisionedPackageCompat -PackagePath $wingetPath -DependencyPackagePath $depPaths
                }
                else {
                    Add-AppxProvisionedPackageCompat -PackagePath $wingetPath
                }
            }
            catch {
                throw "Failed to install WinGet package: $($_.Exception.Message)"
            }
        }

        if (Test-Path -LiteralPath $windowsAppsDir) {
            if ($env:Path -notmatch [regex]::Escape($windowsAppsDir)) {
                $env:Path = "$windowsAppsDir;$env:Path"
            }
        }

        $newPkg = Get-AppxPackageCompat -Name 'Microsoft.DesktopAppInstaller'
        if ($newPkg -and $newPkg.InstallLocation) {
            $pkgWinget = Join-Path $newPkg.InstallLocation 'winget.exe'
            if (Test-Path -LiteralPath $pkgWinget) {
                if ($env:Path -notmatch [regex]::Escape($newPkg.InstallLocation)) {
                    $env:Path = "$($newPkg.InstallLocation);$env:Path"
                }
            }
        }

        Sync-SessionPath

        if (-not (Get-Command 'winget' -ErrorAction SilentlyContinue)) {
            throw "WinGet installed successfully, but 'winget.exe' could not be located in PATH."
        }

        Write-Output '      Initializing WinGet package source agreements...'
        & winget source update --disable-interactivity 2>$null | Out-Null
        Write-Output '      [OK] WinGet bootstrapped successfully.'
    }
    catch {
        Write-Output "      [ERROR] WinGet bootstrap failed: $($_.Exception.Message)"
        throw
    }
    finally {
        if (Test-Path -LiteralPath $tempDir) {
            Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

function Initialize-MicrosoftStore {
    $existing = Get-AppxPackageCompat -Name 'Microsoft.WindowsStore' -AllUsers
    if ($existing) {
        Write-Output '      [OK] Microsoft Store is already installed.'
        return
    }

    Write-Output '      [+] Microsoft Store not detected. Installing Microsoft Store...'
    $installed = $false

    if (Get-Command 'winget' -ErrorAction SilentlyContinue) {
        Write-Output '      Installing Microsoft Store via WinGet (msstore: 9WZDNCRFJBMP)...'
        & winget install --id 9WZDNCRFJBMP --source msstore --exact --accept-package-agreements --accept-source-agreements --disable-interactivity 2>$null
        $check = Get-AppxPackageCompat -Name 'Microsoft.WindowsStore' -AllUsers
        if ($check) {
            $installed = $true
        }
    }

    if (-not $installed -and (Get-Command 'wsreset.exe' -ErrorAction SilentlyContinue)) {
        Write-Output '      Invoking wsreset.exe -i to register Microsoft Store...'
        Start-Process -FilePath 'wsreset.exe' -ArgumentList '-i' -Wait -NoNewWindow -ErrorAction SilentlyContinue
    }

    $finalCheck = Get-AppxPackageCompat -Name 'Microsoft.WindowsStore' -AllUsers
    if ($finalCheck) {
        Write-Output '      [OK] Microsoft Store installed successfully.'
    }
    else {
        Write-Warning 'Microsoft Store installation initiated. It may take a few moments to finish background registration.'
    }
}

function Install-WingetIdempotent {
    param([string]$Id, [string]$Name)
    if ($Id -eq 'AgileBits.1Password') {
        $check1P = & winget list 1Password --accept-source-agreements --disable-interactivity 2>$null
        if ($check1P -match '1Password') {
            Write-Output "      [OK] $Name is already installed."
            return
        }
    }
    $check = & winget list --id $Id -e --accept-source-agreements --disable-interactivity 2>$null
    if ($check -match [regex]::Escape($Id)) {
        Write-Output "      [OK] $Name ($Id) is already installed."
    }
    else {
        Write-Output "      [+] Installing $Name ($Id)..."
        & winget install --id $Id -e --accept-package-agreements --accept-source-agreements --disable-interactivity
    }
}

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

$bhpdRootCaB64 = 'LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUNCRENDQWF1Z0F3SUJBZ0lCQURBS0JnZ3Foa2pPUFFRREFqQThNUXN3Q1FZRFZRUUdFd0pVVnpFTk1Bc0cKQTFVRUNnd0VRa2hRUkRFZU1Cd0dBMVVFQXd3VlFraFFSQ0JKYm5SbGNtNWhiQ0JTYjI5MElFTkJNQjRYRFRJMgpNRGt4T1RFMU1qRXdPVm9YRFRNMk1Ea3hOakUxTWpFd09Wb3dQREVMTUFrR0ExVUVCaE1DVkZjeERUQUxCZ05WCkJBb01CRUpJVUVReEhqQWNCZ05WQkFNTUZVSklVRVFnU1c1MFpYSnVZV3dnVW05dmRDQkRRVEJaTUJNR0J5cUcKU000OUFnRUdDQ3FHU000OUF3RUhBMElBQk95elJsUngvMGR6SjBScDlkYTFiQmdCSmxMbFpqU0NmcFN6ZjBMcQpaeWRjeFo0c1NmWENuTyt4MUhZU1JEa3Y0RGlnYVZwckhaUE1OYldjQ1FsRnBsK2pnWjB3Z1pvd053WUpZSVpJCkFZYjRRZ0VOQkNvV0tFOVFUbk5sYm5ObElFZGxibVZ5WVhSbFpDQkRaWEowYVdacFkyRjBaU0JCZFhSb2IzSnAKZEhrd0hRWURWUjBPQkJZRUZBZitMVWdDeTNKKzEwMEcwdUJHQ1JVWVMvQnRNQjhHQTFVZEl3UVlNQmFBRkFmKwpMVWdDeTNKKzEwMEcwdUJHQ1JVWVMvQnRNQThHQTFVZEV3RUIvd1FGTUFNQkFmOHdEZ1lEVlIwUEFRSC9CQVFECkFnR0dNQW9HQ0NxR1NNNDlCQU1DQTBjQU1FUUNJRmxqSXZKenIyWHJ5Y0FvYzgybVpjU2J3QzRPa1h3NExkQ3IKcU13SlpDWkRBaUJub2xGWjdLRUhtZWlUOU5xYUpmSEtSeW5rMzAwUDhSaDd1eDl2cWZIemNRPT0KLS0tLS1FTkQgQ0VSVElGSUNBVEUtLS0tLQo='
$bhgsRootCaB64 = 'LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUNCVENDQWF1Z0F3SUJBZ0lCQURBS0JnZ3Foa2pPUFFRREFqQThNUXN3Q1FZRFZRUUdFd0pVVnpFTk1Bc0cKQTFVRUNnd0VRa2hIVXpFZU1Cd0dBMVVFQXd3VlFraEhVeUJKYm5SbGNtNWhiQ0JTYjI5MElFTkJNQjRYRFRJMgpNRGt4T1RFMU5UUTBNbG9YRFRNMk1Ea3hOakUxTlRRME1sb3dQREVMTUFrR0ExVUVCaE1DVkZjeERUQUxCZ05WCkJBb01CRUpJUjFNeEhqQWNCZ05WQkFNTUZVSklSMU1nU1c1MFpYSnVZV3dnVW05dmRDQkRRVEJaTUJNR0J5cUcKU000OUFnRUdDQ3FHU000OUF3RUhBMElBQkZGOVk0d0N5TVNnbzNJSjU2QnZOaE12Mnh2a2Y4MC9id2dCOGhILwpFZHhzUktYTS91YjhBWTlldmxaR0VzQlpUZzJaS0ZIT0dMajBpNngyWldUanA3T2pnWjB3Z1pvd053WUpZSVpJCkFZYjRRZ0VOQkNvV0tFOVFUbk5sYm5ObElFZGxibVZ5WVhSbFpDQkRaWEowYVdacFkyRjBaU0JCZFhSb2IzSnAKZEhrd0hRWURWUjBPQkJZRUZHMGU4VXdmZERWTlJ1N3RodXh1TmhmRVk0RG1NQjhHQTFVZEl3UVlNQmFBRkcwZQo4VXdmZERWTlJ1N3RodXh1TmhmRVk0RG1NQThHQTFVZEV3RUIvd1FGTUFNQkFmOHdEZ1lEVlIwUEFRSC9CQVFECkFnR0dNQW9HQ0NxR1NNNDlCQU1DQTBnQU1FVUNJUUNmd0JISXNaTVdHWUZEbVNFNHVuQlNlUUZidkZLMzU0NHUKQ1hadVYwRlhTd0lnR0hwRDVWMGN4RmluS2VtenJVMU1ZQklpZXB0SnVEVmFQSnVhK2Qya3JHST0KLS0tLS1FTkQgQ0VSVElGSUNBVEUtLS0tLQo='

Install-InternalRootCA -Name 'BHPD Internal Root CA' -Base64Cert $bhpdRootCaB64
Install-InternalRootCA -Name 'BHGS Internal Root CA' -Base64Cert $bhgsRootCaB64

# 3. Vite+ Home & Cache Relocation
if ([Environment]::GetEnvironmentVariable('VP_HOME', 'User') -ne $vpHome) {
    Write-Output "[3/9] Setting VP_HOME to $vpHome..."
    [Environment]::SetEnvironmentVariable('VP_HOME', $vpHome, 'User')
    $env:VP_HOME = $vpHome
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
    Sync-SessionPath
}
else {
    Write-Output '[3/9] Vite+ toolchain is ready.'
}

if (Get-Command 'vp' -ErrorAction SilentlyContinue) {
    & vp env default lts
    & vp env install lts
    & vp env install pnpm@latest

    $vpPkgJson = Join-Path $vpHome 'current\node_modules\vite-plus\package.json'
    if (-not (Test-Path -LiteralPath $vpPkgJson -PathType Leaf)) {
        $vpVerOut = @(& vp --version 2>$null)
        foreach ($line in $vpVerOut) {
            if ([string]$line -match '^vp v([^\s]+)') {
                $verPkgJson = Join-Path $vpHome "$($Matches[1])\node_modules\vite-plus\package.json"
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
                $vpOxfmtShim = Join-Path $vpHome 'bin\oxfmt.exe'
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
                    Sync-SessionPath
                }
            }
        }
    }

    $repoPkgJson = Join-Path $repoRoot 'package.json'
    $repoLockFile = Join-Path $repoRoot 'pnpm-lock.yaml'
    if ((Test-Path -LiteralPath $repoPkgJson -PathType Leaf) -and (Test-Path -LiteralPath $repoLockFile -PathType Leaf)) {
        Write-Output '      Installing repository Node.js dependencies via Vite+...'
        & vp -C $repoRoot install --frozen-lockfile
    }
}

# 4. WinGet Bootstrap & Package Installation
Initialize-Winget
Initialize-MicrosoftStore

Write-Output '[4/9] Checking & Installing Modern CLI Tools and Desktop Apps...'

$cliPackages = @(
    @{ Id = 'Microsoft.PowerShell'; Name = 'PowerShell 7' },
    @{ Id = 'BurntSushi.ripgrep.MSVC'; Name = 'ripgrep (rg)' },
    @{ Id = 'sharkdp.fd'; Name = 'fd' },
    @{ Id = 'ast-grep.ast-grep'; Name = 'ast-grep' },
    @{ Id = 'jqlang.jq'; Name = 'jq' },
    @{ Id = 'MikeFarah.yq'; Name = 'yq' },
    @{ Id = 'sharkdp.bat'; Name = 'bat' },
    @{ Id = 'chmln.sd'; Name = 'sd' },
    @{ Id = 'mvdan.shfmt'; Name = 'shfmt' },
    @{ Id = 'oschwartz10612.Poppler'; Name = 'Poppler (pdftotext)' },
    @{ Id = 'XAMPPRocky.Tokei'; Name = 'tokei' },
    @{ Id = 'BurntSushi.xsv.MSVC'; Name = 'xsv' },
    @{ Id = 'SQLite.SQLite'; Name = 'SQLite (sqlite3)' },
    @{ Id = 'ducaale.xh'; Name = 'xh' },
    @{ Id = 'bootandy.dust'; Name = 'dust' },
    @{ Id = 'DuckDB.cli'; Name = 'DuckDB CLI' },
    @{ Id = 'rhysd.actionlint'; Name = 'actionlint' },
    @{ Id = 'sharkdp.hyperfine'; Name = 'hyperfine' },
    @{ Id = 'Gyan.FFmpeg'; Name = 'FFmpeg' },
    @{ Id = 'yt-dlp.yt-dlp'; Name = 'yt-dlp' },
    @{ Id = 'AgileBits.1Password.CLI'; Name = '1Password CLI (op)' }
)
foreach ($pkg in $cliPackages) {
    Install-WingetIdempotent -Id $pkg.Id -Name $pkg.Name
}

$desktopPackages = @(
    @{ Id = 'Git.Git'; Name = 'Git for Windows' },
    @{ Id = 'Microsoft.VisualStudioCode'; Name = 'Visual Studio Code' },
    @{ Id = 'Microsoft.WindowsTerminal'; Name = 'Windows Terminal' },
    @{ Id = 'AgileBits.1Password'; Name = '1Password' },
    @{ Id = 'RevoUninstaller.RevoUninstaller'; Name = 'Revo Uninstaller' },
    @{ Id = 'M2Team.NanaZip'; Name = 'NanaZip' },
    @{ Id = 'ImageOptim.gifski'; Name = 'gifski' }
)
foreach ($pkg in $desktopPackages) {
    Install-WingetIdempotent -Id $pkg.Id -Name $pkg.Name
}

& winget pin add --id Microsoft.Edge --blocking 2>$null | Out-Null

Sync-SessionPath

# 5. Global Git Configuration & Pre-Commit Safety Hook
Write-Output '[5/9] Configuring Global Git Settings & Pre-Commit Hook...'

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
$srcPreCommit = Join-Path $repoRoot 'configs\git\hooks\pre-commit.sh'
$destPreCommit = Join-Path $gitHooksDir 'pre-commit'
if (Test-Path -LiteralPath $srcPreCommit) {
    Copy-Item -LiteralPath $srcPreCommit -Destination $destPreCommit -Force
    & git config --global core.hooksPath ($gitHooksDir -replace '\\', '/')
}

# 6. Windows Terminal & VS Code Configuration
Write-Output '[6/9] Configuring Terminal Defaults to PowerShell 7...'

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

# 7. PowerShell Profiles Setup ($PROFILE for PowerShell 7 and Windows PowerShell 5.1)
Write-Output '[7/9] Setting up PowerShell Profile...'

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

# 8. Sync Antigravity Plugins (common-modern-tools, windows-modern-tools & modern-web-stack)
Write-Output '[8/9] Syncing Antigravity Plugins...'
$pluginsDestRoot = Join-Path $HOME '.gemini\config\plugins'
if (-not (Test-Path -LiteralPath $pluginsDestRoot)) {
    New-Item -ItemType Directory -Force -Path $pluginsDestRoot | Out-Null
}

# Clean up legacy win11-modern-tools plugin if present to prevent duplicate rules/skills
$legacyWin11Plugin = Join-Path $pluginsDestRoot 'win11-modern-tools'
if (Test-Path -LiteralPath $legacyWin11Plugin) {
    Remove-Item -LiteralPath $legacyWin11Plugin -Recurse -Force -ErrorAction SilentlyContinue
}

foreach ($pluginName in @('common-modern-tools', 'windows-modern-tools', 'modern-web-stack')) {
    $srcPlugin = Join-Path $repoRoot "plugins\$pluginName"
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

# 9. Register Repository CLI Directory & Prune Stale User PATH
Write-Output '[9/9] Registering CLI Directory and Pruning Stale User PATH Entries...'
$cliDir = (Resolve-Path -LiteralPath (Join-Path $scriptDir '..\cli')).Path
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
                $expanded = [Environment]::ExpandEnvironmentVariables($_)
                Test-Path -LiteralPath $expanded
            }
    )
}

$vpBinDir = Join-Path $vpHome 'bin'
if ((Test-Path -LiteralPath $vpBinDir -PathType Container) -and ($currentUserPath -notcontains $vpBinDir)) {
    $currentUserPath = @($vpBinDir) + $currentUserPath
    Write-Output "Added $vpBinDir to User PATH."
}

if ($currentUserPath -notcontains $cliDir) {
    $currentUserPath += $cliDir
    Write-Output "Added $cliDir to User PATH."
}

$cleanPath = ($currentUserPath | Select-Object -Unique) -join ';'
[Environment]::SetEnvironmentVariable('Path', $cleanPath, 'User')

Write-Output '=== Setup Completed Successfully! ==='
