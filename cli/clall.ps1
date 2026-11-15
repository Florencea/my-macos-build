#!/usr/bin/env -S pwsh -NoLogo -NoProfile
<#
.SYNOPSIS
    Clone all GitHub Repositories for the authenticated user in parallel.
.DESCRIPTION
    Cross-platform GitHub repository batch cloner for macOS and Windows 11 (PowerShell 7).
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

$scriptDir = $PSScriptRoot
if ($scriptDir -and $PSCommandPath) {
    $commandInfo = [System.IO.FileInfo]::new($PSCommandPath)
    if ($null -ne $commandInfo.LinkTarget) {
        $scriptDir = Split-Path -Parent (($commandInfo.ResolveLinkTarget($true) ?? $commandInfo).FullName)
    }
}
elseif (-not $scriptDir) {
    $entryPath = [Environment]::GetCommandLineArgs() |
        Select-Object -Skip 1 |
        Where-Object { $_ -and (-not $_.StartsWith('-')) -and (Test-Path -LiteralPath $_ -PathType Leaf) } |
        Select-Object -First 1
    if (-not $entryPath) {
        throw 'Unable to determine script path.'
    }
    $entryInfo = [System.IO.FileInfo]::new((Resolve-Path -LiteralPath $entryPath).Path)
    $scriptDir = Split-Path -Parent (($entryInfo.ResolveLinkTarget($true) ?? $entryInfo).FullName)
}
Import-Module -Name (Join-Path $scriptDir 'helpers' 'CliCommon.psm1') -Force

function Show-Help {
    Write-Output @'
clall: Clone all GitHub Repositories for the authenticated user
Usage: clall [GITHUB_ACCESS_TOKEN]
       clall ghp_000000000000000000000000000000000000
       GITHUB_TOKEN=... clall
'@
}

$Token = ''
$Help = $false

foreach ($rawArg in $args) {
    $arg = [string]$rawArg
    if ($arg -match '^--?h(elp)?$') {
        $Help = $true
    }
    elseif ($arg.StartsWith('-')) {
        [Console]::Error.WriteLine("Error: Unknown option $arg")
        Show-Help
        exit 1
    }
    elseif (-not $Token) {
        $Token = $arg
    }
    else {
        [Console]::Error.WriteLine("Error: Unexpected argument $arg")
        Show-Help
        exit 1
    }
}

if ($Help) {
    Show-Help
    exit 0
}

if (-not $Token) {
    $Token = $env:GITHUB_TOKEN ? $env:GITHUB_TOKEN : ($env:GH_TOKEN ? $env:GH_TOKEN : '')
}
$Token = $Token.Trim()

if (-not $Token) {
    [Console]::Error.WriteLine('clall: Clone all GitHub Repositories')
    [Console]::Error.WriteLine('Usage: clall [GITHUB_ACCESS_TOKEN]')
    [Console]::Error.WriteLine('       GITHUB_TOKEN=... clall')
    exit 1
}

if ($Token.StartsWith('op://', [System.StringComparison]::OrdinalIgnoreCase)) {
    [Console]::Error.WriteLine("Error: Unresolved 1Password secret reference in token; run via 'op run'")
    exit 1
}

if (-not (Test-RequiredCommand -Name 'git')) {
    exit 1
}

$headers = @{
    'Accept'               = 'application/vnd.github+json'
    'Authorization'        = "Bearer $Token"
    'X-GitHub-Api-Version' = '2022-11-28'
    'User-Agent'           = 'pwsh-clall'
}

$repos = [System.Collections.Generic.List[pscustomobject]]::new()
$page = 1
try {
    while ($true) {
        $uri = "https://api.github.com/user/repos?type=owner&per_page=100&page=$page"
        $rawResponse = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get
        $rawCount = ($rawResponse -is [System.Array]) ? $rawResponse.Count : (($null -ne $rawResponse) ? 1 : 0)
        if ($rawCount -eq 0) {
            break
        }
        foreach ($repoItem in @(Resolve-GitHubRepoList -RawResponse $rawResponse)) {
            $repos.Add($repoItem)
        }
        if ($rawCount -lt 100) {
            break
        }
        $page++
    }
}
catch {
    [Console]::Error.WriteLine("Error: Failed to fetch repositories from GitHub API: $($_.Exception.Message)")
    exit 1
}

$total = $repos.Count
if ($total -eq 0) {
    Write-Output 'No repositories found.'
    exit 0
}

$targetRoot = $PWD.ProviderPath
$done = 0
$failedCount = 0
$prevTerminalPrompt = $env:GIT_TERMINAL_PROMPT
$env:GIT_TERMINAL_PROMPT = '0'

try {
    $repos | ForEach-Object -Parallel {
        Set-StrictMode -Version Latest
        $ErrorActionPreference = 'Continue'

        $repo = $_
        $destPath = Join-Path $using:targetRoot $repo.Name

        if (Test-Path -LiteralPath $destPath) {
            return [PSCustomObject]@{
                Name        = $repo.Name
                Status      = 'Skipped'
                OutputLines = @()
                ExitCode    = 0
            }
        }

        $maxAttempts = 2
        $cloneErr = @()
        $exitCode = 1

        for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
            $cloneErr = @(& git clone --quiet $repo.Url $destPath 2>&1)
            $exitCode = $LASTEXITCODE
            if ($exitCode -eq 0) {
                return [PSCustomObject]@{
                    Name        = $repo.Name
                    Status      = 'Cloned'
                    OutputLines = @()
                    ExitCode    = 0
                }
            }

            if (Test-Path -LiteralPath $destPath) {
                Remove-Item -LiteralPath $destPath -Recurse -Force -ErrorAction SilentlyContinue
            }

            if ($attempt -lt $maxAttempts) {
                Start-Sleep -Milliseconds 500
            }
        }

        return [PSCustomObject]@{
            Name        = $repo.Name
            Status      = 'Failed'
            OutputLines = @($cloneErr | ForEach-Object { [string]$_ })
            ExitCode    = $exitCode
        }
    } -ThrottleLimit 6 | ForEach-Object {
        if ($_.Status -eq 'Skipped') {
            $done++
            Write-Output "Skip [$done/$total] $($_.Name) (already exists)"
        }
        elseif ($_.Status -eq 'Cloned') {
            $done++
            Write-Output "Clone [$done/$total] $($_.Name) ok"
        }
        else {
            $failedCount++
            $detail = Format-NativeErrorDetail -OutputLines $_.OutputLines -ExitCode $_.ExitCode
            [Console]::Error.WriteLine("Clone $($_.Name) failed: $detail")
        }
    }
}
finally {
    $env:GIT_TERMINAL_PROMPT = $prevTerminalPrompt
}

if ($failedCount -gt 0) {
    exit 1
}
