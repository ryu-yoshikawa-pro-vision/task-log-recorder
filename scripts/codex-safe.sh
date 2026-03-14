#!/usr/bin/env bash
set -euo pipefail

preset="safe"
skip_preflight=0
preflight_only=0
print_command=0
allow_search=0
no_log=0
explicit_log_path=""
declare -a passthrough_args=()

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"

json_escape() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\r'/\\r}"
  s="${s//$'\t'/\\t}"
  printf '%s' "$s"
}

default_log_path() {
  local logs_dir="$repo_root/.codex/logs"
  mkdir -p "$logs_dir"
  printf '%s/codex-safe-%s.jsonl' "$logs_dir" "$(date +%Y%m%d)"
}

resolved_log_path() {
  if (( no_log )); then
    return 0
  fi

  if [[ -n "$explicit_log_path" ]]; then
    mkdir -p "$(dirname "$explicit_log_path")"
    printf '%s' "$explicit_log_path"
    return 0
  fi

  default_log_path
}

write_log() {
  local path="$1"
  local event="$2"
  local extra_json="${3:-}"
  [[ -n "$path" ]] || return 0

  local ts
  ts="$(date -Iseconds)"
  printf '{"timestamp":"%s","event":"%s"%s}\n' \
    "$(json_escape "$ts")" \
    "$(json_escape "$event")" \
    "$extra_json" >> "$path"
}

fail_with_message() {
  local path="$1"
  local message="$2"
  write_log "$path" "wrapper_blocked_args" ",\"message\":\"$(json_escape "$message")\""
  printf '%s\n' "$message" >&2
  exit 1
}

parse_args() {
  while (($#)); do
    case "$1" in
      --preset)
        [[ $# -ge 2 ]] || { echo "--preset requires a value" >&2; exit 1; }
        preset="$2"
        shift 2
        ;;
      --skip-preflight)
        skip_preflight=1
        shift
        ;;
      --preflight-only)
        preflight_only=1
        shift
        ;;
      --print-command)
        print_command=1
        shift
        ;;
      --allow-search)
        allow_search=1
        shift
        ;;
      --no-log)
        no_log=1
        shift
        ;;
      --log-path)
        [[ $# -ge 2 ]] || { echo "--log-path requires a value" >&2; exit 1; }
        explicit_log_path="$2"
        shift 2
        ;;
      --)
        shift
        passthrough_args+=("$@")
        return
        ;;
      *)
        passthrough_args+=("$1")
        shift
        ;;
    esac
  done
}

validate_preset() {
  case "$preset" in
    safe|readonly) ;;
    *)
      echo "Unsupported preset: $preset" >&2
      exit 1
      ;;
  esac
}

append_command() {
  local -n _target=$1
  local command_path="$2"
  if [[ "$command_path" == *.sh ]]; then
    _target+=(bash "$command_path")
  else
    _target+=("$command_path")
  fi
}

check_unsafe_passthrough() {
  local log_path="$1"
  local token

  for token in "${passthrough_args[@]}"; do
    case "$token" in
      --dangerously-bypass-approvals-and-sandbox)
        fail_with_message "$log_path" "Unsafe Codex argument blocked: '$token' (dangerous bypass is prohibited)"
        ;;
      --full-auto)
        fail_with_message "$log_path" "Unsafe Codex argument blocked: '$token' (full-auto overrides approval policy; use wrapper preset instead)"
        ;;
      --add-dir|--add-dir=*)
        fail_with_message "$log_path" "Unsafe Codex argument blocked: '$token' (additional writable directories are not allowed)"
        ;;
      --config|--config=*)
        fail_with_message "$log_path" "Unsafe Codex argument blocked: '$token' (user config overrides are blocked; wrapper injects fixed safety settings)"
        ;;
      --sandbox|--sandbox=*)
        fail_with_message "$log_path" "Unsafe Codex argument blocked: '$token' (sandbox mode is fixed by wrapper)"
        ;;
      --ask-for-approval|--ask-for-approval=*)
        fail_with_message "$log_path" "Unsafe Codex argument blocked: '$token' (approval policy is fixed by wrapper)"
        ;;
      --profile|--profile=*)
        fail_with_message "$log_path" "Unsafe Codex argument blocked: '$token' (profiles are fixed by wrapper presets)"
        ;;
      --cd|--cd=*)
        fail_with_message "$log_path" "Unsafe Codex argument blocked: '$token' (working root is fixed by wrapper)"
        ;;
      --enable|--enable=*)
        fail_with_message "$log_path" "Unsafe Codex argument blocked: '$token' (feature flags are blocked in safe wrapper)"
        ;;
      --disable|--disable=*)
        fail_with_message "$log_path" "Unsafe Codex argument blocked: '$token' (feature flags are blocked in safe wrapper)"
        ;;
      --search)
        if (( ! allow_search )); then
          fail_with_message "$log_path" "Unsafe Codex argument blocked: '$token' (web search is disabled by default in safe wrapper)"
        fi
        ;;
      -c|-c?*)
        fail_with_message "$log_path" "Unsafe Codex argument blocked: '$token' (short -c config override is blocked)"
        ;;
      -s|-s?*)
        fail_with_message "$log_path" "Unsafe Codex argument blocked: '$token' (sandbox mode is fixed by wrapper)"
        ;;
      -a|-a?*)
        fail_with_message "$log_path" "Unsafe Codex argument blocked: '$token' (approval policy is fixed by wrapper)"
        ;;
      -p|-p?*)
        fail_with_message "$log_path" "Unsafe Codex argument blocked: '$token' (profiles are fixed by wrapper presets)"
        ;;
      -C|-C?*)
        fail_with_message "$log_path" "Unsafe Codex argument blocked: '$token' (working root is fixed by wrapper)"
        ;;
    esac

    if [[ "$token" == "danger-full-access" || "$token" == "never" ]]; then
      fail_with_message "$log_path" "Unsafe Codex argument blocked: '$token' (unsafe sandbox/approval value is not allowed)"
    fi
  done
}

collect_rule_args() {
  local rules_dir="$repo_root/.codex/rules"
  [[ -d "$rules_dir" ]] || { echo "Rules directory not found: $rules_dir" >&2; exit 1; }

  mapfile -t rule_files < <(find "$rules_dir" -maxdepth 1 -type f -name '*.rules' | sort)
  ((${#rule_files[@]} > 0)) || { echo "No .rules files found in $rules_dir" >&2; exit 1; }

  rule_args=()
  local rule
  for rule in "${rule_files[@]}"; do
    rule_args+=(--rules "$rule")
  done
}

decision_from_output() {
  local output="$1"
  local decision
  decision="${output##*\"decision\":\"}"
  decision="${decision%%\"*}"
  if [[ -z "$decision" || "$decision" == "$output" ]]; then
    echo "Unable to parse decision from output: $output" >&2
    return 1
  fi
  printf '%s' "$decision"
}

execpolicy_decision() {
  local output
  local -a command=()
  append_command command "$codex_cmd"
  output="$("${command[@]}" execpolicy check "${rule_args[@]}" -- "$@" 2>&1)" || {
    echo "codex execpolicy check failed for '$*': $output" >&2
    return 1
  }
  decision_from_output "$output"
}

assert_decision() {
  local expected="$1"
  shift
  local decision
  decision="$(execpolicy_decision "$@")"
  if [[ "$decision" != "$expected" ]]; then
    echo "Execpolicy preflight mismatch for '$*': expected '$expected', got '$decision'" >&2
    return 1
  fi
}

run_preflight() {
  assert_decision allow git status
  assert_decision allow rg --files docs
  assert_decision prompt git add .
  assert_decision forbidden git reset --hard HEAD~1
  assert_decision forbidden terraform destroy -auto-approve
  assert_decision prompt docker ps
  assert_decision forbidden Remove-Item -Recurse tmp
}

parse_args "$@"
validate_preset

if [[ -n "${CODEX_BIN:-}" ]]; then
  if [[ -x "$CODEX_BIN" || -f "$CODEX_BIN" ]]; then
    codex_cmd="$CODEX_BIN"
  else
    codex_cmd="$(command -v "$CODEX_BIN" || true)"
  fi
else
  codex_cmd="$(command -v codex || true)"
fi
[[ -n "$codex_cmd" ]] || { echo "codex command not found in PATH" >&2; exit 1; }

log_path="$(resolved_log_path || true)"
collect_rule_args

write_log "$log_path" "wrapper_start" ",\"preset\":\"$(json_escape "$preset")\",\"allow_search\":$allow_search,\"skip_preflight\":$skip_preflight,\"preflight_only\":$preflight_only,\"print_command\":$print_command"

check_unsafe_passthrough "$log_path"

cwd="$(pwd -P)"
if [[ "$cwd" != "$repo_root" && "$cwd" != "$repo_root/"* ]]; then
  echo "Current directory is outside repository root. Wrapper will run Codex in repo root: $repo_root" >&2
  cwd="$repo_root"
fi

if (( ! skip_preflight )); then
  write_log "$log_path" "preflight_start"
  if run_preflight; then
    write_log "$log_path" "preflight_ok"
  else
    write_log "$log_path" "preflight_failed"
    exit 1
  fi
fi

if (( preflight_only )); then
  write_log "$log_path" "preflight_only_exit" ",\"cwd\":\"$(json_escape "$cwd")\""
  echo "Preflight OK. Rules validated against smoke tests."
  exit 0
fi

sandbox_mode="workspace-write"
if [[ "$preset" == "readonly" ]]; then
  sandbox_mode="read-only"
fi

final_args=(-C "$cwd" --sandbox "$sandbox_mode" --ask-for-approval untrusted)
if (( allow_search )); then
  final_args+=(--search)
fi
if ((${#passthrough_args[@]} > 0)); then
  final_args+=("${passthrough_args[@]}")
fi

if (( print_command )); then
  write_log "$log_path" "print_command" ",\"cwd\":\"$(json_escape "$cwd")\""
  if command -v python3 >/dev/null 2>&1; then
    python3 - "$codex_cmd" "$preset" "$log_path" "$cwd" "${final_args[@]}" <<'PY'
import json
import sys

codex = sys.argv[1]
preset = sys.argv[2]
log_path = sys.argv[3]
cwd = sys.argv[4]
args = sys.argv[5:]

print(json.dumps({
    "codex": codex,
    "args": args,
    "preflight": True,
    "preset": preset,
    "log_path": log_path,
    "cwd": cwd,
}, ensure_ascii=False))
PY
  else
    printf 'codex: %s\nargs: %s\n' "$codex_cmd" "${final_args[*]}"
  fi
  exit 0
fi

write_log "$log_path" "codex_exec_start" ",\"cwd\":\"$(json_escape "$cwd")\""
set +e
command_prefix=()
append_command command_prefix "$codex_cmd"
"${command_prefix[@]}" "${final_args[@]}"
codex_exit=$?
set -e
write_log "$log_path" "codex_exec_exit" ",\"exit_code\":$codex_exit"
exit "$codex_exit"
