Set-StrictMode -Version Latest

$script:commonParamNames = @(
    [System.Management.Automation.PSCmdlet]::CommonParameters
    [System.Management.Automation.PSCmdlet]::OptionalCommonParameters
    'vb', 'db', 'ea', 'wa', 'infa', 'proga', 'ev', 'wv', 'iv', 'ov', 'ob', 'pv', 'wi', 'cf'
)
$script:cmdParamCache = @{}

function Get-RepoRootPath {
    return (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
}

function Resolve-VerifyTargetFile {
    param(
        [Parameter(Mandatory)]
        [string]$RepoRoot,
        [string[]]$TargetPaths = @(),
        [ValidateSet('all', 'cli', 'install')]
        [string]$TargetGroup = 'all'
    )

    if ($TargetPaths.Count -gt 0) {
        $resolved = [System.Collections.Generic.List[System.IO.FileInfo]]::new()
        foreach ($tp in $TargetPaths) {
            $full = (Resolve-Path -LiteralPath $tp -ErrorAction Stop).Path
            $resolved.Add((Get-Item -LiteralPath $full))
        }
        return @($resolved)
    }

    $cliRoot = Join-Path $RepoRoot 'cli'
    $scriptsRoot = Join-Path $RepoRoot 'scripts'
    $testsRoot = Join-Path $RepoRoot 'tests'

    $installFiles = @(
        Get-ChildItem -LiteralPath $scriptsRoot -Recurse -File |
            Where-Object { $_.Extension -in @('.ps1', '.psm1') } |
            Sort-Object FullName
    )

    if ($TargetGroup -eq 'install') {
        return @($installFiles)
    }

    $list = [System.Collections.Generic.List[System.IO.FileInfo]]::new()
    foreach ($item in @(Get-ChildItem -LiteralPath $cliRoot -Filter '*.ps1' -File)) {
        $list.Add($item)
    }
    foreach ($item in @(Get-ChildItem -LiteralPath (Join-Path $cliRoot 'helpers') -Filter '*.psm1' -File)) {
        $list.Add($item)
    }
    foreach ($item in @(Get-ChildItem -LiteralPath $testsRoot -Filter '*.ps1' -File)) {
        $list.Add($item)
    }
    foreach ($item in @(Get-ChildItem -LiteralPath $testsRoot -Filter '*.psm1' -File)) {
        $list.Add($item)
    }
    if ($TargetGroup -eq 'all') {
        foreach ($item in $installFiles) {
            $list.Add($item)
        }
    }

    return @($list)
}

function Get-FormatterOnlySetting {
    param(
        [Parameter(Mandatory)]
        [string]$SettingsPath
    )

    $base = Import-PowerShellDataFile -LiteralPath $SettingsPath
    $exclude = [System.Collections.Generic.List[string]]::new()
    if ($base.ContainsKey('ExcludeRules')) {
        foreach ($r in @($base['ExcludeRules'])) {
            $exclude.Add([string]$r)
        }
    }
    if (-not $exclude.Contains('PSUseCorrectCasing')) {
        $exclude.Add('PSUseCorrectCasing')
    }

    $rules = @{}
    if ($base.ContainsKey('Rules')) {
        foreach ($k in $base['Rules'].Keys) {
            if ($k -ne 'PSUseCorrectCasing') {
                $rules[$k] = $base['Rules'][$k]
            }
        }
    }

    return @{
        Severity            = $base['Severity']
        IncludeDefaultRules = $base['IncludeDefaultRules']
        ExcludeRules        = @($exclude)
        Rules               = $rules
    }
}

$script:coreModulesWarmed = $false

function Get-CachedCmdletParameterSet {
    param(
        [Parameter(Mandatory)]
        [string]$CommandName
    )

    $cacheKey = $CommandName.ToLowerInvariant()
    if ($script:cmdParamCache.ContainsKey($cacheKey)) {
        return $script:cmdParamCache[$cacheKey]
    }

    if (-not $script:coreModulesWarmed) {
        $null = Get-Command -CommandType Cmdlet -Module @(
            'Microsoft.PowerShell.Core',
            'Microsoft.PowerShell.Management',
            'Microsoft.PowerShell.Utility',
            'Microsoft.PowerShell.Security',
            'Microsoft.PowerShell.Archive',
            'PSScriptAnalyzer'
        ) -ErrorAction SilentlyContinue
        $script:coreModulesWarmed = $true
    }

    $hadAutoLoad = Test-Path -LiteralPath 'Variable:\global:PSModuleAutoLoadingPreference'
    $prevAutoLoad = $hadAutoLoad ? $global:PSModuleAutoLoadingPreference : $null
    $cmdInfo = $null
    try {
        $global:PSModuleAutoLoadingPreference = [System.Management.Automation.PSModuleAutoLoadingPreference]::None
        $cmdInfo = Get-Command -Name $CommandName -CommandType Cmdlet -ErrorAction SilentlyContinue | Select-Object -First 1
    }
    finally {
        if ($hadAutoLoad) {
            $global:PSModuleAutoLoadingPreference = $prevAutoLoad
        }
        else {
            Remove-Variable -Name 'PSModuleAutoLoadingPreference' -Scope Global -ErrorAction SilentlyContinue
        }
    }
    if ($null -eq $cmdInfo) {
        $script:cmdParamCache[$cacheKey] = $null
        return $null
    }

    $names = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($p in $cmdInfo.Parameters.Values) {
        [void]$names.Add($p.Name)
        foreach ($alias in $p.Aliases) {
            [void]$names.Add($alias)
        }
    }
    foreach ($cp in $script:commonParamNames) {
        [void]$names.Add($cp)
    }

    if ($cmdInfo.Name -match '^(?:Get|Set|New|Remove|Copy|Move|Rename|Clear|Add|Test)-(?:Item|ItemProperty|ChildItem|Content|Path)$') {
        $probeTargets = @($PWD.ProviderPath)
        if ($IsWindows) {
            $probeTargets += 'HKLM:\'
        }
        foreach ($probe in $probeTargets) {
            try {
                $dynInfo = Get-Command -Name $cmdInfo.Name -ArgumentList $probe -ErrorAction SilentlyContinue | Select-Object -First 1
                if ($null -ne $dynInfo) {
                    foreach ($dp in $dynInfo.Parameters.Values) {
                        [void]$names.Add($dp.Name)
                        foreach ($alias in $dp.Aliases) {
                            [void]$names.Add($alias)
                        }
                    }
                }
            }
            catch {
                $null = $_
            }
        }
    }

    $script:cmdParamCache[$cacheKey] = $names
    return $names
}

function Test-PowerShellAstContract {
    param(
        [Parameter(Mandatory)]
        [System.IO.FileInfo]$FileInfo,
        [Parameter(Mandatory)]
        [System.Management.Automation.Language.Ast]$Ast,
        [Parameter(Mandatory)]
        [string]$RawContent,
        [Parameter(Mandatory)]
        [string]$RelativePath,
        [Parameter(Mandatory)]
        [string]$CliRoot
    )

    $contractFailures = [System.Collections.Generic.List[string]]::new()
    $isCliScript = ($FileInfo.DirectoryName -eq $CliRoot) -and ($FileInfo.Extension -eq '.ps1')
    $scriptsRoot = Join-Path (Split-Path -Parent $CliRoot) 'scripts'
    $isTierB = $FileInfo.FullName.StartsWith($scriptsRoot + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)
    $isCrossPlat = (-not $isTierB) -and ($RawContent -notmatch '(?m)^#Requires\s+-Version\s+5\.1\b')

    if ($isTierB -and ($FileInfo.Extension -in @('.ps1', '.psm1'))) {
        if ($RawContent -notmatch '(?m)^#Requires\s+-Version\s+5\.1\b') {
            $contractFailures.Add("${RelativePath}: missing Tier B header '#Requires -Version 5.1'")
        }
        if ($RawContent -notmatch '(?m)^Set-StrictMode\s+-Version\s+Latest\b') {
            $contractFailures.Add("${RelativePath}: missing 'Set-StrictMode -Version Latest'")
        }
    }

    if ($isCliScript) {
        if (-not $RawContent.StartsWith('#!/usr/bin/env -S pwsh -NoLogo -NoProfile')) {
            $contractFailures.Add("${RelativePath}: missing Tier A shebang '#!/usr/bin/env -S pwsh -NoLogo -NoProfile'")
        }
        if ($RawContent -notmatch '(?m)^Set-StrictMode\s+-Version\s+Latest\b') {
            $contractFailures.Add("${RelativePath}: missing 'Set-StrictMode -Version Latest'")
        }
        if ($RawContent -notmatch '(?m)^\$ErrorActionPreference\s*=\s*''Stop''\s*$') {
            $contractFailures.Add("${RelativePath}: missing ""`$ErrorActionPreference = 'Stop'""")
        }
        if ($RawContent -notmatch '\[Console\]::OutputEncoding') {
            $contractFailures.Add("${RelativePath}: missing [Console]::OutputEncoding UTF-8 setup")
        }
    }

    if ($isCrossPlat) {
        $envVars = $Ast.FindAll({
                param($node)
                $node -is [System.Management.Automation.Language.VariableExpressionAst] -and
                $node.VariablePath.IsDriveQualified -and
                $node.VariablePath.DriveName -eq 'env'
            }, $true)
        foreach ($ev in $envVars) {
            $varKey = $ev.VariablePath.UserPath -replace '^env:', ''
            if (($varKey -ieq 'path') -and ($varKey -cne 'PATH')) {
                $contractFailures.Add("${RelativePath}:$($ev.Extent.StartLineNumber): use uppercase `$env:PATH instead of `$env:$varKey")
            }
        }
    }

    $navCmdlets = @('Test-Path', 'Get-Item', 'Get-Content', 'Copy-Item', 'Move-Item', 'Remove-Item', 'Resolve-Path')
    $commands = $Ast.FindAll({
            param($node)
            $node -is [System.Management.Automation.Language.CommandAst]
        }, $true)

    foreach ($cmdAst in $commands) {
        $cmdName = $cmdAst.GetCommandName()
        if ([string]::IsNullOrWhiteSpace($cmdName)) {
            continue
        }

        $paramSet = Get-CachedCmdletParameterSet -CommandName $cmdName
        if ($null -ne $paramSet) {
            foreach ($el in $cmdAst.CommandElements) {
                if ($el -is [System.Management.Automation.Language.CommandParameterAst]) {
                    $pName = $el.ParameterName
                    # Registry provider dynamic parameter -Type is unavailable when probing on non-Windows hosts.
                    if ((-not $IsWindows) -and $isTierB -and ($cmdName -eq 'Set-ItemProperty') -and ($pName -ieq 'Type')) {
                        continue
                    }
                    if (-not $paramSet.Contains($pName)) {
                        $prefixMatches = @($paramSet | Where-Object { $_.StartsWith($pName, [System.StringComparison]::OrdinalIgnoreCase) })
                        if ($prefixMatches.Count -ne 1) {
                            $contractFailures.Add("${RelativePath}:$($el.Extent.StartLineNumber): invalid parameter -$pName for cmdlet $cmdName")
                        }
                    }
                }
            }
        }

        if ($isCrossPlat -and ($cmdName -in $navCmdlets)) {
            $cmdText = $cmdAst.Extent.Text
            $hasLiteral = $cmdText -match '-LiteralPath\b'
            $hasFilter = $cmdText -match '-Filter\b'
            $isNonFileProvider = $cmdText -match '\b(?:Env|Variable|Function|Alias|HKLM|HKCU):'
            if ((-not $hasLiteral) -and (-not $hasFilter) -and (-not $isNonFileProvider)) {
                $contractFailures.Add("${RelativePath}:$($cmdAst.Extent.StartLineNumber): pass -LiteralPath to $cmdName")
            }
        }
    }

    return @($contractFailures)
}

function Invoke-ScriptAnalyzerSafe {
    param(
        [Parameter(Mandatory)]
        [string]$TargetPath,
        [Parameter(Mandatory)]
        [object]$Settings,
        [switch]$IncludeSuppressed
    )

    # PowerShell 7.7.0 CommandInfo.Parameters can race once during PSScriptAnalyzer cold analysis.
    for ($attempt = 1; $attempt -le 3; $attempt++) {
        try {
            if ($IncludeSuppressed) {
                return @(Invoke-ScriptAnalyzer -Path $TargetPath -Settings $Settings -IncludeSuppressed -ErrorAction Stop)
            }
            return @(Invoke-ScriptAnalyzer -Path $TargetPath -Settings $Settings -ErrorAction Stop)
        }
        catch [System.NullReferenceException] {
            if ($attempt -eq 3) {
                throw
            }
        }
    }
}

function Invoke-ParallelProcessTask {
    param(
        [Parameter(Mandatory)]
        [object[]]$Tasks,
        [int]$ThrottleLimit = 8
    )

    $results = [System.Collections.Generic.List[object]]::new()
    $limit = [Math]::Max(1, $ThrottleLimit)
    for ($offset = 0; $offset -lt $Tasks.Count; $offset += $limit) {
        $batchEnd = [Math]::Min($Tasks.Count - 1, $offset + $limit - 1)
        $running = [System.Collections.Generic.List[object]]::new()
        for ($idx = $offset; $idx -le $batchEnd; $idx++) {
            $task = $Tasks[$idx]
            $psi = [System.Diagnostics.ProcessStartInfo]::new()
            $psi.FileName = [string]$task.FileName
            foreach ($a in @($task.Arguments)) {
                [void]$psi.ArgumentList.Add([string]$a)
            }
            $psi.UseShellExecute = $false
            $psi.RedirectStandardOutput = $true
            $psi.RedirectStandardError = $true
            $psi.StandardOutputEncoding = [System.Text.UTF8Encoding]::new($false)
            $psi.StandardErrorEncoding = [System.Text.UTF8Encoding]::new($false)

            $proc = [System.Diagnostics.Process]::Start($psi)
            $outTask = $proc.StandardOutput.ReadToEndAsync()
            $errTask = $proc.StandardError.ReadToEndAsync()
            $running.Add([PSCustomObject]@{
                    Label   = [string]$task.Label
                    Process = $proc
                    OutTask = $outTask
                    ErrTask = $errTask
                })
        }

        foreach ($item in $running) {
            $item.Process.WaitForExit()
            $stdout = $item.OutTask.GetAwaiter().GetResult()
            $stderr = $item.ErrTask.GetAwaiter().GetResult()
            $exitCode = $item.Process.ExitCode
            $item.Process.Dispose()
            $results.Add([PSCustomObject]@{
                    Label    = $item.Label
                    ExitCode = $exitCode
                    Stdout   = $stdout
                    Stderr   = $stderr
                })
        }
    }

    return @($results)
}

Export-ModuleMember -Function @(
    'Get-RepoRootPath',
    'Resolve-VerifyTargetFile',
    'Get-FormatterOnlySetting',
    'Test-PowerShellAstContract',
    'Invoke-ScriptAnalyzerSafe',
    'Invoke-ParallelProcessTask'
)
