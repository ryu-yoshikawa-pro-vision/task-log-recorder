[CmdletBinding(PositionalBinding = $false)]
param(
    [ValidateSet("safe", "readonly")]
    [string]$Preset = "safe",

    [switch]$SkipPreflight,

    [switch]$PreflightOnly,

    [switch]$PrintCommand,

    [switch]$AllowSearch,

    [switch]$NoLog,

    [string]$LogPath,

    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$PassthroughArgs
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-RepoRoot {
    param([string]$ScriptDir)
    return (Resolve-Path (Join-Path $ScriptDir "..")).Path
}

function Test-IsPathUnderRoot {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Root
    )

    $fullPath = [System.IO.Path]::GetFullPath($Path)
    $fullRoot = [System.IO.Path]::GetFullPath($Root)
    if (-not $fullRoot.EndsWith([System.IO.Path]::DirectorySeparatorChar)) {
        $fullRoot += [System.IO.Path]::DirectorySeparatorChar
    }
    return $fullPath.StartsWith($fullRoot, [System.StringComparison]::OrdinalIgnoreCase) -or
        ($fullPath.TrimEnd([System.IO.Path]::DirectorySeparatorChar) -eq $fullRoot.TrimEnd([System.IO.Path]::DirectorySeparatorChar))
}

function Get-DefaultLogPath {
    param([string]$RepoRoot)

    $logsDir = Join-Path $RepoRoot ".codex\\logs"
    if (-not (Test-Path $logsDir)) {
        New-Item -ItemType Directory -Path $logsDir -Force | Out-Null
    }
    $datePart = (Get-Date).ToString("yyyyMMdd")
    return (Join-Path $logsDir ("codex-safe-" + $datePart + ".jsonl"))
}

function Get-LogPathResolved {
    param(
        [string]$RepoRoot,
        [bool]$DisableLogging,
        [string]$ExplicitPath
    )

    if ($DisableLogging) {
        return $null
    }

    if (-not [string]::IsNullOrWhiteSpace($ExplicitPath)) {
        $parent = Split-Path -Parent $ExplicitPath
        if (-not [string]::IsNullOrWhiteSpace($parent) -and -not (Test-Path $parent)) {
            New-Item -ItemType Directory -Path $parent -Force | Out-Null
        }
        return $ExplicitPath
    }

    return (Get-DefaultLogPath -RepoRoot $RepoRoot)
}

function Get-ArgsSummary {
    param([string[]]$Args)

    if (-not $Args) {
        return [pscustomobject]@{
            count = 0
            preview = @()
        }
    }

    $preview = @()
    for ($i = 0; $i -lt [Math]::Min($Args.Count, 6); $i++) {
        $token = $Args[$i]
        if ($i -eq 1 -and $Args[0] -eq 'exec' -and $token -notmatch '^-') {
            $preview += '<redacted-prompt>'
            continue
        }
        if ($token.Length -gt 160) {
            $preview += ($token.Substring(0, 160) + '...')
        }
        else {
            $preview += $token
        }
    }

    return [pscustomobject]@{
        count = $Args.Count
        preview = $preview
    }
}

function Write-HarnessLog {
    param(
        [string]$Path,
        [string]$Event,
        [hashtable]$Data
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return
    }

    $payload = [ordered]@{
        timestamp = (Get-Date).ToString("o")
        event = $Event
    }

    if ($Data) {
        foreach ($key in $Data.Keys) {
            $payload[$key] = $Data[$key]
        }
    }

    ($payload | ConvertTo-Json -Compress -Depth 8) | Add-Content -Path $Path
}

function Throw-UnsafeArgument {
    param([string]$Token, [string]$Reason)
    throw "Unsafe Codex argument blocked: '$Token' ($Reason)"
}

function Test-UserArguments {
    param(
        [string[]]$ArgsToCheck,
        [string]$RepoRoot,
        [bool]$SearchAllowed
    )

    if (-not $ArgsToCheck) {
        return
    }

    $i = 0
    while ($i -lt $ArgsToCheck.Count) {
        $token = $ArgsToCheck[$i]

        if ([string]::IsNullOrWhiteSpace($token)) {
            $i++
            continue
        }

        switch -Regex ($token) {
            '^--dangerously-bypass-approvals-and-sandbox$' { Throw-UnsafeArgument $token "dangerous bypass is prohibited" }
            '^--full-auto$' { Throw-UnsafeArgument $token "full-auto overrides approval policy; use wrapper preset instead" }
            '^--add-dir(=|$)' { Throw-UnsafeArgument $token "additional writable directories are not allowed" }
            '^--config(=|$)' { Throw-UnsafeArgument $token "user config overrides are blocked; wrapper injects fixed safety settings" }
            '^--sandbox(=|$)' { Throw-UnsafeArgument $token "sandbox mode is fixed by wrapper" }
            '^--ask-for-approval(=|$)' { Throw-UnsafeArgument $token "approval policy is fixed by wrapper" }
            '^--profile(=|$)' { Throw-UnsafeArgument $token "profiles are fixed by wrapper presets" }
            '^--cd(=|$)' { Throw-UnsafeArgument $token "working root is fixed by wrapper" }
            '^--enable(=|$)' { Throw-UnsafeArgument $token "feature flags are blocked in safe wrapper" }
            '^--disable(=|$)' { Throw-UnsafeArgument $token "feature flags are blocked in safe wrapper" }
            '^--search$' {
                if (-not $SearchAllowed) {
                    Throw-UnsafeArgument $token "web search is disabled by default in safe wrapper"
                }
            }
            '^-c$' { Throw-UnsafeArgument $token "user config overrides are blocked; wrapper injects fixed safety settings" }
            '^-c.+' { Throw-UnsafeArgument $token "short -c config override is blocked" }
            '^-s$' { Throw-UnsafeArgument $token "sandbox mode is fixed by wrapper" }
            '^-s.+' { Throw-UnsafeArgument $token "sandbox mode is fixed by wrapper" }
            '^-a$' { Throw-UnsafeArgument $token "approval policy is fixed by wrapper" }
            '^-a.+' { Throw-UnsafeArgument $token "approval policy is fixed by wrapper" }
            '^-p$' { Throw-UnsafeArgument $token "profiles are fixed by wrapper presets" }
            '^-p.+' { Throw-UnsafeArgument $token "profiles are fixed by wrapper presets" }
            '^-C$' { Throw-UnsafeArgument $token "working root is fixed by wrapper" }
            '^-C.+' { Throw-UnsafeArgument $token "working root is fixed by wrapper" }
            default { }
        }

        if ($token -eq '--search' -and -not $SearchAllowed) {
            Throw-UnsafeArgument $token "web search is disabled by default in safe wrapper"
        }

        # Extra defense: block explicit danger values if passed as a separate token in unsupported ways.
        if ($token -eq 'danger-full-access' -or $token -eq 'never') {
            Throw-UnsafeArgument $token "unsafe sandbox/approval value is not allowed"
        }

        $i++
    }
}

function Get-RuleFiles {
    param([string]$RepoRoot)
    $rulesDir = Join-Path $RepoRoot ".codex\\rules"
    if (-not (Test-Path $rulesDir)) {
        throw "Rules directory not found: $rulesDir"
    }
    $files = Get-ChildItem -Path $rulesDir -Filter *.rules | Sort-Object Name
    if (-not $files) {
        throw "No .rules files found in $rulesDir"
    }
    return $files
}

function Invoke-ExecpolicyCheck {
    param(
        [string]$CodexExe,
        [System.IO.FileInfo[]]$RuleFiles,
        [string[]]$CommandTokens
    )

    $args = @('execpolicy', 'check')
    foreach ($file in $RuleFiles) {
        $args += @('--rules', $file.FullName)
    }
    $args += @('--')
    $args += $CommandTokens

    $output = & $CodexExe @args 2>&1
    $exitCode = $LASTEXITCODE
    if ($exitCode -ne 0) {
        throw "codex execpolicy check failed (exit=$exitCode) for '$($CommandTokens -join ' ')': $output"
    }

    $jsonText = ($output | Out-String)
    return ($jsonText | ConvertFrom-Json)
}

function Invoke-Preflight {
    param(
        [string]$CodexExe,
        [System.IO.FileInfo[]]$RuleFiles
    )

    $tests = @(
        @{ Tokens = @('git', 'status'); Decisions = @('allow') },
        @{ Tokens = @('rg', '--files', 'docs'); Decisions = @('allow') },
        @{ Tokens = @('git', 'add', '.'); Decisions = @('prompt') },
        @{ Tokens = @('git', 'reset', '--hard', 'HEAD~1'); Decisions = @('forbidden') },
        @{ Tokens = @('terraform', 'destroy', '-auto-approve'); Decisions = @('forbidden') },
        @{ Tokens = @('docker', 'ps'); Decisions = @('prompt') },
        @{ Tokens = @('Remove-Item', '-Recurse', 'tmp'); Decisions = @('forbidden') }
    )

    foreach ($test in $tests) {
        $result = Invoke-ExecpolicyCheck -CodexExe $CodexExe -RuleFiles $RuleFiles -CommandTokens $test.Tokens
        if ($result.decision -notin $test.Decisions) {
            throw "Execpolicy preflight mismatch for '$($test.Tokens -join ' ')': expected [$($test.Decisions -join ', ')], got '$($result.decision)'"
        }
    }
}

function Get-PresetConfig {
    param([string]$PresetName)
    switch ($PresetName) {
        'safe' {
            return @{
                Sandbox = 'workspace-write'
                Approval = 'untrusted'
                Profile  = 'repo_safe'
            }
        }
        'readonly' {
            return @{
                Sandbox = 'read-only'
                Approval = 'untrusted'
                Profile  = 'repo_readonly'
            }
        }
        default {
            throw "Unsupported preset: $PresetName"
        }
    }
}

$repoRoot = Get-RepoRoot -ScriptDir $PSScriptRoot
$codexCmd = if (-not [string]::IsNullOrWhiteSpace($env:CODEX_BIN)) {
    $candidate = $env:CODEX_BIN
    if (Test-Path $candidate) {
        (Resolve-Path $candidate).Path
    }
    else {
        (Get-Command $candidate -ErrorAction Stop).Source
    }
}
else {
    (Get-Command codex -ErrorAction Stop).Source
}
$rules = Get-RuleFiles -RepoRoot $repoRoot
$presetConfig = Get-PresetConfig -PresetName $Preset
$resolvedLogPath = Get-LogPathResolved -RepoRoot $repoRoot -DisableLogging:$NoLog.IsPresent -ExplicitPath $LogPath

Write-HarnessLog -Path $resolvedLogPath -Event 'wrapper_start' -Data @{
    preset = $Preset
    allow_search = $AllowSearch.IsPresent
    skip_preflight = $SkipPreflight.IsPresent
    preflight_only = $PreflightOnly.IsPresent
    print_command = $PrintCommand.IsPresent
    rules = @($rules | ForEach-Object { $_.Name })
    codex_args = (Get-ArgsSummary -Args $PassthroughArgs)
}

try {
    Test-UserArguments -ArgsToCheck $PassthroughArgs -RepoRoot $repoRoot -SearchAllowed:$AllowSearch.IsPresent
}
catch {
    Write-HarnessLog -Path $resolvedLogPath -Event 'wrapper_blocked_args' -Data @{
        message = $_.Exception.Message
        codex_args = (Get-ArgsSummary -Args $PassthroughArgs)
    }
    throw
}

$cwd = (Get-Location).Path
if (-not (Test-IsPathUnderRoot -Path $cwd -Root $repoRoot)) {
    Write-Warning "Current directory is outside repository root. Wrapper will run Codex in repo root: $repoRoot"
    $cwd = $repoRoot
}

if (-not $SkipPreflight) {
    Write-HarnessLog -Path $resolvedLogPath -Event 'preflight_start' -Data @{}
    try {
        Invoke-Preflight -CodexExe $codexCmd -RuleFiles $rules
        Write-HarnessLog -Path $resolvedLogPath -Event 'preflight_ok' -Data @{}
    }
    catch {
        Write-HarnessLog -Path $resolvedLogPath -Event 'preflight_failed' -Data @{
            message = $_.Exception.Message
        }
        throw
    }
}

if ($PreflightOnly) {
    Write-HarnessLog -Path $resolvedLogPath -Event 'preflight_only_exit' -Data @{
        cwd = $cwd
    }
    Write-Host "Preflight OK. Rules validated against smoke tests."
    exit 0
}

$finalArgs = @(
    '-C', $cwd,
    '--sandbox', $presetConfig.Sandbox,
    '--ask-for-approval', $presetConfig.Approval
)

if ($AllowSearch) {
    $finalArgs += '--search'
}

if ($PassthroughArgs) {
    $finalArgs += $PassthroughArgs
}

if ($PrintCommand) {
    Write-HarnessLog -Path $resolvedLogPath -Event 'print_command' -Data @{
        cwd = $cwd
        final_args = (Get-ArgsSummary -Args $finalArgs)
        profile_hint = $presetConfig.Profile
    }
    [pscustomobject]@{
        codex = $codexCmd
        args = $finalArgs
        rules = ($rules | ForEach-Object { $_.Name })
        preflight = (-not $SkipPreflight.IsPresent)
        preset = $Preset
        profile_hint = $presetConfig.Profile
        log_path = $resolvedLogPath
    } | ConvertTo-Json -Depth 4
    exit 0
}

Write-HarnessLog -Path $resolvedLogPath -Event 'codex_exec_start' -Data @{
    cwd = $cwd
    final_args = (Get-ArgsSummary -Args $finalArgs)
    profile_hint = $presetConfig.Profile
}

& $codexCmd @finalArgs
$codexExit = $LASTEXITCODE

Write-HarnessLog -Path $resolvedLogPath -Event 'codex_exec_exit' -Data @{
    exit_code = $codexExit
}

exit $codexExit
