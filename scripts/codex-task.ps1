[CmdletBinding(PositionalBinding = $false)]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Arguments
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

function Resolve-RepoPath {
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [Parameter(Mandatory = $true)][string]$Path
    )

    if ([System.IO.Path]::IsPathRooted($Path)) {
        return [System.IO.Path]::GetFullPath($Path)
    }

    return [System.IO.Path]::GetFullPath((Join-Path $RepoRoot $Path))
}

function Convert-ToContainerPath {
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [Parameter(Mandatory = $true)][string]$Path
    )

    if ($Path -eq $RepoRoot) {
        return "/workspace"
    }

    $trimmedRoot = $RepoRoot.TrimEnd('\', '/')
    $relative = $Path.Substring($trimmedRoot.Length).TrimStart('\', '/')
    return "/workspace/" + ($relative -replace '\\', '/')
}

function Get-DefaultLogPath {
    param([string]$RepoRoot)

    $logsDir = Join-Path $RepoRoot ".codex\\logs"
    if (-not (Test-Path $logsDir)) {
        New-Item -ItemType Directory -Path $logsDir -Force | Out-Null
    }
    return (Join-Path $logsDir ("codex-task-" + (Get-Date).ToString("yyyyMMdd") + ".jsonl"))
}

function Get-PythonCommand {
    foreach ($candidate in @("python", "python3")) {
        $cmd = Get-Command $candidate -ErrorAction SilentlyContinue
        if ($cmd) {
            return $cmd.Source
        }
    }
    return $null
}

function Get-CodexCommand {
    if (-not [string]::IsNullOrWhiteSpace($env:CODEX_BIN)) {
        if (Test-Path $env:CODEX_BIN) {
            return (Resolve-Path $env:CODEX_BIN).Path
        }
        return (Get-Command $env:CODEX_BIN -ErrorAction Stop).Source
    }
    return (Get-Command codex -ErrorAction Stop).Source
}

function Get-DockerCommand {
    if (-not [string]::IsNullOrWhiteSpace($env:CODEX_DOCKER_BIN)) {
        if (Test-Path $env:CODEX_DOCKER_BIN) {
            return (Resolve-Path $env:CODEX_DOCKER_BIN).Path
        }
        return (Get-Command $env:CODEX_DOCKER_BIN -ErrorAction Stop).Source
    }
    return (Get-Command docker -ErrorAction Stop).Source
}

function Invoke-VerifyCommand {
    param(
        [Parameter(Mandatory = $true)][string]$CommandText,
        [Parameter(Mandatory = $true)][string]$RepoRoot
    )

    $resolvedPath = Resolve-RepoPath -RepoRoot $RepoRoot -Path $CommandText
    if (Test-Path $resolvedPath -PathType Leaf) {
        $extension = [System.IO.Path]::GetExtension($resolvedPath).ToLowerInvariant()
        switch ($extension) {
            '.ps1' {
                & powershell.exe -ExecutionPolicy Bypass -File $resolvedPath
                return $LASTEXITCODE
            }
            '.cmd' { 
                & cmd.exe /d /c $resolvedPath
                return $LASTEXITCODE
            }
            '.bat' {
                & cmd.exe /d /c $resolvedPath
                return $LASTEXITCODE
            }
            '.sh' {
                $bashCmd = Get-Command bash -ErrorAction SilentlyContinue
                if (-not $bashCmd) {
                    throw "bash command not found for verify script: $resolvedPath"
                }
                & $bashCmd.Source $resolvedPath
                return $LASTEXITCODE
            }
            default {
                & $resolvedPath
                return $LASTEXITCODE
            }
        }
    }

    $previous = [System.Environment]::GetEnvironmentVariable('CODEX_VERIFY_COMMAND')
    try {
        [System.Environment]::SetEnvironmentVariable('CODEX_VERIFY_COMMAND', $CommandText)
        $verifyRunner = '$script = [System.Environment]::GetEnvironmentVariable("CODEX_VERIFY_COMMAND"); & ([scriptblock]::Create($script))'
        $encodedRunner = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($verifyRunner))
        & powershell.exe -NoProfile -EncodedCommand $encodedRunner
        return $LASTEXITCODE
    }
    finally {
        [System.Environment]::SetEnvironmentVariable('CODEX_VERIFY_COMMAND', $previous)
    }
}

function Write-TaskLog {
    param(
        [string]$Path,
        [string]$Event,
        [hashtable]$Data
    )

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

function Write-TaskReport {
    param(
        [string]$Path,
        [hashtable]$Report
    )

    $parent = Split-Path -Parent $Path
    if (-not [string]::IsNullOrWhiteSpace($parent) -and -not (Test-Path $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }

    ($Report | ConvertTo-Json -Depth 6) | Set-Content -Path $Path
}

function Fail-Task {
    param(
        [string]$Status,
        [string]$Message,
        [string]$LogPath,
        [string]$ReportPath,
        [hashtable]$Report
    )

    $Report.status = $Status
    Write-TaskLog -Path $LogPath -Event "task_failed" -Data @{ status = $Status; message = $Message }
    Write-TaskReport -Path $ReportPath -Report $Report
    throw $Message
}

function Block-UnsafeArgument {
    param(
        [string]$Token,
        [string]$Reason,
        [string]$LogPath,
        [string]$ReportPath,
        [hashtable]$Report
    )

    Fail-Task -Status "blocked_args" -Message "Unsafe Codex argument blocked: '$Token' ($Reason)" -LogPath $LogPath -ReportPath $ReportPath -Report $Report
}

$repoRoot = Get-RepoRoot -ScriptDir $PSScriptRoot
$timestamp = (Get-Date).ToString("yyyyMMdd-HHmmss")
$artifactsDir = Join-Path $repoRoot ".codex\\artifacts"
$reportsDir = Join-Path $repoRoot ".codex\\reports"
foreach ($dir in @($artifactsDir, $reportsDir)) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
}

$state = [ordered]@{
    preset = "safe"
    runtime = "host"
    prompt_file = $null
    prompt = $null
    output_file = Join-Path $artifactsDir ("codex-task-" + $timestamp + ".json")
    output_schema = $null
    report_path = Join-Path $reportsDir ("codex-task-" + $timestamp + ".report.json")
    verify_command = $null
    allow_search = $false
    skip_preflight = $false
    skip_verify = $false
    log_path = Get-DefaultLogPath -RepoRoot $repoRoot
}

$report = [ordered]@{
    runtime = $state.runtime
    preset = $state.preset
    prompt_source = ""
    output_file = $state.output_file
    output_schema = $null
    log_path = $state.log_path
    codex_exit_code = $null
    verify_exit_code = $null
    status = "pending"
}

$positionals = New-Object System.Collections.Generic.List[string]
$i = 0
while ($i -lt $Arguments.Count) {
    $token = $Arguments[$i]
    switch ($token) {
        '--preset' {
            $i++
            if ($i -ge $Arguments.Count) { Fail-Task -Status "invalid_args" -Message "--preset requires a value" -LogPath $state.log_path -ReportPath $state.report_path -Report $report }
            $state.preset = $Arguments[$i]
        }
        '--runtime' {
            $i++
            if ($i -ge $Arguments.Count) { Fail-Task -Status "invalid_args" -Message "--runtime requires a value" -LogPath $state.log_path -ReportPath $state.report_path -Report $report }
            $state.runtime = $Arguments[$i]
        }
        '--prompt-file' {
            $i++
            if ($i -ge $Arguments.Count) { Fail-Task -Status "invalid_args" -Message "--prompt-file requires a value" -LogPath $state.log_path -ReportPath $state.report_path -Report $report }
            $state.prompt_file = Resolve-RepoPath -RepoRoot $repoRoot -Path $Arguments[$i]
        }
        '--output-file' {
            $i++
            if ($i -ge $Arguments.Count) { Fail-Task -Status "invalid_args" -Message "--output-file requires a value" -LogPath $state.log_path -ReportPath $state.report_path -Report $report }
            $state.output_file = Resolve-RepoPath -RepoRoot $repoRoot -Path $Arguments[$i]
        }
        '--output-schema' {
            $i++
            if ($i -ge $Arguments.Count) { Fail-Task -Status "invalid_args" -Message "--output-schema requires a value" -LogPath $state.log_path -ReportPath $state.report_path -Report $report }
            $state.output_schema = Resolve-RepoPath -RepoRoot $repoRoot -Path $Arguments[$i]
        }
        '--report-path' {
            $i++
            if ($i -ge $Arguments.Count) { Fail-Task -Status "invalid_args" -Message "--report-path requires a value" -LogPath $state.log_path -ReportPath $state.report_path -Report $report }
            $state.report_path = Resolve-RepoPath -RepoRoot $repoRoot -Path $Arguments[$i]
        }
        '--verify-command' {
            $i++
            if ($i -ge $Arguments.Count) { Fail-Task -Status "invalid_args" -Message "--verify-command requires a value" -LogPath $state.log_path -ReportPath $state.report_path -Report $report }
            $state.verify_command = $Arguments[$i]
        }
        '--allow-search' { $state.allow_search = $true }
        '--skip-preflight' { $state.skip_preflight = $true }
        '--skip-verify' { $state.skip_verify = $true }
        '--log-path' {
            $i++
            if ($i -ge $Arguments.Count) { Fail-Task -Status "invalid_args" -Message "--log-path requires a value" -LogPath $state.log_path -ReportPath $state.report_path -Report $report }
            $state.log_path = Resolve-RepoPath -RepoRoot $repoRoot -Path $Arguments[$i]
        }
        '--dangerously-bypass-approvals-and-sandbox' { Block-UnsafeArgument -Token $token -Reason "dangerous bypass is prohibited" -LogPath $state.log_path -ReportPath $state.report_path -Report $report }
        { $_ -like '--config*' -or $_ -like '-c*' } { Block-UnsafeArgument -Token $token -Reason "user config overrides are blocked; wrapper injects fixed safety settings" -LogPath $state.log_path -ReportPath $state.report_path -Report $report }
        { $_ -like '--sandbox*' -or $_ -like '-s*' } { Block-UnsafeArgument -Token $token -Reason "sandbox mode is fixed by wrapper" -LogPath $state.log_path -ReportPath $state.report_path -Report $report }
        { $_ -like '--ask-for-approval*' -or $_ -like '-a*' } { Block-UnsafeArgument -Token $token -Reason "approval policy is fixed by wrapper" -LogPath $state.log_path -ReportPath $state.report_path -Report $report }
        { $_ -like '--profile*' -or $_ -like '-p*' } { Block-UnsafeArgument -Token $token -Reason "profiles are fixed by wrapper presets" -LogPath $state.log_path -ReportPath $state.report_path -Report $report }
        { $_ -like '--cd*' -or $_ -like '-C*' } { Block-UnsafeArgument -Token $token -Reason "working root is fixed by wrapper" -LogPath $state.log_path -ReportPath $state.report_path -Report $report }
        { $_ -like '--enable*' -or $_ -like '--disable*' } { Block-UnsafeArgument -Token $token -Reason "feature flags are blocked in safe wrapper" -LogPath $state.log_path -ReportPath $state.report_path -Report $report }
        '--search' { Block-UnsafeArgument -Token $token -Reason "web search is disabled by default in safe wrapper" -LogPath $state.log_path -ReportPath $state.report_path -Report $report }
        { $_ -like '--add-dir*' -or $_ -eq '--full-auto' } { Block-UnsafeArgument -Token $token -Reason "additional writable directories are not allowed" -LogPath $state.log_path -ReportPath $state.report_path -Report $report }
        default {
            if ($token.StartsWith('-')) {
                Fail-Task -Status "invalid_args" -Message "Unsupported codex-task option: $token" -LogPath $state.log_path -ReportPath $state.report_path -Report $report
            }
            $positionals.Add($token)
        }
    }
    $i++
}

$report.runtime = $state.runtime
$report.preset = $state.preset
$report.output_file = $state.output_file
$report.output_schema = $state.output_schema
$report.log_path = $state.log_path

$logParent = Split-Path -Parent $state.log_path
if (-not (Test-Path $logParent)) {
    New-Item -ItemType Directory -Path $logParent -Force | Out-Null
}
Write-TaskLog -Path $state.log_path -Event "wrapper_start" -Data @{ runtime = $state.runtime; preset = $state.preset }

if ($state.preset -notin @("safe", "readonly")) {
    Fail-Task -Status "invalid_args" -Message "Unsupported preset: $($state.preset)" -LogPath $state.log_path -ReportPath $state.report_path -Report $report
}

if ($state.runtime -notin @("host", "docker-sandbox")) {
    Fail-Task -Status "invalid_args" -Message "Unsupported runtime: $($state.runtime)" -LogPath $state.log_path -ReportPath $state.report_path -Report $report
}

$prompt = if ($state.prompt_file) {
    if (-not (Test-Path $state.prompt_file)) {
        Fail-Task -Status "invalid_args" -Message "Prompt file not found: $($state.prompt_file)" -LogPath $state.log_path -ReportPath $state.report_path -Report $report
    }
    $report.prompt_source = $state.prompt_file
    Get-Content -Raw $state.prompt_file
}
else {
    $report.prompt_source = "inline"
    ($positionals -join ' ')
}

if ([string]::IsNullOrWhiteSpace($prompt)) {
    Fail-Task -Status "invalid_args" -Message "Prompt text is required" -LogPath $state.log_path -ReportPath $state.report_path -Report $report
}

foreach ($path in @($state.output_file, $state.report_path)) {
    $parent = Split-Path -Parent $path
    if (-not (Test-Path $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
}

if ($state.output_schema -and -not (Test-Path $state.output_schema)) {
    Fail-Task -Status "invalid_args" -Message "Output schema not found: $($state.output_schema)" -LogPath $state.log_path -ReportPath $state.report_path -Report $report
}

$cwd = (Get-Location).Path
if (-not (Test-IsPathUnderRoot -Path $cwd -Root $repoRoot)) {
    $cwd = $repoRoot
}

if (-not $state.skip_preflight) {
    Write-TaskLog -Path $state.log_path -Event "preflight_start" -Data @{}
    try {
        & powershell.exe -ExecutionPolicy Bypass -File (Join-Path $repoRoot "scripts\\codex-safe.ps1") -PreflightOnly | Out-Null
        Write-TaskLog -Path $state.log_path -Event "preflight_ok" -Data @{}
    }
    catch {
        Fail-Task -Status "preflight_failed" -Message "codex-safe preflight failed" -LogPath $state.log_path -ReportPath $state.report_path -Report $report
    }
}

$sandboxMode = if ($state.preset -eq "readonly") { "read-only" } else { "workspace-write" }
$codexCmd = try { Get-CodexCommand } catch { $null }
if (-not $codexCmd) {
    Fail-Task -Status "codex_missing" -Message "codex command not found in PATH" -LogPath $state.log_path -ReportPath $state.report_path -Report $report
}

Write-TaskLog -Path $state.log_path -Event "codex_exec_start" -Data @{ runtime = $state.runtime; output_file = $state.output_file }
$execArgs = @("exec", "-C", $cwd, "--sandbox", $sandboxMode, "--ask-for-approval", "never", "--output-last-message", $state.output_file)
if ($state.allow_search) {
    $execArgs += "--search"
}
if ($state.output_schema) {
    $execArgs += @("--output-schema", $state.output_schema)
}

function Invoke-NativeCommand {
    param(
        [Parameter(Mandatory = $true)][string]$Command,
        [Parameter(Mandatory = $true)][string[]]$CommandArgs
    )

    $prevNativeErr = $null
    $hasNativeErrPref = $null -ne (Get-Variable -Name PSNativeCommandUseErrorActionPreference -ErrorAction SilentlyContinue)
    if ($hasNativeErrPref) {
        $prevNativeErr = $PSNativeCommandUseErrorActionPreference
        $PSNativeCommandUseErrorActionPreference = $false
    }

    try {
        & $Command @CommandArgs
        return $LASTEXITCODE
    }
    finally {
        if ($hasNativeErrPref) {
            $PSNativeCommandUseErrorActionPreference = $prevNativeErr
        }
    }
}

if ($state.runtime -eq "host") {
    $report.codex_exit_code = Invoke-NativeCommand -Command $codexCmd -CommandArgs ($execArgs + $prompt)
}
else {
    $dockerCmd = try { Get-DockerCommand } catch { $null }
    if (-not $dockerCmd) {
        Fail-Task -Status "docker_unavailable" -Message "docker command not found in PATH" -LogPath $state.log_path -ReportPath $state.report_path -Report $report
    }
    if ([string]::IsNullOrWhiteSpace($env:CODEX_DOCKER_IMAGE)) {
        Fail-Task -Status "docker_unavailable" -Message "Set CODEX_DOCKER_IMAGE before using docker-sandbox runtime" -LogPath $state.log_path -ReportPath $state.report_path -Report $report
    }
    if (-not (Test-IsPathUnderRoot -Path $state.output_file -Root $repoRoot)) {
        Fail-Task -Status "docker_unavailable" -Message "docker-sandbox output file must be under repository root" -LogPath $state.log_path -ReportPath $state.report_path -Report $report
    }
    if ($state.output_schema -and -not (Test-IsPathUnderRoot -Path $state.output_schema -Root $repoRoot)) {
        Fail-Task -Status "docker_unavailable" -Message "docker-sandbox output schema must be under repository root" -LogPath $state.log_path -ReportPath $state.report_path -Report $report
    }
    if (-not (Test-IsPathUnderRoot -Path $cwd -Root $repoRoot)) {
        Fail-Task -Status "docker_unavailable" -Message "docker-sandbox working directory must be under repository root" -LogPath $state.log_path -ReportPath $state.report_path -Report $report
    }

    $dockerArgs = @("run", "--rm", "-v", "${repoRoot}:/workspace", "-w", "/workspace")
    $homeCodex = Join-Path $HOME ".codex"
    if (Test-Path $homeCodex) {
        $dockerArgs += @("-v", "${homeCodex}:/root/.codex")
    }
    if (-not [string]::IsNullOrWhiteSpace($env:OPENAI_API_KEY)) {
        $dockerArgs += @("-e", "OPENAI_API_KEY")
    }

    $containerArgs = @(
        "codex", "exec",
        "-C", (Convert-ToContainerPath -RepoRoot $repoRoot -Path $cwd),
        "--sandbox", $sandboxMode,
        "--ask-for-approval", "never",
        "--output-last-message", (Convert-ToContainerPath -RepoRoot $repoRoot -Path $state.output_file)
    )
    if ($state.allow_search) {
        $containerArgs += "--search"
    }
    if ($state.output_schema) {
        $containerArgs += @("--output-schema", (Convert-ToContainerPath -RepoRoot $repoRoot -Path $state.output_schema))
    }
    $report.codex_exit_code = Invoke-NativeCommand -Command $dockerCmd -CommandArgs ($dockerArgs + @($env:CODEX_DOCKER_IMAGE) + $containerArgs + $prompt)
}

Write-TaskLog -Path $state.log_path -Event "codex_exec_exit" -Data @{ exit_code = $report.codex_exit_code }
if ($report.codex_exit_code -ne 0) {
    $report.status = "codex_failed"
    Write-TaskReport -Path $state.report_path -Report $report
    exit $report.codex_exit_code
}

if (-not (Test-Path $state.output_file)) {
    Fail-Task -Status "missing_output" -Message "codex exec completed without writing output file" -LogPath $state.log_path -ReportPath $state.report_path -Report $report
}

if ($state.output_schema) {
    $pythonCmd = Get-PythonCommand
    if (-not $pythonCmd) {
        Fail-Task -Status "invalid_output" -Message "Python is required to validate output schema" -LogPath $state.log_path -ReportPath $state.report_path -Report $report
    }
    try {
        & $pythonCmd (Join-Path $repoRoot "scripts\\validate-output-schema.py") $state.output_schema $state.output_file
        if ($LASTEXITCODE -ne 0) {
            throw "schema validation failed"
        }
        Write-TaskLog -Path $state.log_path -Event "schema_ok" -Data @{}
    }
    catch {
        $report.status = "invalid_output"
        $message = if ($_.Exception.Message -eq 'schema validation failed') { 'schema validation failed' } else { $_.Exception.Message }
        Write-TaskLog -Path $state.log_path -Event "schema_failed" -Data @{ message = $message }
        Write-TaskReport -Path $state.report_path -Report $report
        exit 1
    }
}

if ($state.skip_verify) {
    $report.status = "verify_skipped"
    Write-TaskReport -Path $state.report_path -Report $report
    exit 0
}

$verifyCommand = $state.verify_command
if ([string]::IsNullOrWhiteSpace($verifyCommand)) {
    if (Test-Path (Join-Path $repoRoot "scripts\\verify.ps1")) {
        $verifyCommand = "powershell.exe -ExecutionPolicy Bypass -File scripts/verify.ps1"
    }
    elseif ((Get-Command bash -ErrorAction SilentlyContinue) -and (Test-Path (Join-Path $repoRoot "scripts\\verify"))) {
        $verifyCommand = "bash scripts/verify"
    }
}

if ([string]::IsNullOrWhiteSpace($verifyCommand)) {
    $report.status = "verify_skipped"
    Write-TaskLog -Path $state.log_path -Event "verify_skipped" -Data @{}
    Write-TaskReport -Path $state.report_path -Report $report
    exit 0
}

Write-TaskLog -Path $state.log_path -Event "verify_start" -Data @{ command = $verifyCommand }
try {
    $report.verify_exit_code = Invoke-VerifyCommand -CommandText $verifyCommand -RepoRoot $repoRoot
}
catch {
    $report.verify_exit_code = 1
    Write-TaskLog -Path $state.log_path -Event "verify_failed_to_start" -Data @{ message = $_.Exception.Message }
}
Write-TaskLog -Path $state.log_path -Event "verify_exit" -Data @{ exit_code = $report.verify_exit_code }

if ($report.verify_exit_code -ne 0) {
    $report.status = "verify_failed"
    Write-TaskReport -Path $state.report_path -Report $report
    exit $report.verify_exit_code
}

$report.status = "ok"
Write-TaskReport -Path $state.report_path -Report $report
exit 0
