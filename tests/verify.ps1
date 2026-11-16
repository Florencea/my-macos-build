#!/usr/bin/env -S pwsh -NoLogo -NoProfile
<#
.SYNOPSIS
    Unified verification gate for PowerShell, Shell, TypeScript, and Markdown assets in my-machine-build.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

$fixMode = $false
$scope = 'all'
$validScopes = @('all', 'ps', 'shell', 'vp', 'cli')
$targetPaths = [System.Collections.Generic.List[string]]::new()
for ($i = 0; $i -lt $args.Count; $i++) {
    $arg = [string]$args[$i]
    if ($arg -eq '--fix') {
        $fixMode = $true
    }
    elseif ($arg -match '^--?scope=(.+)$') {
        $scope = $Matches[1].ToLowerInvariant()
    }
    elseif ($arg -match '^--?scope$') {
        if ($i + 1 -ge $args.Count) {
            [Console]::Error.WriteLine('Error: --scope requires a value (all|ps|shell|vp|cli)')
            exit 1
        }
        $i++
        $scope = ([string]$args[$i]).ToLowerInvariant()
    }
    elseif ($arg -match '^--?path=(.+)$') {
        $targetPaths.Add($Matches[1])
    }
    elseif ($arg -match '^--?path$') {
        if ($i + 1 -ge $args.Count) {
            [Console]::Error.WriteLine('Error: --path requires a file path')
            exit 1
        }
        $i++
        $targetPaths.Add([string]$args[$i])
    }
    elseif ($arg -match '^--?h(elp)?$') {
        Write-Output 'Usage: pwsh -NoLogo -NoProfile -File tests/verify.ps1 [--fix] [--scope all|ps|shell|vp|cli] [--path <file>]'
        exit 0
    }
    else {
        [Console]::Error.WriteLine("Error: Unknown option $arg")
        exit 1
    }
}

if ($scope -notin $validScopes) {
    [Console]::Error.WriteLine("Error: Invalid scope '$scope'. Expected one of: $($validScopes -join ', ')")
    exit 1
}

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$settingsPath = Join-Path $repoRoot 'PSScriptAnalyzerSettings.psd1'
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
$failures = [System.Collections.Generic.List[string]]::new()
$script:cmdParamCache = @{}
$script:commonParamNames = @(
    [System.Management.Automation.PSCmdlet]::CommonParameters
    [System.Management.Automation.PSCmdlet]::OptionalCommonParameters
    'vb', 'db', 'ea', 'wa', 'infa', 'proga', 'ev', 'wv', 'iv', 'ov', 'ob', 'pv', 'wi', 'cf'
)

function Get-CachedCmdletParameterSet {
    param(
        [Parameter(Mandatory)]
        [string]$CommandName
    )

    $cacheKey = $CommandName.ToLowerInvariant()
    if ($script:cmdParamCache.ContainsKey($cacheKey)) {
        return $script:cmdParamCache[$cacheKey]
    }

    $cmdInfo = Get-Command -Name $CommandName -CommandType Cmdlet -ErrorAction SilentlyContinue | Select-Object -First 1
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

    # Include dynamic provider parameters (FileSystem and Windows Registry) for item/content cmdlets.
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
                # Ignore provider contexts that do not support the probed cmdlet.
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
    $isCrossPlat = ($FileInfo.Name -ne 'install.ps1') -and ($RawContent -notmatch '(?m)^#Requires\s+-Version\s+5\.1\b')

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

function Invoke-AnalyzerSafe {
    param(
        [Parameter(Mandatory)]
        [string]$TargetPath,
        [Parameter(Mandatory)]
        [object]$Settings
    )

    # PowerShell 7.7.0 CommandInfo.Parameters can race once during PSScriptAnalyzer cold parallel analysis.
    for ($attempt = 1; $attempt -le 2; $attempt++) {
        try {
            return @(Invoke-ScriptAnalyzer -Path $TargetPath -Settings $Settings -IncludeSuppressed -ErrorAction Stop)
        }
        catch [System.NullReferenceException] {
            if ($attempt -eq 2) {
                throw
            }
        }
    }
}

# 1. PowerShell Formatting, AST, Compatibility, and Static Analysis
if ($scope -in @('all', 'ps')) {
    $cliRoot = Join-Path $repoRoot 'cli'
    $installPs1 = Join-Path $repoRoot 'scripts' 'install.ps1'

    if ($targetPaths.Count -gt 0) {
        $psFiles = @(foreach ($tp in $targetPaths) {
                $resolvedTarget = (Resolve-Path -LiteralPath $tp -ErrorAction Stop).Path
                Get-Item -LiteralPath $resolvedTarget
            })
    }
    else {
        $psFiles = @(
            Get-ChildItem -LiteralPath $cliRoot -Filter '*.ps1' -File
            Get-ChildItem -LiteralPath (Join-Path $cliRoot 'helpers') -Filter '*.psm1' -File
            Get-Item -LiteralPath $installPs1
            Get-ChildItem -LiteralPath (Join-Path $repoRoot 'tests') -Filter '*.ps1' -File
        )
    }

    $cliCompatSettings = @{
        IncludeRules = @('PSUseCompatibleCommands', 'PSUseCompatibleTypes')
        Rules        = @{
            PSUseCompatibleCommands = @{
                Enable         = $true
                TargetProfiles = @(
                    'ubuntu_x64_18.04_7.0.0_x64_3.1.2_core',
                    'win-4_x64_10.0.18362.0_7.0.0_x64_3.1.2_core'
                )
                IgnoreCommands = @('Resolve-DnsName', 'node')
            }
            PSUseCompatibleTypes    = @{
                Enable         = $true
                TargetProfiles = @(
                    'ubuntu_x64_18.04_7.0.0_x64_3.1.2_core',
                    'win-4_x64_10.0.18362.0_7.0.0_x64_3.1.2_core'
                )
            }
        }
    }

    $installCompatSettings = @{
        IncludeRules = @('PSUseCompatibleSyntax', 'PSUseCompatibleCommands', 'PSUseCompatibleTypes')
        Rules        = @{
            PSUseCompatibleSyntax   = @{
                Enable         = $true
                TargetVersions = @('5.1', '7.4')
            }
            PSUseCompatibleCommands = @{
                Enable         = $true
                TargetProfiles = @(
                    'win-48_x64_10.0.17763.0_5.1.17763.316_x64_4.0.30319.42000_framework',
                    'win-4_x64_10.0.18362.0_7.0.0_x64_3.1.2_core'
                )
                IgnoreCommands = @('Set-ItemProperty')
            }
            PSUseCompatibleTypes    = @{
                Enable         = $true
                TargetProfiles = @(
                    'win-48_x64_10.0.17763.0_5.1.17763.316_x64_4.0.30319.42000_framework',
                    'win-4_x64_10.0.18362.0_7.0.0_x64_3.1.2_core'
                )
            }
        }
    }

    foreach ($file in $psFiles) {
        $relPath = [System.IO.Path]::GetRelativePath($repoRoot, $file.FullName) -replace '\\', '/'
        $raw = [System.IO.File]::ReadAllText($file.FullName)
        $formatted = Invoke-Formatter -ScriptDefinition $raw -Settings $settingsPath
        $expected = ($formatted -replace "`r`n", "`n").TrimEnd() + "`n"

        $effectiveContent = $raw
        if ($raw -cne $expected) {
            if ($fixMode) {
                [System.IO.File]::WriteAllText($file.FullName, $expected, $utf8NoBom)
                $effectiveContent = $expected
                Write-Output "[FIXED] Format $relPath"
            }
            else {
                $failures.Add("Format drift in $relPath (run with --fix)")
            }
        }

        $parseErrors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$null, [ref]$parseErrors)
        if ($parseErrors) {
            $failures.Add("AST syntax errors in ${relPath}: $($parseErrors -join '; ')")
        }
        else {
            foreach ($cf in @(Test-PowerShellAstContract -FileInfo $file -Ast $ast -RawContent $effectiveContent -RelativePath $relPath -CliRoot $cliRoot)) {
                $failures.Add($cf)
            }
        }

        $violations = @(Invoke-AnalyzerSafe -TargetPath $file.FullName -Settings $settingsPath)
        if ($violations.Count -gt 0) {
            $violations | Format-Table RuleName, Severity, Line, Message -AutoSize
            $failures.Add("PSScriptAnalyzer reported $($violations.Count) violation(s) in $relPath")
        }

        $isUnderCli = $file.FullName.StartsWith($cliRoot + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)
        if ($isUnderCli) {
            $cliCompatViolations = @(Invoke-AnalyzerSafe -TargetPath $file.FullName -Settings $cliCompatSettings)
            if ($cliCompatViolations.Count -gt 0) {
                $cliCompatViolations | Format-Table RuleName, Severity, Line, Message -AutoSize
                $failures.Add("Cross-platform compatibility rules failed on $relPath")
            }
        }
        elseif ($file.FullName -ieq $installPs1) {
            $installCompatViolations = @(Invoke-AnalyzerSafe -TargetPath $file.FullName -Settings $installCompatSettings)
            if ($installCompatViolations.Count -gt 0) {
                $installCompatViolations | Format-Table RuleName, Severity, Line, Message -AutoSize
                $failures.Add('PSUseCompatible* failed on scripts/install.ps1')
            }
        }
    }
}

# 2. Shell Syntax and shfmt Verification
if ($scope -in @('all', 'shell')) {
    $zshFiles = @(
        (Join-Path $repoRoot 'scripts' 'install.sh'),
        (Join-Path $repoRoot 'configs' 'zsh' 'zshenv'),
        (Join-Path $repoRoot 'configs' 'zsh' 'zprofile'),
        (Join-Path $repoRoot 'configs' 'zsh' 'zshrc')
    ) + @(Get-ChildItem -LiteralPath (Join-Path $repoRoot 'configs' 'zsh' 'completions') -File | ForEach-Object { $_.FullName })

    $bashFiles = @(
        (Join-Path $repoRoot 'configs' 'bash' 'bash_profile'),
        (Join-Path $repoRoot 'configs' 'bash' 'bashrc'),
        (Join-Path $repoRoot 'configs' 'git' 'hooks' 'pre-commit.sh')
    )

    if (Get-Command 'zsh' -ErrorAction SilentlyContinue) {
        foreach ($zf in $zshFiles) {
            & zsh -n $zf
            if ($LASTEXITCODE -ne 0) {
                $failures.Add("zsh -n failed for $zf")
            }
        }
    }

    if (Get-Command 'bash' -ErrorAction SilentlyContinue) {
        foreach ($bf in $bashFiles) {
            & bash -n $bf
            if ($LASTEXITCODE -ne 0) {
                $failures.Add("bash -n failed for $bf")
            }
        }
    }

    if (Get-Command 'shfmt' -ErrorAction SilentlyContinue) {
        $allShellFiles = $zshFiles + $bashFiles
        $shfmtFlag = $fixMode ? '-w' : '-d'
        & shfmt -i 2 -ci $shfmtFlag @allShellFiles
        if ($LASTEXITCODE -ne 0) {
            $failures.Add('shfmt check failed')
        }
    }
}

# 3. Vite+ Check (Format, Type-Aware Lint, Typecheck) & Vitest Unit Tests
if ($scope -in @('all', 'vp')) {
    if (Get-Command 'vp' -ErrorAction SilentlyContinue) {
        $hasVitePlus = Test-Path -LiteralPath (Join-Path $repoRoot 'node_modules' 'vite-plus') -PathType Container
        if (-not $hasVitePlus) {
            $failures.Add("node_modules/vite-plus missing in $repoRoot (run 'vp install')")
        }
        else {
            if ($fixMode) {
                & vp -C $repoRoot check --fix
            }
            else {
                & vp -C $repoRoot check
            }
            if ($LASTEXITCODE -ne 0) {
                $failures.Add('vp check failed')
            }

            & vp -C $repoRoot run typecheck
            if ($LASTEXITCODE -ne 0) {
                $failures.Add('vp run typecheck failed')
            }

            & vp -C $repoRoot test run --reporter=tap-flat --no-color
            if ($LASTEXITCODE -ne 0) {
                $failures.Add('vp test run failed')
            }
        }
    }
}

# 4. PowerShell Unit & Contract Tests
if ($scope -in @('all', 'cli')) {
    & pwsh -NoLogo -NoProfile -File (Join-Path $repoRoot 'tests' 'cli.Tests.ps1')
    if ($LASTEXITCODE -ne 0) {
        $failures.Add('cli.Tests.ps1 failed')
    }
}

if ($failures.Count -gt 0) {
    [Console]::Error.WriteLine("Verification failed with $($failures.Count) issue(s):")
    foreach ($item in $failures) {
        [Console]::Error.WriteLine("  - $item")
    }
    exit 1
}

Write-Output 'All repository script checks and tests passed.'
