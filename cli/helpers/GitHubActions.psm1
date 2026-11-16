Set-StrictMode -Version Latest

function Restore-GitHubWorkflow {
    # Prevent vp migrate and vp fmt from modifying CI workflows or action definitions during dependency updates.
    param(
        [switch]$IncludeActionsDir
    )

    $pathsToInspect = [System.Collections.Generic.List[string]]::new()
    if (Test-Path -LiteralPath '.github' -PathType Container) {
        $pathsToInspect.Add('.github')
    }
    if ($IncludeActionsDir -and (Test-Path -LiteralPath 'actions' -PathType Container)) {
        $pathsToInspect.Add('actions')
    }

    if ($pathsToInspect.Count -eq 0) {
        return
    }

    $diffLines = @(& git -c core.quotePath=false diff --relative --name-only -- @pathsToInspect 2>$null)
    if ($LASTEXITCODE -ne 0) {
        throw 'Failed to inspect GitHub Actions workflow changes after vp migrate'
    }

    $changedWorkflowFiles = @($diffLines | Where-Object {
            ($_ -imatch '^\.github/(workflows/[^/]+\.ya?ml|(.+/)?action\.ya?ml)$') -or
            ($IncludeActionsDir -and ($_ -imatch '^actions/'))
        })
    if ($changedWorkflowFiles.Count -eq 0) {
        return
    }

    & git checkout -q -- @changedWorkflowFiles
    if ($LASTEXITCODE -ne 0) {
        throw 'Failed to restore GitHub Actions workflow files after vp migrate'
    }
}

function Find-GitHubActionFile {
    if (-not (Test-Path -LiteralPath '.github' -PathType Container)) {
        return @()
    }

    $repoRoot = (Resolve-Path -LiteralPath '.').Path
    $githubDir = (Resolve-Path -LiteralPath '.github').Path
    $files = @(Get-ChildItem -LiteralPath $githubDir -Recurse -File | Where-Object {
            $_.Extension -in @('.yml', '.yaml')
        })

    $matched = [System.Collections.Generic.List[string]]::new()
    foreach ($file in $files) {
        $relPath = [System.IO.Path]::GetRelativePath($repoRoot, $file.FullName) -replace '\\', '/'
        if ($relPath -imatch '^\.github/(workflows/[^/]+\.ya?ml|(.+/)?action\.ya?ml)$') {
            $matched.Add($relPath)
        }
    }
    return @($matched | Sort-Object)
}

function ConvertFrom-GitHubActionVersion {
    param(
        [string]$Ref
    )

    if ($Ref -match '^(v)?(\d+)(?:\.(\d+)(?:\.(\d+))?)?$') {
        $hasVPrefix = $Matches.ContainsKey(1) -and (-not [string]::IsNullOrEmpty($Matches[1]))
        $hasMinor = $Matches.ContainsKey(3)
        $hasPatch = $Matches.ContainsKey(4)
        if ((-not $hasVPrefix) -and (-not $hasMinor)) {
            return $null
        }

        $precision = $hasPatch ? 3 : ($hasMinor ? 2 : 1)
        return [PSCustomObject]@{
            Raw       = $Ref
            Major     = [int]$Matches[2]
            Minor     = $hasMinor ? [int]$Matches[3] : 0
            Patch     = $hasPatch ? [int]$Matches[4] : 0
            Precision = $precision
        }
    }

    return $null
}

function Compare-GitHubActionVersion {
    param(
        [PSCustomObject]$Left,
        [PSCustomObject]$Right
    )

    foreach ($field in @('Major', 'Minor', 'Patch', 'Precision')) {
        $leftVal = [int]$Left.$field
        $rightVal = [int]$Right.$field
        if ($leftVal -ne $rightVal) {
            return ($leftVal -gt $rightVal) ? 1 : -1
        }
    }

    return 0
}

function Get-GitHubActionReference {
    param(
        [string[]]$FilePaths = @()
    )

    $references = [System.Collections.Generic.List[hashtable]]::new()
    $yqQuery = '[(.jobs[]?.uses, .jobs[]?.steps[]?.uses, .runs?.steps[]?.uses) | select(. != null and tag == "!!str") | {"uses": ., "line": line}]'

    foreach ($relPath in $FilePaths) {
        $absPath = (Resolve-Path -LiteralPath $relPath).Path
        $rawJson = (& yq -o=json $yqQuery $absPath 2>&1) -join "`n"
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to parse YAML file '${relPath}': $rawJson"
        }

        if (-not $rawJson -or $rawJson.Trim() -in @('', '[]')) {
            continue
        }

        $items = @($rawJson | ConvertFrom-Json -AsHashtable)
        foreach ($item in $items) {
            $usesValue = [string]($item['uses'] ?? '')
            if (-not $usesValue -or $usesValue.StartsWith('.') -or $usesValue.StartsWith('docker://') -or (-not $usesValue.Contains('@'))) {
                continue
            }

            if ($usesValue -match '^([A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+)(?:/([^@]+))?@(.+)$') {
                $repoSlug = $Matches[1]
                $subpath = $Matches.ContainsKey(2) ? $Matches[2] : ''
                $currentRef = $Matches[3]
                $currentVersion = ConvertFrom-GitHubActionVersion -Ref $currentRef

                if ($null -ne $currentVersion) {
                    $actionTarget = $subpath ? "$repoSlug/$subpath" : $repoSlug
                    $references.Add(@{
                            FilePath       = $relPath
                            Line           = [int]$item['line']
                            OldUses        = $usesValue
                            RepoSlug       = $repoSlug
                            ActionTarget   = $actionTarget
                            CurrentRef     = $currentRef
                            CurrentVersion = $currentVersion
                        })
                }
            }
        }
    }

    return @($references)
}

function Resolve-GitHubActionLatestVersion {
    param(
        [string[]]$RepoSlugs = @()
    )

    $uniqueRepos = @($RepoSlugs | Sort-Object -Unique)
    $resultMap = @{}
    if ($uniqueRepos.Count -eq 0) {
        return $resultMap
    }

    $prevTerminalPrompt = $env:GIT_TERMINAL_PROMPT
    $env:GIT_TERMINAL_PROMPT = '0'
    try {
        $results = @($uniqueRepos | ForEach-Object -Parallel {
                $slug = $_
                $output = @(& git -c credential.interactive=never ls-remote --tags --refs "https://github.com/$slug.git" 2>&1)
                $code = $LASTEXITCODE
                if ($code -ne 0) {
                    $errLine = ($output | ForEach-Object { [string]$_ } | Where-Object { $_.Trim() } | Select-Object -First 1) ?? "exit code $code"
                    [PSCustomObject]@{
                        RepoSlug = $slug
                        Success  = $false
                        Tags     = @()
                        Error    = $errLine
                    }
                    return
                }

                $tags = [System.Collections.Generic.List[string]]::new()
                foreach ($line in $output) {
                    $text = [string]$line
                    if ($text -match '\trefs/tags/([^\s]+)$') {
                        $tags.Add($Matches[1])
                    }
                }

                [PSCustomObject]@{
                    RepoSlug = $slug
                    Success  = $true
                    Tags     = @($tags)
                    Error    = ''
                }
            } -ThrottleLimit 6)
    }
    finally {
        $env:GIT_TERMINAL_PROMPT = $prevTerminalPrompt
    }

    foreach ($res in $results) {
        $latestByMajor = @{}
        if ($res.Success) {
            foreach ($tagName in $res.Tags) {
                $parsed = ConvertFrom-GitHubActionVersion -Ref ([string]$tagName)
                if ($null -eq $parsed) {
                    continue
                }
                $majorKey = [int]$parsed.Major
                if ((-not $latestByMajor.ContainsKey($majorKey)) -or ((Compare-GitHubActionVersion -Left $parsed -Right $latestByMajor[$majorKey]) -gt 0)) {
                    $latestByMajor[$majorKey] = $parsed
                }
            }
        }

        $resultMap[$res.RepoSlug] = [PSCustomObject]@{
            RepoSlug      = $res.RepoSlug
            Success       = $res.Success
            LatestByMajor = $latestByMajor
            Error         = $res.Error
        }
    }

    return $resultMap
}

function Get-GitHubActionUpdate {
    param(
        [hashtable[]]$References = @(),
        [hashtable]$LatestByMajorByRepo = @{}
    )

    $updates = [System.Collections.Generic.List[hashtable]]::new()
    foreach ($refItem in $References) {
        $slug = [string]$refItem['RepoSlug']
        if (-not $LatestByMajorByRepo.ContainsKey($slug)) {
            continue
        }

        $majorMap = $LatestByMajorByRepo[$slug]
        $currentVersion = $refItem['CurrentVersion']
        $majorKey = [int]$currentVersion.Major
        if (-not $majorMap.ContainsKey($majorKey)) {
            continue
        }

        $latestVersion = $majorMap[$majorKey]
        $currentRef = [string]$refItem['CurrentRef']
        $targetRef = [string]$latestVersion.Raw
        $cmp = Compare-GitHubActionVersion -Left $latestVersion -Right $currentVersion

        if (($cmp -gt 0) -or (($cmp -eq 0) -and ($currentRef -ne $targetRef))) {
            $actionTarget = [string]$refItem['ActionTarget']
            $updates.Add(@{
                    FilePath     = [string]$refItem['FilePath']
                    Line         = [int]$refItem['Line']
                    OldUses      = [string]$refItem['OldUses']
                    NewUses      = "$actionTarget@$targetRef"
                    RepoSlug     = $slug
                    ActionTarget = $actionTarget
                    OldRef       = $currentRef
                    NewRef       = $targetRef
                })
        }
    }

    return @($updates)
}

function Update-GitHubActionFile {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([object[]])]
    param(
        [hashtable[]]$Updates = @()
    )

    $changedFiles = [System.Collections.Generic.List[string]]::new()
    $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
    $grouped = $Updates | Group-Object -Property { $_['FilePath'] }

    foreach ($group in $grouped) {
        $relPath = [string]$group.Name
        $absPath = (Resolve-Path -LiteralPath $relPath).Path
        $raw = [System.IO.File]::ReadAllText($absPath)
        $eol = $raw.Contains("`r`n") ? "`r`n" : "`n"
        $lines = [string[]]($raw -split '\r?\n')
        $fileModified = $false

        foreach ($item in $group.Group) {
            $lineIndex = [int]$item['Line'] - 1
            if ($lineIndex -lt 0 -or $lineIndex -ge $lines.Count) {
                throw "Line index $($item['Line']) out of range for '$relPath'"
            }

            $oldUses = [string]$item['OldUses']
            $newUses = [string]$item['NewUses']
            $safeReplacement = $newUses.Replace('$', '$$')
            $escapedOld = [regex]::Escape($oldUses)
            $usesPattern = '(?<=uses\s*:\s*[''"]?)' + $escapedOld + '(?=[''"]?(?:\s+#.*|\s*$))'
            $fallbackPattern = '(?<=^\s*[''"]?)' + $escapedOld + '(?=[''"]?(?:\s+#.*|\s*$))'
            $lineText = $lines[$lineIndex]

            if ($lineText -match $usesPattern) {
                $lines[$lineIndex] = [regex]::new($usesPattern).Replace($lineText, $safeReplacement, 1)
                $fileModified = $true
            }
            elseif ($lineText -match $fallbackPattern) {
                $lines[$lineIndex] = [regex]::new($fallbackPattern).Replace($lineText, $safeReplacement, 1)
                $fileModified = $true
            }
            else {
                throw "Failed to locate uses target '$oldUses' at ${relPath}:$($item['Line'])"
            }
        }

        if ($fileModified -and $PSCmdlet.ShouldProcess($relPath, 'Update GitHub Actions version references')) {
            [System.IO.File]::WriteAllText($absPath, ($lines -join $eol), $utf8NoBom)
            $changedFiles.Add($relPath)
        }
    }

    return @($changedFiles)
}

Export-ModuleMember -Function @(
    'Compare-GitHubActionVersion',
    'ConvertFrom-GitHubActionVersion',
    'Find-GitHubActionFile',
    'Get-GitHubActionReference',
    'Get-GitHubActionUpdate',
    'Resolve-GitHubActionLatestVersion',
    'Restore-GitHubWorkflow',
    'Update-GitHubActionFile'
)
