Set-StrictMode -Version Latest

Import-Module -Name (Join-Path $PSScriptRoot 'CliCommon.psm1') -ErrorAction Stop

function Resolve-PlaywrightSyncStep {
    param(
        [Parameter(Mandatory)]
        [hashtable]$PackageJson,
        [string]$ProjectRoot = '.'
    )

    $scriptsMap = ($PackageJson['scripts'] -is [hashtable]) ? $PackageJson['scripts'] : @{}
    $depSections = @(
        (($PackageJson['dependencies'] -is [hashtable]) ? $PackageJson['dependencies'] : @{}),
        (($PackageJson['devDependencies'] -is [hashtable]) ? $PackageJson['devDependencies'] : @{}),
        (($PackageJson['optionalDependencies'] -is [hashtable]) ? $PackageJson['optionalDependencies'] : @{}),
        (($PackageJson['peerDependencies'] -is [hashtable]) ? $PackageJson['peerDependencies'] : @{})
    )

    $hasFullPlaywrightDep = $false
    $hasCoreOnlyDep = $false
    foreach ($section in $depSections) {
        foreach ($pkgName in @('playwright', '@playwright/test', '@vitest/browser-playwright')) {
            if ($section.ContainsKey($pkgName)) {
                $hasFullPlaywrightDep = $true
            }
        }
        if ($section.ContainsKey('playwright-core')) {
            $hasCoreOnlyDep = $true
        }
    }

    $binDir = Join-Path $ProjectRoot 'node_modules' '.bin'
    $hasPlaywrightBin = $false
    foreach ($binName in @('playwright', 'playwright.cmd', 'playwright.ps1')) {
        if (Test-Path -LiteralPath (Join-Path $binDir $binName) -PathType Leaf) {
            $hasPlaywrightBin = $true
            break
        }
    }

    $hasCoreBin = $false
    foreach ($binName in @('playwright-core', 'playwright-core.cmd', 'playwright-core.ps1')) {
        if (Test-Path -LiteralPath (Join-Path $binDir $binName) -PathType Leaf) {
            $hasCoreBin = $true
            break
        }
    }

    $hasAnyPlaywright = $hasFullPlaywrightDep -or $hasCoreOnlyDep -or $hasPlaywrightBin -or $hasCoreBin

    if ($scriptsMap.ContainsKey('test:setup')) {
        $setupCmd = [string]$scriptsMap['test:setup']
        if ($hasAnyPlaywright -or ($setupCmd -match '\bplaywright\b')) {
            return [PSCustomObject]@{
                Exe       = 'vpr'
                Arguments = @('--no-cache', 'test:setup')
                StepLabel = 'vpr --no-cache test:setup'
            }
        }
    }

    if ($hasFullPlaywrightDep -or $hasPlaywrightBin) {
        return [PSCustomObject]@{
            Exe       = 'vp'
            Arguments = @('exec', 'playwright', 'install', 'chromium', '--no-progress')
            StepLabel = 'vp exec playwright install chromium'
        }
    }

    if ($hasCoreOnlyDep -or $hasCoreBin) {
        return [PSCustomObject]@{
            Exe       = 'vp'
            Arguments = @('exec', 'playwright-core', 'install', 'chromium', '--no-progress')
            StepLabel = 'vp exec playwright-core install chromium'
        }
    }

    return $null
}

function Resolve-ProjectVerifyStep {
    param(
        [Parameter(Mandatory)]
        [hashtable]$ScriptsMap
    )

    $steps = [System.Collections.Generic.List[pscustomobject]]::new()
    if ($ScriptsMap.ContainsKey('agent:verify:gate')) {
        $steps.Add([PSCustomObject]@{
                Exe       = 'vpr'
                Arguments = @('agent:verify:gate')
                Message   = 'Verifying gate (unit, build, e2e)'
                StepLabel = 'vpr agent:verify:gate (gate)'
            })
        return @($steps)
    }

    foreach ($s in @('agent:verify:unit', 'agent:test:unit', 'test:unit')) {
        if ($ScriptsMap.ContainsKey($s)) {
            $steps.Add([PSCustomObject]@{
                    Exe       = 'vpr'
                    Arguments = @($s)
                    Message   = 'Verifying unit tests'
                    StepLabel = "vpr $s (unit-test)"
                })
            break
        }
    }

    $e2eScript = ''
    foreach ($s in @('agent:test:e2e', 'test:e2e')) {
        if ($ScriptsMap.ContainsKey($s)) {
            $e2eScript = $s
            break
        }
    }

    if ($e2eScript) {
        foreach ($b in @('build:all', 'build')) {
            if ($ScriptsMap.ContainsKey($b)) {
                $steps.Add([PSCustomObject]@{
                        Exe       = 'vpr'
                        Arguments = @($b)
                        Message   = 'Building project for E2E'
                        StepLabel = "vpr $b (build)"
                    })
                break
            }
        }

        $steps.Add([PSCustomObject]@{
                Exe       = 'vpr'
                Arguments = @($e2eScript)
                Message   = 'Verifying E2E tests'
                StepLabel = "vpr $e2eScript (e2e-test)"
            })
    }

    return @($steps)
}

function Test-WorkspaceNodeSyncTarget {
    param(
        [Parameter(Mandatory)]
        [string]$RepoPath,
        [bool]$PullUpdated = $false
    )

    if (-not (Test-Path -LiteralPath (Join-Path $RepoPath 'package.json') -PathType Leaf)) {
        return $false
    }

    $hasLockfile = $false
    foreach ($lockfile in @('pnpm-lock.yaml', 'package-lock.json', 'npm-shrinkwrap.json', 'yarn.lock', 'bun.lock', 'bun.lockb')) {
        if (Test-Path -LiteralPath (Join-Path $RepoPath $lockfile) -PathType Leaf) {
            $hasLockfile = $true
            break
        }
    }

    if (-not $hasLockfile) {
        return $false
    }

    $hasNodeModules = Test-Path -LiteralPath (Join-Path $RepoPath 'node_modules') -PathType Container
    return ($PullUpdated -or (-not $hasNodeModules))
}

function Resolve-LatestPnpmVersionFromJson {
    param(
        [AllowNull()]
        [string]$JsonText
    )

    if ([string]::IsNullOrWhiteSpace($JsonText)) {
        return $null
    }

    try {
        $parsed = $JsonText | ConvertFrom-Json -AsHashtable -ErrorAction Stop
    }
    catch {
        return $null
    }

    if (($parsed -isnot [hashtable]) -or (-not $parsed.ContainsKey('package_managers'))) {
        return $null
    }

    $pmMap = $parsed['package_managers']
    if (($pmMap -isnot [hashtable]) -or (-not $pmMap.ContainsKey('pnpm'))) {
        return $null
    }

    $entries = @($pmMap['pnpm'])
    foreach ($entry in $entries) {
        if ($entry -isnot [hashtable]) {
            continue
        }
        $ver = [string]($entry['version'] ?? '')
        if ([bool]($entry['latest'] ?? $false) -and (-not [string]::IsNullOrWhiteSpace($ver))) {
            return [PSCustomObject]@{
                Version   = $ver.Trim()
                Installed = [bool]($entry['installed'] ?? $false)
            }
        }
    }

    foreach ($entry in $entries) {
        if ($entry -isnot [hashtable]) {
            continue
        }
        $ver = [string]($entry['version'] ?? '')
        if (-not [string]::IsNullOrWhiteSpace($ver)) {
            return [PSCustomObject]@{
                Version   = $ver.Trim()
                Installed = [bool]($entry['installed'] ?? $false)
            }
        }
    }

    return $null
}

function Get-PnpmPackageManagerSpec {
    param(
        [AllowNull()]
        [string]$PackageManagerField
    )

    if ([string]::IsNullOrWhiteSpace($PackageManagerField)) {
        return [PSCustomObject]@{
            IsPnpm  = $false
            IsOther = $false
            Raw     = ''
            Version = ''
        }
    }

    $trimmed = $PackageManagerField.Trim()
    if ($trimmed -match '^pnpm@([^\s+]+)(?:\+.*)?$') {
        return [PSCustomObject]@{
            IsPnpm  = $true
            IsOther = $false
            Raw     = $trimmed
            Version = $Matches[1]
        }
    }

    return [PSCustomObject]@{
        IsPnpm  = $false
        IsOther = $true
        Raw     = $trimmed
        Version = ''
    }
}

function Test-PnpmWorkspaceProject {
    param(
        [Parameter(Mandatory)]
        [string]$RepoPath
    )

    if (-not (Test-Path -LiteralPath (Join-Path $RepoPath '.git'))) {
        return $false
    }

    $pkgPath = Join-Path $RepoPath 'package.json'
    if (-not (Test-Path -LiteralPath $pkgPath -PathType Leaf)) {
        return $false
    }

    try {
        $pkg = Get-Content -LiteralPath $pkgPath -Raw | ConvertFrom-Json -AsHashtable -ErrorAction Stop
    }
    catch {
        return $false
    }

    if ($pkg -isnot [hashtable]) {
        return $false
    }

    $pmSpec = Get-PnpmPackageManagerSpec -PackageManagerField ([string]($pkg['packageManager'] ?? ''))
    if ($pmSpec.IsOther) {
        return $false
    }
    if ($pmSpec.IsPnpm) {
        return $true
    }

    return (
        (Test-Path -LiteralPath (Join-Path $RepoPath 'pnpm-lock.yaml') -PathType Leaf) -or
        (Test-Path -LiteralPath (Join-Path $RepoPath 'pnpm-workspace.yaml') -PathType Leaf)
    )
}

function Format-ProjectPackageManifest {
    param(
        [Parameter(Mandatory)]
        [string]$ProjectDir
    )

    $manifestPath = Join-Path $ProjectDir 'package.json'
    if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
        return [PSCustomObject]@{
            Success     = $false
            ErrorDetail = "package.json not found in $ProjectDir"
        }
    }

    $fmtOut = @(& vp -C $ProjectDir fmt --no-error-on-unmatched-pattern package.json 2>&1)
    $exitCode = ($LASTEXITCODE ?? 0)
    if ($exitCode -ne 0) {
        return [PSCustomObject]@{
            Success     = $false
            ErrorDetail = (Format-NativeErrorDetail -OutputLines $fmtOut -ExitCode $exitCode)
        }
    }

    return [PSCustomObject]@{
        Success     = $true
        ErrorDetail = ''
    }
}

function Get-VitePlusOxfmtSpec {
    param(
        [string]$VpCommandPath = '',
        [string]$VpVersion = '',
        [string[]]$FallbackRoots = @()
    )

    $candidateRoots = [System.Collections.Generic.List[string]]::new()
    if (-not [string]::IsNullOrWhiteSpace($env:VP_HOME)) {
        $candidateRoots.Add($env:VP_HOME.Trim())
    }
    if (-not [string]::IsNullOrWhiteSpace($VpCommandPath)) {
        $binDir = Split-Path -Parent $VpCommandPath
        if ($binDir) {
            $parentDir = Split-Path -Parent $binDir
            if ($parentDir) {
                $candidateRoots.Add($parentDir)
            }
        }
        $vpInfo = [System.IO.FileInfo]::new($VpCommandPath)
        $vpTarget = $vpInfo.ResolveLinkTarget($true)
        if ($null -ne $vpTarget) {
            $targetBinDir = Split-Path -Parent $vpTarget.FullName
            if ($targetBinDir) {
                $targetParentDir = Split-Path -Parent $targetBinDir
                if ($targetParentDir) {
                    $candidateRoots.Add($targetParentDir)
                }
            }
        }
    }

    foreach ($extraRoot in $FallbackRoots) {
        if (-not [string]::IsNullOrWhiteSpace($extraRoot)) {
            $candidateRoots.Add($extraRoot)
        }
    }

    if ($IsWindows) {
        $candidateRoots.Add('E:\vite-plus')
        $candidateRoots.Add((Join-Path $HOME '.vite-plus'))
    }
    else {
        $candidateRoots.Add((Join-Path $HOME '.local/share/vite-plus'))
    }

    $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($root in $candidateRoots) {
        if ([string]::IsNullOrWhiteSpace($root) -or (-not $seen.Add($root)) -or (-not (Test-Path -LiteralPath $root -PathType Container))) {
            continue
        }

        $pkgCandidates = [System.Collections.Generic.List[string]]::new()
        $pkgCandidates.Add((Join-Path $root 'current/node_modules/vite-plus/package.json'))
        if ($VpVersion) {
            $pkgCandidates.Add((Join-Path $root "$VpVersion/node_modules/vite-plus/package.json"))
        }
        $pkgCandidates.Add((Join-Path $root 'node_modules/vite-plus/package.json'))

        foreach ($pkgPath in $pkgCandidates) {
            if (-not (Test-Path -LiteralPath $pkgPath -PathType Leaf)) {
                continue
            }

            $pkg = Get-Content -LiteralPath $pkgPath -Raw | ConvertFrom-Json -AsHashtable
            $deps = $pkg['dependencies']
            if ($deps -is [hashtable] -and $deps.ContainsKey('oxfmt')) {
                $rawVer = ([string]$deps['oxfmt']).Trim()
                $targetVer = $rawVer -replace '^[^0-9]*', ''
                if ($targetVer) {
                    $vpHomeDir = $root
                    if ($pkgPath -eq (Join-Path $root 'node_modules/vite-plus/package.json')) {
                        $vpHomeDir = Split-Path -Parent $root
                    }
                    return [PSCustomObject]@{
                        VpHome       = $vpHomeDir
                        OxfmtVersion = $targetVer
                    }
                }
            }
        }
    }

    return $null
}

function Sync-GlobalOxfmt {
    $vpCmd = Get-Command 'vp' -ErrorAction SilentlyContinue
    if ($null -eq $vpCmd) {
        return
    }

    $vpVerOut = @(& vp --version 2>$null)
    $vpVersion = ''
    foreach ($line in $vpVerOut) {
        if ([string]$line -match '^vp v([^\s]+)') {
            $vpVersion = $Matches[1]
            break
        }
    }

    $spec = Get-VitePlusOxfmtSpec -VpCommandPath $vpCmd.Source -VpVersion $vpVersion
    if ($null -eq $spec) {
        [Console]::Error.WriteLine('Warning: Unable to determine bundled oxfmt version from global vite-plus installation.')
        return
    }

    $targetVer = $spec.OxfmtVersion
    $shimName = $IsWindows ? 'oxfmt.exe' : 'oxfmt'
    $shimPath = Join-Path $spec.VpHome "bin/$shimName"
    $currentVer = ''

    if (Test-Path -LiteralPath $shimPath -PathType Leaf) {
        $verOut = @(& $shimPath --version 2>$null)
        foreach ($line in $verOut) {
            if ([string]$line -match '(\d+\.\d+\.\d+(?:-[^\s]+)?)') {
                $currentVer = $Matches[1]
                break
            }
        }
    }

    if ((-not (Test-Path -LiteralPath $shimPath -PathType Leaf)) -or ($currentVer -ne $targetVer)) {
        $installOut = @(& vp install -g "oxfmt@$targetVer" 2>&1)
        if ($LASTEXITCODE -ne 0) {
            foreach ($line in $installOut) {
                [Console]::Error.WriteLine($line)
            }
            throw "Failed to align global oxfmt to $targetVer"
        }

        if ($currentVer) {
            Write-Output "oxfmt: $currentVer -> $targetVer"
        }
        else {
            Write-Output "oxfmt: $targetVer"
        }
    }
}

Export-ModuleMember -Function @(
    'Format-ProjectPackageManifest',
    'Get-PnpmPackageManagerSpec',
    'Get-VitePlusOxfmtSpec',
    'Resolve-LatestPnpmVersionFromJson',
    'Resolve-PlaywrightSyncStep',
    'Resolve-ProjectVerifyStep',
    'Sync-GlobalOxfmt',
    'Test-PnpmWorkspaceProject',
    'Test-WorkspaceNodeSyncTarget'
)
