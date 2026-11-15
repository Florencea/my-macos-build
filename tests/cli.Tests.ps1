#!/usr/bin/env -S pwsh -NoLogo -NoProfile
<#
.SYNOPSIS
    Zero-dependency unit and CLI contract test suite for cli/ PowerShell scripts and helpers.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$cliDir = Join-Path $repoRoot 'cli'
$commonModule = Join-Path $cliDir 'helpers' 'CliCommon.psm1'
Import-Module -Name $commonModule -Force

$script:passed = 0
$script:failed = 0

function Assert-Condition {
    param(
        [Parameter(Mandatory)]
        [string]$Name,
        [Parameter(Mandatory)]
        [bool]$Condition,
        [string]$Detail = ''
    )

    if ($Condition) {
        $script:passed++
    }
    else {
        $script:failed++
        $suffix = $Detail ? " ($Detail)" : ''
        [Console]::Error.WriteLine("[FAIL] ${Name}${suffix}")
    }
}

function Assert-Throw {
    param(
        [Parameter(Mandatory)]
        [string]$Name,
        [Parameter(Mandatory)]
        [scriptblock]$Action
    )

    $threw = $false
    try {
        & $Action | Out-Null
    }
    catch {
        $threw = $true
    }
    Assert-Condition -Name $Name -Condition $threw -Detail 'expected exception was not thrown'
}

function Invoke-PwshCaptured {
    param(
        [Parameter(Mandatory)]
        [string[]]$PwshArgs
    )

    $stdoutFile = [System.IO.Path]::GetTempFileName()
    $stderrFile = [System.IO.Path]::GetTempFileName()
    try {
        $proc = Start-Process -FilePath 'pwsh' -ArgumentList $PwshArgs -NoNewWindow -Wait -PassThru `
            -RedirectStandardOutput $stdoutFile -RedirectStandardError $stderrFile
        $outText = [System.IO.File]::ReadAllText($stdoutFile)
        $errText = [System.IO.File]::ReadAllText($stderrFile)
        return [PSCustomObject]@{
            ExitCode = $proc.ExitCode
            Stdout   = $outText
            Stderr   = $errText
        }
    }
    finally {
        Remove-Item -LiteralPath $stdoutFile, $stderrFile -Force -ErrorAction SilentlyContinue
    }
}

# 1. Unit tests for CliCommon.psm1
Assert-Condition -Name 'Convert-TimeToSecond HH:MM:SS.ms' -Condition ([Math]::Abs((Convert-TimeToSecond -TimeText '01:02:03.5') - 3723.5) -lt 0.0001)
Assert-Condition -Name 'Convert-TimeToSecond MM:SS' -Condition ([Math]::Abs((Convert-TimeToSecond -TimeText '02:30') - 150.0) -lt 0.0001)
Assert-Condition -Name 'Convert-TimeToSecond numeric seconds' -Condition ([Math]::Abs((Convert-TimeToSecond -TimeText '12.5') - 12.5) -lt 0.0001)

Assert-Throw -Name 'Convert-TimeToSecond rejects negative' -Action { Convert-TimeToSecond -TimeText '-1' }
Assert-Throw -Name 'Convert-TimeToSecond rejects >=60 seconds' -Action { Convert-TimeToSecond -TimeText '01:60' }
Assert-Throw -Name 'Convert-TimeToSecond rejects non-positive duration' -Action { Convert-TimeToSecond -TimeText '0' -PositiveOnly }
Assert-Throw -Name 'Convert-TimeToSecond rejects invalid text' -Action { Convert-TimeToSecond -TimeText 'not-a-time' }

Assert-Condition -Name 'ConvertTo-ValidatedInt valid' -Condition ((ConvertTo-ValidatedInt -Value '50' -OptionName '--quality' -MinValue 0 -MaxValue 100) -eq 50)
Assert-Throw -Name 'ConvertTo-ValidatedInt rejects non-int' -Action { ConvertTo-ValidatedInt -Value 'abc' -OptionName '--quality' -MinValue 0 -MaxValue 100 }
Assert-Throw -Name 'ConvertTo-ValidatedInt rejects out-of-range' -Action { ConvertTo-ValidatedInt -Value '101' -OptionName '--quality' -MinValue 0 -MaxValue 100 }

Assert-Condition -Name 'Format-ByteSize KB' -Condition ((Format-ByteSize -ByteCount 1024) -eq '1K')
Assert-Condition -Name 'Format-ByteSize MB' -Condition ((Format-ByteSize -ByteCount 1572864) -eq '1.5M')
Assert-Condition -Name 'Format-ByteSize GB' -Condition ((Format-ByteSize -ByteCount 2147483648) -eq '2.0G')

Assert-Condition -Name 'Test-RequiredCommand finds pwsh' -Condition (Test-RequiredCommand -Name 'pwsh' -Quiet)
Assert-Condition -Name 'Test-RequiredCommand returns false for missing command' -Condition (-not (Test-RequiredCommand -Name 'nonexistent-cmd-xyz-999' -Quiet))

# 2. Symlink resolution test via temporary extensionless symlink
$tempTestDir = Join-Path ([System.IO.Path]::GetTempPath()) ('mmb_test_' + [System.Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $tempTestDir | Out-Null

try {
    $symlinkPath = Join-Path $tempTestDir 'mmb_link'
    $targetScript = Join-Path $cliDir 'mmb.ps1'
    $linkCreated = $false
    try {
        New-Item -ItemType SymbolicLink -Path $symlinkPath -Target $targetScript -ErrorAction Stop | Out-Null
        $linkCreated = $true
    }
    catch {
        $linkCreated = $false
    }

    if ($linkCreated) {
        $resolvedDir = Resolve-CliScriptDirectory -CommandPath $symlinkPath
        Assert-Condition -Name 'Resolve-CliScriptDirectory resolves symlink target' -Condition ($resolvedDir -eq $cliDir) -Detail "got '$resolvedDir'"

        $symHelp = Invoke-PwshCaptured -PwshArgs @('-NoLogo', '-NoProfile', '-File', $symlinkPath, '--help')
        Assert-Condition -Name 'Extensionless symlink --help exits 0' -Condition ($symHelp.ExitCode -eq 0) -Detail "exit $($symHelp.ExitCode): $($symHelp.Stderr)"
        Assert-Condition -Name 'Extensionless symlink --help prints usage' -Condition ($symHelp.Stdout -match 'mmb:')
    }

    # 3. Contract tests for all cli/*.ps1 scripts (--help and unknown option rejection)
    $cliScripts = @(Get-ChildItem -LiteralPath $cliDir -Filter '*.ps1' -File | Sort-Object Name)
    foreach ($scriptFile in $cliScripts) {
        $cmdName = $scriptFile.BaseName
        $helpRes = Invoke-PwshCaptured -PwshArgs @('-NoLogo', '-NoProfile', '-File', $scriptFile.FullName, '--help')
        Assert-Condition -Name "$($scriptFile.Name) --help exit 0" -Condition ($helpRes.ExitCode -eq 0) -Detail "exit $($helpRes.ExitCode): $($helpRes.Stderr)"
        Assert-Condition -Name "$($scriptFile.Name) --help outputs usage" -Condition ($helpRes.Stdout -match [regex]::Escape($cmdName))

        $badRes = Invoke-PwshCaptured -PwshArgs @('-NoLogo', '-NoProfile', '-File', $scriptFile.FullName, '--unknown-flag-test')
        Assert-Condition -Name "$($scriptFile.Name) rejects unknown option" -Condition ($badRes.ExitCode -ne 0) -Detail 'expected non-zero exit'
        Assert-Condition -Name "$($scriptFile.Name) writes unknown option error to stderr" -Condition ($badRes.Stderr -match 'Unknown option')
    }

    # 4. rea.ps1 safety guard: refuse deleting directory with multiple .mkv files
    if (Get-Command 'ffmpeg' -ErrorAction SilentlyContinue) {
        $reaDir = Join-Path $tempTestDir 'multi_mkv'
        New-Item -ItemType Directory -Force -Path $reaDir | Out-Null
        [System.IO.File]::WriteAllText((Join-Path $reaDir 'a.mkv'), '')
        [System.IO.File]::WriteAllText((Join-Path $reaDir 'b.mkv'), '')
        [System.IO.File]::WriteAllText((Join-Path $reaDir 'a.cht.ass'), '')

        $reaRes = Invoke-PwshCaptured -PwshArgs @('-NoLogo', '-NoProfile', '-File', (Join-Path $cliDir 'rea.ps1'), $reaDir)
        Assert-Condition -Name 'rea.ps1 rejects directory with multiple mkv files' -Condition ($reaRes.ExitCode -ne 0)
        Assert-Condition -Name 'rea.ps1 outputs multiple mkv error' -Condition ($reaRes.Stderr -match 'Multiple \.mkv files')
        Assert-Condition -Name 'rea.ps1 preserves directory when aborted' -Condition (Test-Path -LiteralPath $reaDir -PathType Container)
    }

    # 5. webread.ps1 rejects invalid --max-chars cleanly
    $webreadBadMax = Invoke-PwshCaptured -PwshArgs @('-NoLogo', '-NoProfile', '-File', (Join-Path $cliDir 'webread.ps1'), '--max-chars', 'abc', 'https://example.com')
    Assert-Condition -Name 'webread.ps1 rejects non-integer --max-chars' -Condition ($webreadBadMax.ExitCode -ne 0)
    Assert-Condition -Name 'webread.ps1 reports --max-chars validation error' -Condition ($webreadBadMax.Stderr -match 'Invalid integer for --max-chars')

    # 6. Resolve-PlaywrightSyncStep tests
    $pwEmptyDir = Join-Path $tempTestDir 'pw_empty'
    New-Item -ItemType Directory -Force -Path $pwEmptyDir | Out-Null

    $pwSetupStep = Resolve-PlaywrightSyncStep -PackageJson @{
        scripts         = @{ 'test:setup' = 'playwright install chromium' }
        devDependencies = @{ playwright = '1.65.0' }
    } -ProjectRoot $pwEmptyDir
    Assert-Condition -Name 'Resolve-PlaywrightSyncStep uses test:setup when present' -Condition (($null -ne $pwSetupStep) -and ($pwSetupStep.Exe -eq 'vpr') -and (($pwSetupStep.Arguments -join ' ') -eq '--no-cache test:setup'))

    $nonPwSetupStep = Resolve-PlaywrightSyncStep -PackageJson @{
        scripts         = @{ 'test:setup' = 'node scripts/seed-db.ts' }
        devDependencies = @{ vitest = '5.1.0' }
    } -ProjectRoot $pwEmptyDir
    Assert-Condition -Name 'Resolve-PlaywrightSyncStep ignores unrelated test:setup' -Condition ($null -eq $nonPwSetupStep)

    $pwBrowserDepStep = Resolve-PlaywrightSyncStep -PackageJson @{
        devDependencies = @{ '@vitest/browser-playwright' = '5.1.0' }
    } -ProjectRoot $pwEmptyDir
    Assert-Condition -Name 'Resolve-PlaywrightSyncStep falls back to vp exec playwright for @vitest/browser-playwright' -Condition (($null -ne $pwBrowserDepStep) -and ($pwBrowserDepStep.Exe -eq 'vp') -and (($pwBrowserDepStep.Arguments -join ' ') -eq 'exec playwright install chromium --no-progress'))

    $pwCoreOnlyStep = Resolve-PlaywrightSyncStep -PackageJson @{
        dependencies = @{ 'playwright-core' = '1.65.0' }
    } -ProjectRoot $pwEmptyDir
    Assert-Condition -Name 'Resolve-PlaywrightSyncStep falls back to playwright-core when only core is declared' -Condition (($null -ne $pwCoreOnlyStep) -and ($pwCoreOnlyStep.Exe -eq 'vp') -and (($pwCoreOnlyStep.Arguments -join ' ') -eq 'exec playwright-core install chromium --no-progress'))

    $pwBinDir = Join-Path $tempTestDir 'pw_bin'
    $pwShimDir = Join-Path $pwBinDir 'node_modules' '.bin'
    New-Item -ItemType Directory -Force -Path $pwShimDir | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $pwShimDir 'playwright.cmd'), '')
    $pwShimStep = Resolve-PlaywrightSyncStep -PackageJson @{
        devDependencies = @{ vitest = '5.1.0' }
    } -ProjectRoot $pwBinDir
    Assert-Condition -Name 'Resolve-PlaywrightSyncStep detects node_modules/.bin playwright.cmd shim' -Condition (($null -ne $pwShimStep) -and ($pwShimStep.Exe -eq 'vp') -and (($pwShimStep.Arguments -join ' ') -eq 'exec playwright install chromium --no-progress'))

    $noPwStep = Resolve-PlaywrightSyncStep -PackageJson @{
        devDependencies = @{ vitest = '5.1.0' }
    } -ProjectRoot $pwEmptyDir
    Assert-Condition -Name 'Resolve-PlaywrightSyncStep returns null for non-Playwright projects' -Condition ($null -eq $noPwStep)

    # 7. Resolve-ProjectVerifyStep tests
    $gateSteps = @(Resolve-ProjectVerifyStep -ScriptsMap @{
            'agent:verify:gate' = 'vpr agent:verify:unit && vp build && vpr agent:test:e2e'
            'agent:verify:unit' = 'vpr agent:verify:inner && vpr agent:test:unit'
            'agent:test:e2e'    = 'vp test run --project e2e'
        })
    Assert-Condition -Name 'Resolve-ProjectVerifyStep prioritizes agent:verify:gate' -Condition (($gateSteps.Count -eq 1) -and ($gateSteps[0].Exe -eq 'vpr') -and (($gateSteps[0].Arguments -join ' ') -eq 'agent:verify:gate'))

    $fallbackSteps = @(Resolve-ProjectVerifyStep -ScriptsMap @{
            'agent:verify:unit' = 'vpr agent:verify:inner && vpr agent:test:unit'
            'build'             = 'vp build'
            'agent:test:e2e'    = 'vp test run --project e2e'
        })
    Assert-Condition -Name 'Resolve-ProjectVerifyStep sequences unit, build, and e2e without gate' -Condition (($fallbackSteps.Count -eq 3) -and ($fallbackSteps[0].Arguments[0] -eq 'agent:verify:unit') -and ($fallbackSteps[1].Arguments[0] -eq 'build') -and ($fallbackSteps[2].Arguments[0] -eq 'agent:test:e2e'))

    $unitOnlySteps = @(Resolve-ProjectVerifyStep -ScriptsMap @{
            'agent:verify:unit' = 'vpr agent:verify:inner && vpr agent:test:unit'
        })
    Assert-Condition -Name 'Resolve-ProjectVerifyStep handles unit-only projects' -Condition (($unitOnlySteps.Count -eq 1) -and ($unitOnlySteps[0].Arguments[0] -eq 'agent:verify:unit'))

    $emptyVerifySteps = @(Resolve-ProjectVerifyStep -ScriptsMap @{})
    Assert-Condition -Name 'Resolve-ProjectVerifyStep returns empty array when no verify scripts exist' -Condition ($emptyVerifySteps.Count -eq 0)

    # 8. Test-WorkspaceNodeSyncTarget tests
    $nonNodeRepo = Join-Path $tempTestDir 'repo_non_node'
    New-Item -ItemType Directory -Force -Path $nonNodeRepo | Out-Null
    Assert-Condition -Name 'Test-WorkspaceNodeSyncTarget rejects repo without package.json' -Condition (-not (Test-WorkspaceNodeSyncTarget -RepoPath $nonNodeRepo -PullUpdated $true))

    $noLockRepo = Join-Path $tempTestDir 'repo_no_lock'
    New-Item -ItemType Directory -Force -Path $noLockRepo | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $noLockRepo 'package.json'), '{}')
    Assert-Condition -Name 'Test-WorkspaceNodeSyncTarget rejects repo without lockfile' -Condition (-not (Test-WorkspaceNodeSyncTarget -RepoPath $noLockRepo -PullUpdated $true))

    $freshCloneRepo = Join-Path $tempTestDir 'repo_fresh_clone'
    New-Item -ItemType Directory -Force -Path $freshCloneRepo | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $freshCloneRepo 'package.json'), '{}')
    [System.IO.File]::WriteAllText((Join-Path $freshCloneRepo 'pnpm-lock.yaml'), '')
    Assert-Condition -Name 'Test-WorkspaceNodeSyncTarget initializes repo missing node_modules even without pull updates' -Condition (Test-WorkspaceNodeSyncTarget -RepoPath $freshCloneRepo -PullUpdated $false)

    $installedRepo = Join-Path $tempTestDir 'repo_installed'
    New-Item -ItemType Directory -Force -Path (Join-Path $installedRepo 'node_modules') | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $installedRepo 'package.json'), '{}')
    [System.IO.File]::WriteAllText((Join-Path $installedRepo 'pnpm-lock.yaml'), '')
    Assert-Condition -Name 'Test-WorkspaceNodeSyncTarget skips unchanged repo when node_modules exists' -Condition (-not (Test-WorkspaceNodeSyncTarget -RepoPath $installedRepo -PullUpdated $false))
    Assert-Condition -Name 'Test-WorkspaceNodeSyncTarget syncs updated repo when node_modules exists' -Condition (Test-WorkspaceNodeSyncTarget -RepoPath $installedRepo -PullUpdated $true)

    # 9. Format-NativeErrorDetail and clall.ps1 contract tests
    $multiErr = Format-NativeErrorDetail -OutputLines @('fatal: remote error: ', '', '  Repository is disabled.', $null) -ExitCode 128
    Assert-Condition -Name 'Format-NativeErrorDetail preserves multi-line git error details' -Condition ($multiErr -eq 'fatal: remote error: | Repository is disabled.') -Detail "got '$multiErr'"

    $emptyErr = Format-NativeErrorDetail -OutputLines @('', '   ') -ExitCode 128
    Assert-Condition -Name 'Format-NativeErrorDetail falls back to exit code when output is blank' -Condition ($emptyErr -eq 'exit code 128') -Detail "got '$emptyErr'"

    if (Get-Command 'git' -ErrorAction SilentlyContinue) {
        $missingGitSrc = Join-Path $tempTestDir 'missing_repo.git'
        $missingGitDest = Join-Path $tempTestDir 'missing_repo_dest'
        $prevEap = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        $gitOut = @(& git clone --quiet $missingGitSrc $missingGitDest 2>&1)
        $gitCode = $LASTEXITCODE
        $ErrorActionPreference = $prevEap
        $gitDetail = Format-NativeErrorDetail -OutputLines $gitOut -ExitCode $gitCode
        Assert-Condition -Name 'Format-NativeErrorDetail formats git ErrorRecord output' -Condition (($gitCode -ne 0) -and ($gitDetail -match 'does not exist')) -Detail "got '$gitDetail'"
    }

    $clallOpRes = Invoke-PwshCaptured -PwshArgs @('-NoLogo', '-NoProfile', '-File', (Join-Path $cliDir 'clall.ps1'), 'op://Personal/GitHub/token')
    Assert-Condition -Name 'clall.ps1 rejects unresolved op:// secret reference' -Condition ($clallOpRes.ExitCode -ne 0) -Detail 'expected non-zero exit'
    Assert-Condition -Name 'clall.ps1 explains unresolved op:// token error on stderr' -Condition ($clallOpRes.Stderr -match '1Password secret reference') -Detail "got '$($clallOpRes.Stderr)'"

    # 10. Resolve-GitHubRepoList tests (including -NoEnumerate array responses)
    $emptyApiRepos = @(Resolve-GitHubRepoList -RawResponse (ConvertFrom-Json '[]' -NoEnumerate))
    Assert-Condition -Name 'Resolve-GitHubRepoList handles empty JSON array' -Condition ($emptyApiRepos.Count -eq 0) -Detail "got $($emptyApiRepos.Count)"

    $nullApiRepos = @(Resolve-GitHubRepoList -RawResponse $null)
    Assert-Condition -Name 'Resolve-GitHubRepoList handles null response' -Condition ($nullApiRepos.Count -eq 0) -Detail "got $($nullApiRepos.Count)"

    $singleRaw = ConvertFrom-Json '[{"name":"alpha","ssh_url":"git@github.com:u/alpha.git"}]' -NoEnumerate
    $singleApiRepos = @(Resolve-GitHubRepoList -RawResponse $singleRaw)
    Assert-Condition -Name 'Resolve-GitHubRepoList unwraps single-element -NoEnumerate array' -Condition (($singleApiRepos.Count -eq 1) -and ($singleApiRepos[0].Name -eq 'alpha') -and ($singleApiRepos[0].Url -eq 'git@github.com:u/alpha.git'))

    $multiRaw = ConvertFrom-Json '[{"name":"alpha","ssh_url":"git@github.com:u/alpha.git"},{"name":"no-ssh"},{"ssh_url":"git@github.com:u/beta.git"}]' -NoEnumerate
    $multiApiRepos = @(Resolve-GitHubRepoList -RawResponse $multiRaw)
    Assert-Condition -Name 'Resolve-GitHubRepoList unwraps multi-element -NoEnumerate array and filters missing ssh_url' -Condition (($multiApiRepos.Count -eq 2) -and ($multiApiRepos[0].Name -eq 'alpha') -and ($multiApiRepos[1].Name -eq 'beta')) -Detail "got $($multiApiRepos.Count)"

    # 11. Resolve-YtDlpBrowser and mkclp/mkgif default browser contract tests
    $prevYtBrowser = $env:YT_DLP_BROWSER
    try {
        Remove-Item Env:YT_DLP_BROWSER -ErrorAction SilentlyContinue
        Assert-Condition -Name 'Resolve-YtDlpBrowser defaults to chrome' -Condition ((Resolve-YtDlpBrowser) -eq 'chrome')
        Assert-Condition -Name 'Resolve-YtDlpBrowser ignores whitespace browser arg' -Condition ((Resolve-YtDlpBrowser -Browser '   ') -eq 'chrome')

        $env:YT_DLP_BROWSER = ' edge '
        Assert-Condition -Name 'Resolve-YtDlpBrowser uses trimmed YT_DLP_BROWSER env var' -Condition ((Resolve-YtDlpBrowser) -eq 'edge')
        Assert-Condition -Name 'Resolve-YtDlpBrowser prefers explicit browser over env var' -Condition ((Resolve-YtDlpBrowser -Browser ' firefox ') -eq 'firefox')
    }
    finally {
        if ($null -eq $prevYtBrowser) {
            Remove-Item Env:YT_DLP_BROWSER -ErrorAction SilentlyContinue
        }
        else {
            $env:YT_DLP_BROWSER = $prevYtBrowser
        }
    }

    foreach ($mediaScript in @('mkclp.ps1', 'mkgif.ps1')) {
        $mediaHelp = Invoke-PwshCaptured -PwshArgs @('-NoLogo', '-NoProfile', '-File', (Join-Path $cliDir $mediaScript), '--help')
        Assert-Condition -Name "$mediaScript --help documents default browser as chrome" -Condition ($mediaHelp.Stdout -match 'default:\s*chrome') -Detail "got '$($mediaHelp.Stdout)'"
    }
}
finally {
    if (Test-Path -LiteralPath $tempTestDir) {
        Remove-Item -LiteralPath $tempTestDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Write-Output "PowerShell tests: $($script:passed) passed, $($script:failed) failed"
if ($script:failed -gt 0) {
    exit 1
}
