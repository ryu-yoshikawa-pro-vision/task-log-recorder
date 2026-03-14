# Codex Execpolicy Rules

This directory stores repository-local Codex execpolicy rule files (`*.rules`).

## Files

- `10-readonly-allow.rules`: common read-only commands that can run without prompts
- `20-risky-prompt.rules`: broad prompt rules for mutating/high-impact command families
- `30-destructive-forbidden.rules`: explicitly forbidden destructive prefixes

## Validation

Use `codex execpolicy check` or the wrapper preflight:

- `codex execpolicy check --rules .codex/rules/10-readonly-allow.rules -- git status`
- `powershell -ExecutionPolicy Bypass -File scripts/codex-safe.ps1 -PreflightOnly`

## Notes

- Rules are prefix-based; they are not a full parser for every shell grammar edge case.
- The wrapper and Codex approval/sandbox settings provide additional defense layers.
