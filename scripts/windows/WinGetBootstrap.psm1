#Requires -Version 5.1
Set-StrictMode -Version Latest

Import-Module -Name (Join-Path $PSScriptRoot 'WindowsProvisioning.psm1') -ErrorAction Stop

function Get-AppxPackageCompat {
    param(
        [Parameter(Mandatory)]
        [string]$Name,
        [switch]$AllUsers,
        [switch]$UseWindowsPowerShellBridge
    )

    if ($UseWindowsPowerShellBridge) {
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
        [Parameter(Mandatory)]
        [string]$Path,
        [string[]]$DependencyPath = @(),
        [switch]$UseWindowsPowerShellBridge
    )

    if ($UseWindowsPowerShellBridge) {
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
        [Parameter(Mandatory)]
        [string]$PackagePath,
        [string[]]$DependencyPackagePath = @(),
        [switch]$UseWindowsPowerShellBridge
    )

    if ($UseWindowsPowerShellBridge) {
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
    param(
        [switch]$UseWindowsPowerShellBridge,
        [string[]]$ExtraPaths = @()
    )

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
    $existingPkg = Get-AppxPackageCompat -Name 'Microsoft.DesktopAppInstaller' -UseWindowsPowerShellBridge:$UseWindowsPowerShellBridge
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
                Add-AppxPackageCompat -Path $dep.FullName -UseWindowsPowerShellBridge:$UseWindowsPowerShellBridge
            }
            catch {
                Write-Output "          [Note] $($_.Exception.Message.Trim())"
            }
            $depPaths += $dep.FullName
        }

        Write-Output '      Registering WinGet DesktopAppInstaller package...'
        try {
            if ($depPaths.Count -gt 0) {
                Add-AppxPackageCompat -Path $wingetPath -DependencyPath $depPaths -UseWindowsPowerShellBridge:$UseWindowsPowerShellBridge
            }
            else {
                Add-AppxPackageCompat -Path $wingetPath -UseWindowsPowerShellBridge:$UseWindowsPowerShellBridge
            }
        }
        catch {
            Write-Output "      [!] Add-AppxPackage failed: $($_.Exception.Message). Falling back to Add-AppxProvisionedPackage..."
            try {
                if ($depPaths.Count -gt 0) {
                    Add-AppxProvisionedPackageCompat -PackagePath $wingetPath -DependencyPackagePath $depPaths -UseWindowsPowerShellBridge:$UseWindowsPowerShellBridge
                }
                else {
                    Add-AppxProvisionedPackageCompat -PackagePath $wingetPath -UseWindowsPowerShellBridge:$UseWindowsPowerShellBridge
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

        $newPkg = Get-AppxPackageCompat -Name 'Microsoft.DesktopAppInstaller' -UseWindowsPowerShellBridge:$UseWindowsPowerShellBridge
        if ($newPkg -and $newPkg.InstallLocation) {
            $pkgWinget = Join-Path $newPkg.InstallLocation 'winget.exe'
            if (Test-Path -LiteralPath $pkgWinget) {
                if ($env:Path -notmatch [regex]::Escape($newPkg.InstallLocation)) {
                    $env:Path = "$($newPkg.InstallLocation);$env:Path"
                }
            }
        }

        Sync-SessionPath -ExtraPaths $ExtraPaths

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
    param(
        [switch]$UseWindowsPowerShellBridge
    )

    $existing = Get-AppxPackageCompat -Name 'Microsoft.WindowsStore' -AllUsers -UseWindowsPowerShellBridge:$UseWindowsPowerShellBridge
    if ($existing) {
        Write-Output '      [OK] Microsoft Store is already installed.'
        return
    }

    Write-Output '      [+] Microsoft Store not detected. Installing Microsoft Store...'
    $installed = $false

    if (Get-Command 'winget' -ErrorAction SilentlyContinue) {
        Write-Output '      Installing Microsoft Store via WinGet (msstore: 9WZDNCRFJBMP)...'
        & winget install --id 9WZDNCRFJBMP --source msstore --exact --accept-package-agreements --accept-source-agreements --disable-interactivity 2>$null
        $check = Get-AppxPackageCompat -Name 'Microsoft.WindowsStore' -AllUsers -UseWindowsPowerShellBridge:$UseWindowsPowerShellBridge
        if ($check) {
            $installed = $true
        }
    }

    if (-not $installed -and (Get-Command 'wsreset.exe' -ErrorAction SilentlyContinue)) {
        Write-Output '      Invoking wsreset.exe -i to register Microsoft Store...'
        Start-Process -FilePath 'wsreset.exe' -ArgumentList '-i' -Wait -NoNewWindow -ErrorAction SilentlyContinue
    }

    $finalCheck = Get-AppxPackageCompat -Name 'Microsoft.WindowsStore' -AllUsers -UseWindowsPowerShellBridge:$UseWindowsPowerShellBridge
    if ($finalCheck) {
        Write-Output '      [OK] Microsoft Store installed successfully.'
    }
    else {
        Write-Warning 'Microsoft Store installation initiated. It may take a few moments to finish background registration.'
    }
}

function Install-WingetIdempotent {
    param(
        [Parameter(Mandatory)]
        [string]$Id,
        [Parameter(Mandatory)]
        [string]$Name
    )

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
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "WinGet installation for $Name ($Id) exited with code $LASTEXITCODE."
        }
    }
}

Export-ModuleMember -Function @(
    'Add-AppxPackageCompat',
    'Add-AppxProvisionedPackageCompat',
    'Get-AppxPackageCompat',
    'Initialize-MicrosoftStore',
    'Initialize-Winget',
    'Install-WingetIdempotent'
)
