[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $repoRoot

$passCount = 0
$failCount = 0
$skipCount = 0

function Add-Pass([string]$Name) {
    Write-Host "PASS: $Name"
    $script:passCount++
}

function Add-Fail([string]$Name, [string]$Message) {
    Write-Host "FAIL: $Name"
    if ($Message) {
        Write-Host $Message
    }
    $script:failCount++
}

function Add-Skip([string]$Name) {
    Write-Host "SKIP: $Name"
    $script:skipCount++
}

function Invoke-Check {
    param(
        [string]$Name,
        [scriptblock]$Script
    )

    try {
        & $Script
        Add-Pass $Name
    }
    catch {
        Add-Fail $Name $_.Exception.Message
    }
}

function Get-Decision([string]$Raw) {
    $json = $Raw | ConvertFrom-Json
    return $json.decision
}

function Test-TemplateContract {
    $required = @(
        "AGENTS.md",
        "PLANS.md",
        "CODE_REVIEW.md",
        ".codex/templates/PLAN.md",
        ".codex/rules/10-readonly-allow.rules",
        "scripts/codex-task.ps1",
        "scripts/codex-task.sh",
        "scripts/codex-sandbox.ps1",
        "scripts/codex-sandbox.sh",
        "scripts/validate-output-schema.py",
        ".agents/skills/feature-plan/references/planning-workflow.md",
        ".agents/skills/code-review/references/review-workflow.md",
        "docs/reference/codex-safety-harness.md",
        "docs/reference/codex-implementation-harness.md"
    )
    foreach ($path in $required) {
        if (-not (Test-Path $path)) {
            throw "Missing required path: $path"
        }
    }

    $agents = Get-Content -Raw AGENTS.md
    $plans = Get-Content -Raw PLANS.md
    $review = Get-Content -Raw CODE_REVIEW.md
    if ($agents -notmatch [regex]::Escape(".agents/skills/feature-plan/SKILL.md")) { throw "AGENTS.md missing feature-plan skill reference" }
    if ($agents -notmatch [regex]::Escape(".agents/skills/code-review/SKILL.md")) { throw "AGENTS.md missing code-review skill reference" }
    if ($agents -notmatch [regex]::Escape("docs/reference/codex-safety-harness.md")) { throw "AGENTS.md missing safety harness reference" }
    if ($agents -notmatch [regex]::Escape("docs/reference/codex-implementation-harness.md")) { throw "AGENTS.md missing implementation harness reference" }
    if ($plans -notmatch [regex]::Escape(".agents/skills/feature-plan/SKILL.md")) { throw "PLANS.md missing feature-plan skill reference" }
    if ($plans -notmatch [regex]::Escape("docs/plans/TEMPLATE.md")) { throw "PLANS.md missing plan template reference" }
    if ($review -notmatch [regex]::Escape(".agents/skills/code-review/SKILL.md")) { throw "CODE_REVIEW.md missing code-review skill reference" }
    if ($review -notmatch [regex]::Escape("findings-first")) { throw "CODE_REVIEW.md missing findings-first guidance" }
}

function Test-ExecpolicyBaseline {
    $codex = (Get-Command codex -ErrorAction Stop).Source
    $ruleArgs = @(
        '--rules', '.codex/rules/10-readonly-allow.rules',
        '--rules', '.codex/rules/20-risky-prompt.rules',
        '--rules', '.codex/rules/30-destructive-forbidden.rules'
    )

    $allow = & $codex execpolicy check @ruleArgs -- git status 2>&1
    if ((Get-Decision ($allow | Out-String)) -ne 'allow') { throw "git status should be allow" }

    $prompt = & $codex execpolicy check @ruleArgs -- git add . 2>&1
    if ((Get-Decision ($prompt | Out-String)) -ne 'prompt') { throw "git add . should be prompt" }

    $forbidden = & $codex execpolicy check @ruleArgs -- git reset --hard HEAD~1 2>&1
    if ((Get-Decision ($forbidden | Out-String)) -ne 'forbidden') { throw "git reset should be forbidden" }
}

function Test-WrapperPreflight {
    powershell.exe -ExecutionPolicy Bypass -File scripts/codex-safe.ps1 -PreflightOnly | Out-Null
}

function Test-NpmQuality {
    npm run verify:quality | Out-Null
}

Invoke-Check "template contract files" { Test-TemplateContract }

if (Test-Path package.json) {
    if (Get-Command npm -ErrorAction SilentlyContinue) {
        Invoke-Check "npm quality checks" { Test-NpmQuality }
    }
    else {
        Add-Fail "npm quality checks" "package.json exists but npm command not found"
    }
}
else {
    Add-Skip "npm quality checks"
}

if (Get-Command codex -ErrorAction SilentlyContinue) {
    Invoke-Check "execpolicy baseline decisions" { Test-ExecpolicyBaseline }
}
else {
    Add-Skip "execpolicy baseline decisions"
}

if (Get-Command powershell.exe -ErrorAction SilentlyContinue) {
    $hasCodex = powershell.exe -NoProfile -Command "if (Get-Command codex -ErrorAction SilentlyContinue) { exit 0 } else { exit 1 }"
    if ($LASTEXITCODE -eq 0) {
        Invoke-Check "PowerShell wrapper preflight" { Test-WrapperPreflight }
    }
    else {
        Add-Skip "PowerShell wrapper preflight"
    }
}
else {
    Add-Skip "PowerShell wrapper preflight"
}

Write-Host "Summary: PASS=$passCount FAIL=$failCount SKIP=$skipCount"

if ($failCount -gt 0) {
    exit 1
}

exit 0
