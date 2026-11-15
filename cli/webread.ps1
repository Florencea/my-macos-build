#!/usr/bin/env -S pwsh -NoLogo -NoProfile
<#
.SYNOPSIS
    Fetch and extract clean, secure, LLM-friendly Markdown from any webpage.
.DESCRIPTION
    Cross-platform webpage and documentation reader for macOS and Windows 11 (PowerShell 7).
    Prioritizes Local-First parsing with zero third-party cloud dependencies via modern TypeScript & Node.js LTS,
    supports direct probing of /llms-full.txt and /llms.txt, and provides multi-tier Indirect Prompt Injection defense.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
[Console]::OutputEncoding = $utf8NoBom
$OutputEncoding = $utf8NoBom

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
webread: Clean, token-efficient, secure webpage and documentation reader for agents and humans.

Usage:
  webread [options] <url>

Options:
  -l, --llms            Probe and fetch /llms-full.txt or /llms.txt directly from site domain
  -s, --selector <sel>  Extract specific CSS selector, tag, or #id / .class locally
  -r, --raw             Fetch raw content without Markdown conversion
  -o, --output <file>   Save output directly to a file
  --jina, --external    Use external Jina Reader (r.jina.ai) as fallback (Opt-in only)
  --no-enclosure        Omit the <UNTRUSTED_EXTERNAL_WEB_CONTENT> security barrier
  --max-chars <n>       Maximum characters before safety truncation (default: 64000)
  -h, --help            Show this help message and exit

Security Invariants:
  - Local-First by default: Fetches directly from target origin; no URLs or payloads sent to third-party services.
  - Prompt Injection Defense: Automatically strips hidden CSS cloaking, HTML comments, and defangs instruction markers.
  - Context Flooding Guard: Circuit-breaker automatically truncates payloads exceeding safe token thresholds.

Examples:
  webread --llms https://viteplus.dev
  webread https://react.dev/learn/you-might-not-need-an-effect
  webread -s 'article' https://oxc.rs
  webread --raw https://example.com -o page.html
'@
}

$parserScript = Join-Path $scriptDir 'helpers' 'webread-parser.ts'

$Selector = ''
$Llms = $false
$Raw = $false
$Output = ''
$Help = $false
$UseJina = $false
$NoEnclosure = $false
$MaxChars = 64000
$targetUrl = ''

for ($i = 0; $i -lt $args.Count; $i++) {
    $arg = [string]$args[$i]
    if ($arg -match '^--?h(elp)?$') {
        $Help = $true
    }
    elseif ($arg -match '^--?l(lms)?$') {
        $Llms = $true
    }
    elseif ($arg -match '^--?r(aw)?$') {
        $Raw = $true
    }
    elseif ($arg -match '^--?(jina|external)$') {
        $UseJina = $true
    }
    elseif ($arg -eq '--no-enclosure') {
        $NoEnclosure = $true
    }
    elseif ($arg -eq '--max-chars') {
        if ($i + 1 -ge $args.Count) {
            [Console]::Error.WriteLine('Error: --max-chars requires a numeric argument')
            exit 1
        }
        try {
            $MaxChars = ConvertTo-ValidatedInt -Value ([string]$args[++$i]) -OptionName '--max-chars' -MinValue 1
        }
        catch [System.ArgumentException] {
            [Console]::Error.WriteLine("Error: $($_.Exception.Message)")
            exit 1
        }
    }
    elseif ($arg -match '^--?s(elector)?$') {
        if ($i + 1 -ge $args.Count) {
            [Console]::Error.WriteLine('Error: --selector requires a CSS selector argument')
            exit 1
        }
        $Selector = [string]$args[++$i]
    }
    elseif ($arg -match '^--?o(utput)?$') {
        if ($i + 1 -ge $args.Count) {
            [Console]::Error.WriteLine('Error: --output requires a file path argument')
            exit 1
        }
        $Output = [string]$args[++$i]
    }
    elseif ($arg.StartsWith('-')) {
        [Console]::Error.WriteLine("Error: Unknown option $arg")
        Show-Help
        exit 1
    }
    elseif (-not $targetUrl) {
        $targetUrl = $arg
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

if (-not $targetUrl) {
    [Console]::Error.WriteLine('Error: URL is required')
    Show-Help
    exit 1
}

$targetUrl = $targetUrl.Trim()
if ($targetUrl -notmatch '^https?://') {
    $targetUrl = "https://$targetUrl"
}

$curlBin = $IsWindows ? 'curl.exe' : 'curl'
if (-not (Test-RequiredCommand -Name $curlBin)) {
    exit 1
}
$curlCmd = (Get-Command $curlBin).Source

$nullDevice = $IsWindows ? 'NUL' : '/dev/null'
$userAgent = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36'
$acceptHeader = 'text/markdown, text/plain;q=0.95, text/html;q=0.9, application/xhtml+xml;q=0.8, application/json;q=0.7'
$repoRoot = Split-Path -Parent $scriptDir

function Resolve-GitHubRawUrl {
    param(
        [string]$UriText
    )

    if ($Raw) {
        return $null
    }

    if ($UriText -match '^https?://github\.com/([^/]+)/([^/]+)/blob/([^?#]+)(?:\?.*)?(?:#.*)?$') {
        $owner = $Matches[1]
        $repo = $Matches[2]
        $branchAndPath = $Matches[3]
        return "https://raw.githubusercontent.com/$owner/$repo/$branchAndPath"
    }

    return $null
}

function Invoke-LocalParser {
    param(
        [string]$RawText,
        [string]$SourceUrl,
        [string]$ContentType = ''
    )

    $nodeModulesReady = Test-Path -LiteralPath (Join-Path $repoRoot 'node_modules' 'defuddle') -PathType Container
    if ((Test-Path -LiteralPath $parserScript -PathType Leaf) -and $nodeModulesReady -and (Get-Command 'vp' -ErrorAction SilentlyContinue)) {
        $parserArgs = @(
            'node',
            $parserScript,
            '--url', $SourceUrl,
            '--max-chars', [string]$MaxChars
        )
        if ($ContentType) {
            $parserArgs += @('--content-type', $ContentType)
        }
        if ($Selector) {
            $parserArgs += @('--selector', $Selector)
        }
        if ($Raw) {
            $parserArgs += @('--raw')
        }
        if ($NoEnclosure) {
            $parserArgs += @('--no-enclosure')
        }

        $output = @($RawText | & vp @parserArgs)
        if ($LASTEXITCODE -eq 0) {
            return ($output -join "`n")
        }
    }

    if (-not $nodeModulesReady) {
        [Console]::Error.WriteLine("Notice: node_modules not installed in $repoRoot (run 'vp install'), outputting direct fetch.")
    }
    else {
        [Console]::Error.WriteLine('Notice: webread-parser.ts unavailable or failed, outputting direct fetch.')
    }
    return $RawText
}

function Invoke-CurlPayload {
    param(
        [string[]]$CurlArgs
    )

    $bodyFile = [System.IO.Path]::GetTempFileName()
    try {
        $metaLine = (& $curlCmd @CurlArgs -o $bodyFile -w '%{http_code}`t%{content_type}`t%{url_effective}' 2>$null)
        if ($LASTEXITCODE -ne 0 -or (-not (Test-Path -LiteralPath $bodyFile -PathType Leaf))) {
            return $null
        }

        $bodyText = [System.IO.File]::ReadAllText($bodyFile, $utf8NoBom)
        if ([string]::IsNullOrEmpty($bodyText)) {
            return $null
        }

        $parts = ([string]$metaLine).Split("`t")
        $contentType = $parts.Count -ge 2 ? $parts[1] : ''
        $effectiveUrl = ($parts.Count -ge 3 -and $parts[2]) ? $parts[2] : ''

        return [PSCustomObject]@{
            Body         = $bodyText
            ContentType  = $contentType
            EffectiveUrl = $effectiveUrl
        }
    }
    finally {
        Remove-Item -LiteralPath $bodyFile -Force -ErrorAction SilentlyContinue
    }
}

function Get-WebreadContent {
    param(
        [string]$UrlToFetch,
        [string]$CurrentMode
    )

    # 1. Probe /llms-full.txt or /llms.txt directly from origin
    if ($CurrentMode -eq 'llms') {
        try {
            $uri = [System.Uri]$UrlToFetch
            $origin = "$($uri.Scheme)://$($uri.Authority)"
        }
        catch {
            [Console]::Error.WriteLine("Error: Invalid URI '$UrlToFetch'")
            return $null
        }

        foreach ($candidatePath in @('/llms-full.txt', '/llms.txt')) {
            $probeUrl = "$origin$candidatePath"
            $statusCode = (& $curlCmd -sL -w '%{http_code}' -o $nullDevice $probeUrl)
            if ($statusCode -eq '200') {
                $payload = Invoke-CurlPayload -CurlArgs @('-fsL', '-A', $userAgent, $probeUrl)
                if ($null -ne $payload) {
                    $resolvedUrl = $payload.EffectiveUrl ? $payload.EffectiveUrl : $probeUrl
                    return (Invoke-LocalParser -RawText $payload.Body -SourceUrl $resolvedUrl -ContentType $payload.ContentType)
                }
            }
        }

        [Console]::Error.WriteLine("Notice: Neither /llms-full.txt nor /llms.txt found on $origin, falling back to local reader...")
    }

    # 2. Opt-in External Jina Reader
    if ($UseJina) {
        [Console]::Error.WriteLine('Notice: Using external Jina Reader service (r.jina.ai)...')
        $jinaUrl = "https://r.jina.ai/$UrlToFetch"
        $payload = Invoke-CurlPayload -CurlArgs @('-fsL', '--max-time', '15', '-H', 'X-No-Cache: true', $jinaUrl)
        if ($null -ne $payload -and ($payload.Body -notmatch 'Request failed with status code')) {
            $jinaContentType = $payload.ContentType ? $payload.ContentType : 'text/markdown'
            return (Invoke-LocalParser -RawText $payload.Body -SourceUrl $UrlToFetch -ContentType $jinaContentType)
        }
        [Console]::Error.WriteLine('Notice: External Jina Reader unavailable, falling back to local reader...')
    }

    # 3. GitHub blob -> raw.githubusercontent.com rewrite for direct Markdown/source reading
    $githubRawUrl = Resolve-GitHubRawUrl -UriText $UrlToFetch
    if ($null -ne $githubRawUrl) {
        $rawPayload = Invoke-CurlPayload -CurlArgs @('-fsL', '--max-time', '20', '-A', $userAgent, $githubRawUrl)
        if ($null -ne $rawPayload) {
            $resolvedRawUrl = $rawPayload.EffectiveUrl ? $rawPayload.EffectiveUrl : $githubRawUrl
            $rawContentType = $rawPayload.ContentType ? $rawPayload.ContentType : 'text/plain'
            return (Invoke-LocalParser -RawText $rawPayload.Body -SourceUrl $resolvedRawUrl -ContentType $rawContentType)
        }
    }

    # 4. Local-First Safe Fetch with Content Negotiation (Default)
    $fetchedPayload = Invoke-CurlPayload -CurlArgs @('-fsL', '--max-time', '20', '-A', $userAgent, '-H', "Accept: $acceptHeader", $UrlToFetch)
    if ($null -eq $fetchedPayload) {
        [Console]::Error.WriteLine("Error: Failed to fetch content from $UrlToFetch")
        return $null
    }

    $resolvedFetchUrl = $fetchedPayload.EffectiveUrl ? $fetchedPayload.EffectiveUrl : $UrlToFetch
    return (Invoke-LocalParser -RawText $fetchedPayload.Body -SourceUrl $resolvedFetchUrl -ContentType $fetchedPayload.ContentType)
}

$activeMode = $Llms ? 'llms' : 'local'
$result = Get-WebreadContent -UrlToFetch $targetUrl -CurrentMode $activeMode

if ([string]::IsNullOrEmpty($result)) {
    exit 1
}

if ($Output) {
    $absOut = [System.IO.Path]::GetFullPath($Output, $PWD.ProviderPath)
    $outDir = Split-Path -Parent $absOut
    if ($outDir -and (-not (Test-Path -LiteralPath $outDir -PathType Container))) {
        New-Item -ItemType Directory -Force -Path $outDir | Out-Null
    }
    $newline = $IsWindows ? "`r`n" : "`n"
    $normalizedText = (($result -replace "`r`n", "`n") -replace "`n", $newline).TrimEnd("`r", "`n") + $newline
    [System.IO.File]::WriteAllText($absOut, $normalizedText, [System.Text.UTF8Encoding]::new($false))
    Write-Output "Content saved to $Output"
}
else {
    Write-Output $result
}
