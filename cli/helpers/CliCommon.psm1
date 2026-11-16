Set-StrictMode -Version Latest

function Resolve-CliScriptDirectory {
    param(
        [string]$ScriptRoot = '',
        [string]$CommandPath = ''
    )

    if (-not [string]::IsNullOrWhiteSpace($ScriptRoot)) {
        if (-not [string]::IsNullOrWhiteSpace($CommandPath) -and (Test-Path -LiteralPath $CommandPath -PathType Leaf)) {
            $cmdInfo = [System.IO.FileInfo]::new((Resolve-Path -LiteralPath $CommandPath).Path)
            if ($null -ne $cmdInfo.LinkTarget) {
                $targetInfo = $cmdInfo.ResolveLinkTarget($true)
                $realPath = ($null -ne $targetInfo) ? $targetInfo.FullName : $cmdInfo.FullName
                return (Split-Path -Parent $realPath)
            }
        }
        return $ScriptRoot
    }

    $targetPath = $CommandPath
    if ([string]::IsNullOrWhiteSpace($targetPath)) {
        $cmdArgs = [Environment]::GetCommandLineArgs()
        for ($i = 1; $i -lt $cmdArgs.Count; $i++) {
            $candidate = [string]$cmdArgs[$i]
            if ($candidate -and (-not $candidate.StartsWith('-')) -and (Test-Path -LiteralPath $candidate -PathType Leaf)) {
                $targetPath = $candidate
                break
            }
        }
    }

    if ([string]::IsNullOrWhiteSpace($targetPath)) {
        throw [System.InvalidOperationException]::new('Unable to determine script path.')
    }

    $resolvedPath = (Resolve-Path -LiteralPath $targetPath).Path
    $fileInfo = [System.IO.FileInfo]::new($resolvedPath)
    $targetInfo = $fileInfo.ResolveLinkTarget($true)
    $realPath = ($null -ne $targetInfo) ? $targetInfo.FullName : $fileInfo.FullName
    return (Split-Path -Parent $realPath)
}

function Test-RequiredCommand {
    param(
        [Parameter(Mandatory)]
        [string[]]$Name,
        [switch]$Quiet
    )

    $allAvailable = $true
    foreach ($cmd in $Name) {
        if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
            if (-not $Quiet) {
                [Console]::Error.WriteLine("Error: $cmd is not installed")
            }
            $allAvailable = $false
        }
    }
    return $allAvailable
}

function Convert-TimeToSecond {
    param(
        [Parameter(Mandatory)]
        [string]$TimeText,
        [switch]$PositiveOnly
    )

    $trimmed = $TimeText.Trim()
    $seconds = 0.0
    $culture = [System.Globalization.CultureInfo]::InvariantCulture
    $styles = [System.Globalization.NumberStyles]::Float

    if ($trimmed -match '^(\d+):(\d{2}):(\d{2}(?:\.\d+)?)$') {
        $hours = [double]::Parse($Matches[1], $culture)
        $minutes = [double]::Parse($Matches[2], $culture)
        $secs = [double]::Parse($Matches[3], $culture)
        if ($minutes -ge 60 -or $secs -ge 60) {
            throw [System.ArgumentException]::new("Invalid time value '$TimeText' (minutes/seconds must be < 60).")
        }
        $seconds = ($hours * 3600) + ($minutes * 60) + $secs
    }
    elseif ($trimmed -match '^(\d+):(\d{2}(?:\.\d+)?)$') {
        $minutes = [double]::Parse($Matches[1], $culture)
        $secs = [double]::Parse($Matches[2], $culture)
        if ($secs -ge 60) {
            throw [System.ArgumentException]::new("Invalid time value '$TimeText' (seconds must be < 60).")
        }
        $seconds = ($minutes * 60) + $secs
    }
    elseif (-not [double]::TryParse($trimmed, $styles, $culture, [ref]$seconds)) {
        throw [System.ArgumentException]::new("Invalid time value '$TimeText' (expected HH:MM:SS, MM:SS, or seconds).")
    }

    if ([double]::IsNaN($seconds) -or [double]::IsInfinity($seconds) -or ($seconds -lt 0)) {
        throw [System.ArgumentException]::new("Time value '$TimeText' must be a finite non-negative number.")
    }
    if ($PositiveOnly -and ($seconds -le 0)) {
        throw [System.ArgumentException]::new("Duration '$TimeText' must be greater than zero.")
    }

    return $seconds
}

function ConvertTo-ValidatedInt {
    param(
        [Parameter(Mandatory)]
        [string]$Value,
        [Parameter(Mandatory)]
        [string]$OptionName,
        [int]$MinValue = [int]::MinValue,
        [int]$MaxValue = [int]::MaxValue
    )

    $parsed = 0
    $culture = [System.Globalization.CultureInfo]::InvariantCulture
    if (-not [int]::TryParse($Value.Trim(), [System.Globalization.NumberStyles]::Integer, $culture, [ref]$parsed)) {
        throw [System.ArgumentException]::new("Invalid integer for ${OptionName}: '$Value'")
    }
    if ($parsed -lt $MinValue -or $parsed -gt $MaxValue) {
        throw [System.ArgumentException]::new("Value for $OptionName must be between $MinValue and $MaxValue (got $parsed).")
    }

    return $parsed
}

function Format-ByteSize {
    param(
        [Parameter(Mandatory)]
        [long]$ByteCount
    )

    if ($ByteCount -ge 1GB) {
        return ('{0:N1}G' -f ($ByteCount / 1GB))
    }
    if ($ByteCount -ge 1MB) {
        return ('{0:N1}M' -f ($ByteCount / 1MB))
    }
    return ('{0:N0}K' -f ($ByteCount / 1KB))
}

function Import-WindowsMachinePath {
    if (-not $IsWindows) {
        return
    }

    $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $entries = [System.Collections.Generic.List[string]]::new()

    $rawSources = @(
        $env:PATH,
        [Environment]::GetEnvironmentVariable('Path', 'User'),
        [Environment]::GetEnvironmentVariable('Path', 'Machine')
    )

    foreach ($raw in $rawSources) {
        if ([string]::IsNullOrWhiteSpace($raw)) {
            continue
        }
        foreach ($segment in ($raw -split ';')) {
            $trimmed = $segment.Trim()
            if ($trimmed -and $seen.Add($trimmed)) {
                $entries.Add($trimmed)
            }
        }
    }

    $env:PATH = $entries -join ';'
}

function Format-NativeErrorDetail {
    param(
        [AllowEmptyCollection()]
        [AllowNull()]
        [object[]]$OutputLines = @(),
        [int]$ExitCode = 1
    )

    $lines = @(
        foreach ($line in @($OutputLines)) {
            if ($null -eq $line) {
                continue
            }
            $text = ([string]$line).Trim()
            if ($text) {
                $text
            }
        }
    )

    if ($lines.Count -gt 0) {
        return ($lines -join ' | ')
    }
    return "exit code $ExitCode"
}

function Resolve-GitHubRepoList {
    param(
        [AllowNull()]
        [object]$RawResponse
    )

    $items = [System.Collections.Generic.List[pscustomobject]]::new()
    if ($null -eq $RawResponse) {
        return @($items)
    }

    $entries = ($RawResponse -is [System.Array]) ? $RawResponse : @($RawResponse)
    foreach ($entry in $entries) {
        if ($null -eq $entry) {
            continue
        }
        $sshProp = $entry.PSObject.Properties['ssh_url']
        if ($null -eq $sshProp -or [string]::IsNullOrWhiteSpace([string]$sshProp.Value)) {
            continue
        }
        $sshUrl = [string]$sshProp.Value
        $nameProp = $entry.PSObject.Properties['name']
        $repoName = ($null -ne $nameProp -and -not [string]::IsNullOrWhiteSpace([string]$nameProp.Value)) ? [string]$nameProp.Value : [System.IO.Path]::GetFileNameWithoutExtension($sshUrl)
        $items.Add([PSCustomObject]@{
                Name = $repoName
                Url  = $sshUrl
            })
    }

    return @($items)
}

function Invoke-SpinnerStep {
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        [Parameter(Mandatory)]
        [string]$Exe,
        [string[]]$Arguments = @(),
        [hashtable]$Environment = @{}
    )

    $Arguments = $Arguments ?? @()
    $frames = @('⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏')
    $frameIdx = 0

    $savedEnv = @{}
    foreach ($key in $Environment.Keys) {
        $k = [string]$key
        $savedEnv[$k] = [Environment]::GetEnvironmentVariable($k, 'Process')
        [Environment]::SetEnvironmentVariable($k, [string]$Environment[$key], 'Process')
    }

    $targetExe = $Exe
    $targetArgs = $Arguments
    $job = $null

    try {
        $job = Start-ThreadJob -ScriptBlock {
            $runExe = $using:targetExe
            $runArgs = $using:targetArgs
            try {
                $output = @(& $runExe @runArgs 2>&1)
                [PSCustomObject]@{
                    Output   = $output
                    ExitCode = ($LASTEXITCODE ?? 0)
                }
            }
            catch {
                [PSCustomObject]@{
                    Output   = @($_.ToString())
                    ExitCode = 1
                }
            }
        }

        $Host.UI.Write("`e[?25l`r  $($frames[$frameIdx]) $Message...")
        $frameIdx = ($frameIdx + 1) % $frames.Count

        while (-not $job.Finished.WaitOne(80)) {
            $Host.UI.Write("`r  $($frames[$frameIdx]) $Message...")
            $frameIdx = ($frameIdx + 1) % $frames.Count
        }

        $res = Receive-Job -Job $job
        $resObj = ($res -is [array]) ? $res[-1] : $res
        $output = @()
        $code = 0
        if ($null -ne $resObj) {
            $output = $resObj.Output ?? @()
            $code = [int]($resObj.ExitCode ?? 0)
        }
        else {
            $code = 1
            $output = @("Step '$Message' terminated unexpectedly.")
        }

        $Host.UI.Write("`r`e[K")
        if ($code -ne 0) {
            foreach ($line in $output) {
                [Console]::Error.WriteLine($line)
            }
            throw "Step failed with exit code $code"
        }
    }
    finally {
        $Host.UI.Write("`e[?25h")
        if ($null -ne $job) {
            if ($job.JobStateInfo.State -eq [System.Management.Automation.JobState]::Running) {
                Stop-Job -Job $job -ErrorAction SilentlyContinue
            }
            Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
        }
        foreach ($key in $savedEnv.Keys) {
            [Environment]::SetEnvironmentVariable([string]$key, $savedEnv[$key], 'Process')
        }
    }
}

Export-ModuleMember -Function @(
    'Resolve-CliScriptDirectory',
    'Test-RequiredCommand',
    'Convert-TimeToSecond',
    'ConvertTo-ValidatedInt',
    'Format-ByteSize',
    'Format-NativeErrorDetail',
    'Import-WindowsMachinePath',
    'Invoke-SpinnerStep',
    'Resolve-GitHubRepoList'
)
