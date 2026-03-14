#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
artifacts_dir="$repo_root/.codex/artifacts"
reports_dir="$repo_root/.codex/reports"
logs_dir="$repo_root/.codex/logs"
mkdir -p "$artifacts_dir" "$reports_dir" "$logs_dir"

preset="safe"
runtime="host"
prompt_file=""
output_schema=""
verify_command=""
allow_search=0
skip_preflight=0
skip_verify=0
explicit_log_path=""
declare -a prompt_parts=()

timestamp="$(date +%Y%m%d-%H%M%S)"
output_file="$artifacts_dir/codex-task-${timestamp}.json"
report_path="$reports_dir/codex-task-${timestamp}.report.json"
log_path="$logs_dir/codex-task-$(date +%Y%m%d).jsonl"

report_status="pending"
prompt_source=""
codex_exit_code="null"
verify_exit_code="null"

json_escape() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\r'/\\r}"
  s="${s//$'\t'/\\t}"
  printf '%s' "$s"
}

ensure_parent_dir() {
  local path="$1"
  mkdir -p "$(dirname "$path")"
}

resolve_path() {
  local raw="$1"
  if [[ "$raw" = /* || "$raw" =~ ^[A-Za-z]:[\\/] || "$raw" =~ ^\\\\ ]]; then
    printf '%s' "$raw"
  else
    printf '%s/%s' "$repo_root" "$raw"
  fi
}

python_cmd() {
  if command -v python3 >/dev/null 2>&1; then
    printf 'python3'
    return
  fi
  if command -v python >/dev/null 2>&1; then
    printf 'python'
    return
  fi
  printf ''
}

normalized_path() {
  local py
  py="$(python_cmd)"
  if [[ -z "$py" ]]; then
    printf '%s' "$1"
    return
  fi
  "$py" -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$1"
}

path_under_root() {
  local candidate root
  candidate="$(normalized_path "$1")"
  root="$(normalized_path "$repo_root")"
  [[ "$candidate" == "$root" || "$candidate" == "$root/"* ]]
}

to_container_path() {
  local full="$1"
  local rel
  if [[ "$full" == "$repo_root" ]]; then
    printf '/workspace'
    return
  fi
  rel="${full#"$repo_root"/}"
  printf '/workspace/%s' "${rel//\\//}"
}

write_log() {
  local event="$1"
  local extra_json="${2:-}"
  ensure_parent_dir "$log_path"
  printf '{"timestamp":"%s","event":"%s"%s}\n' \
    "$(json_escape "$(date -Iseconds)")" \
    "$(json_escape "$event")" \
    "$extra_json" >> "$log_path"
}

write_report() {
  ensure_parent_dir "$report_path"
  cat > "$report_path" <<EOF
{
  "runtime": "$(json_escape "$runtime")",
  "preset": "$(json_escape "$preset")",
  "prompt_source": "$(json_escape "$prompt_source")",
  "output_file": "$(json_escape "$output_file")",
  "output_schema": $(if [[ -n "$output_schema" ]]; then printf '"%s"' "$(json_escape "$output_schema")"; else printf 'null'; fi),
  "log_path": "$(json_escape "$log_path")",
  "codex_exit_code": $codex_exit_code,
  "verify_exit_code": $verify_exit_code,
  "status": "$(json_escape "$report_status")"
}
EOF
}

fail_with_status() {
  local status="$1"
  local message="$2"
  report_status="$status"
  write_log "task_failed" ",\"status\":\"$(json_escape "$status")\",\"message\":\"$(json_escape "$message")\""
  write_report
  printf '%s\n' "$message" >&2
  exit 1
}

block_unsafe_argument() {
  local token="$1"
  local reason="$2"
  fail_with_status "blocked_args" "Unsafe Codex argument blocked: '$token' ($reason)"
}

parse_args() {
  while (($#)); do
    case "$1" in
      --preset)
        [[ $# -ge 2 ]] || fail_with_status "invalid_args" "--preset requires a value"
        preset="$2"
        shift 2
        ;;
      --runtime)
        [[ $# -ge 2 ]] || fail_with_status "invalid_args" "--runtime requires a value"
        runtime="$2"
        shift 2
        ;;
      --prompt-file)
        [[ $# -ge 2 ]] || fail_with_status "invalid_args" "--prompt-file requires a value"
        prompt_file="$(resolve_path "$2")"
        shift 2
        ;;
      --output-file)
        [[ $# -ge 2 ]] || fail_with_status "invalid_args" "--output-file requires a value"
        output_file="$(resolve_path "$2")"
        shift 2
        ;;
      --output-schema)
        [[ $# -ge 2 ]] || fail_with_status "invalid_args" "--output-schema requires a value"
        output_schema="$(resolve_path "$2")"
        shift 2
        ;;
      --report-path)
        [[ $# -ge 2 ]] || fail_with_status "invalid_args" "--report-path requires a value"
        report_path="$(resolve_path "$2")"
        shift 2
        ;;
      --verify-command)
        [[ $# -ge 2 ]] || fail_with_status "invalid_args" "--verify-command requires a value"
        verify_command="$2"
        shift 2
        ;;
      --allow-search)
        allow_search=1
        shift
        ;;
      --skip-preflight)
        skip_preflight=1
        shift
        ;;
      --skip-verify)
        skip_verify=1
        shift
        ;;
      --log-path)
        [[ $# -ge 2 ]] || fail_with_status "invalid_args" "--log-path requires a value"
        explicit_log_path="$(resolve_path "$2")"
        shift 2
        ;;
      --dangerously-bypass-approvals-and-sandbox)
        block_unsafe_argument "$1" "dangerous bypass is prohibited"
        ;;
      --config|--config=*|-c|-c*)
        block_unsafe_argument "$1" "user config overrides are blocked; wrapper injects fixed safety settings"
        ;;
      --sandbox|--sandbox=*|-s|-s*)
        block_unsafe_argument "$1" "sandbox mode is fixed by wrapper"
        ;;
      --ask-for-approval|--ask-for-approval=*|-a|-a*)
        block_unsafe_argument "$1" "approval policy is fixed by wrapper"
        ;;
      --profile|--profile=*|-p|-p*)
        block_unsafe_argument "$1" "profiles are fixed by wrapper presets"
        ;;
      --cd|--cd=*|-C|-C*)
        block_unsafe_argument "$1" "working root is fixed by wrapper"
        ;;
      --enable|--enable=*|--disable|--disable=*)
        block_unsafe_argument "$1" "feature flags are blocked in safe wrapper"
        ;;
      --search)
        block_unsafe_argument "$1" "web search is disabled by default in safe wrapper"
        ;;
      --add-dir|--add-dir=*|--full-auto)
        block_unsafe_argument "$1" "additional writable directories are not allowed"
        ;;
      --*)
        fail_with_status "invalid_args" "Unsupported codex-task option: $1"
        ;;
      *)
        prompt_parts+=("$1")
        shift
        ;;
    esac
  done
}

default_verify_command() {
  if [[ -f "$repo_root/scripts/verify" ]]; then
    printf 'bash scripts/verify'
    return
  fi
  if command -v powershell.exe >/dev/null 2>&1 && [[ -f "$repo_root/scripts/verify.ps1" ]]; then
    printf 'powershell.exe -ExecutionPolicy Bypass -File scripts/verify.ps1'
    return
  fi
  printf ''
}

run_preflight() {
  bash "$repo_root/scripts/codex-safe.sh" --preflight-only >/dev/null
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

run_schema_check() {
  local py
  py="$(python_cmd)"
  [[ -n "$py" ]] || fail_with_status "invalid_output" "Python is required to validate output schema"
  "$py" "$repo_root/scripts/validate-output-schema.py" "$output_schema" "$output_file"
}

main() {
  if [[ -n "$explicit_log_path" ]]; then
    log_path="$explicit_log_path"
  fi

  write_log "wrapper_start" ",\"runtime\":\"$(json_escape "$runtime")\",\"preset\":\"$(json_escape "$preset")\""

  case "$preset" in
    safe|readonly) ;;
    *) fail_with_status "invalid_args" "Unsupported preset: $preset" ;;
  esac

  case "$runtime" in
    host|docker-sandbox) ;;
    *) fail_with_status "invalid_args" "Unsupported runtime: $runtime" ;;
  esac

  local prompt="" cwd sandbox_mode codex_bin used_verify container_output container_schema container_cwd

  if [[ -n "$prompt_file" ]]; then
    [[ -f "$prompt_file" ]] || fail_with_status "invalid_args" "Prompt file not found: $prompt_file"
    prompt="$(<"$prompt_file")"
    prompt_source="$prompt_file"
  else
    prompt="${prompt_parts[*]}"
    prompt_source="inline"
  fi
  [[ -n "$prompt" ]] || fail_with_status "invalid_args" "Prompt text is required"

  ensure_parent_dir "$output_file"
  ensure_parent_dir "$report_path"
  if [[ -n "$output_schema" && ! -f "$output_schema" ]]; then
    fail_with_status "invalid_args" "Output schema not found: $output_schema"
  fi

  cwd="$(pwd -P)"
  if [[ "$cwd" != "$repo_root" && "$cwd" != "$repo_root/"* ]]; then
    cwd="$repo_root"
  fi

  if (( ! skip_preflight )); then
    write_log "preflight_start"
    if run_preflight; then
      write_log "preflight_ok"
    else
      fail_with_status "preflight_failed" "codex-safe preflight failed"
    fi
  fi

  sandbox_mode="workspace-write"
  if [[ "$preset" == "readonly" ]]; then
    sandbox_mode="read-only"
  fi

  if [[ -n "${CODEX_BIN:-}" ]]; then
    if [[ -x "$CODEX_BIN" || -f "$CODEX_BIN" ]]; then
      codex_bin="$CODEX_BIN"
    else
      codex_bin="$(command -v "$CODEX_BIN" || true)"
    fi
  else
    codex_bin="$(command -v codex || true)"
  fi
  [[ -n "$codex_bin" ]] || fail_with_status "codex_missing" "codex command not found in PATH"

  write_log "codex_exec_start" ",\"runtime\":\"$(json_escape "$runtime")\",\"output_file\":\"$(json_escape "$output_file")\""
  set +e
  if [[ "$runtime" == "host" ]]; then
    cmd=()
    append_command cmd "$codex_bin"
    cmd+=(exec -C "$cwd" --sandbox "$sandbox_mode" --ask-for-approval never --output-last-message "$output_file")
    if (( allow_search )); then
      cmd+=(--search)
    fi
    if [[ -n "$output_schema" ]]; then
      cmd+=(--output-schema "$output_schema")
    fi
    cmd+=("$prompt")
    "${cmd[@]}"
    codex_exit_code=$?
  else
    if [[ -n "${CODEX_DOCKER_BIN:-}" ]]; then
      if [[ -x "$CODEX_DOCKER_BIN" || -f "$CODEX_DOCKER_BIN" ]]; then
        docker_bin="$CODEX_DOCKER_BIN"
      else
        docker_bin="$(command -v "$CODEX_DOCKER_BIN" || true)"
      fi
    else
      docker_bin="$(command -v docker || true)"
    fi
    [[ -n "$docker_bin" ]] || fail_with_status "docker_unavailable" "docker command not found in PATH"
    [[ -n "${CODEX_DOCKER_IMAGE:-}" ]] || fail_with_status "docker_unavailable" "Set CODEX_DOCKER_IMAGE before using docker-sandbox runtime"
    path_under_root "$output_file" || fail_with_status "docker_unavailable" "docker-sandbox output file must be under repository root"
    if [[ -n "$output_schema" ]]; then
      path_under_root "$output_schema" || fail_with_status "docker_unavailable" "docker-sandbox output schema must be under repository root"
    fi
    path_under_root "$cwd" || fail_with_status "docker_unavailable" "docker-sandbox working directory must be under repository root"

    container_output="$(to_container_path "$output_file")"
    container_cwd="$(to_container_path "$cwd")"
    docker_cmd=()
    append_command docker_cmd "$docker_bin"
    docker_cmd+=(run --rm -v "$repo_root:/workspace" -w /workspace)
    if [[ -d "${HOME:-}/.codex" ]]; then
      docker_cmd+=(-v "${HOME}/.codex:/root/.codex")
    fi
    if [[ -n "${OPENAI_API_KEY:-}" ]]; then
      docker_cmd+=(-e OPENAI_API_KEY)
    fi
    docker_cmd+=("${CODEX_DOCKER_IMAGE}" codex exec -C "$container_cwd" --sandbox "$sandbox_mode" --ask-for-approval never --output-last-message "$container_output")
    if (( allow_search )); then
      docker_cmd+=(--search)
    fi
    if [[ -n "$output_schema" ]]; then
      container_schema="$(to_container_path "$output_schema")"
      docker_cmd+=(--output-schema "$container_schema")
    fi
    docker_cmd+=("$prompt")
    "${docker_cmd[@]}"
    codex_exit_code=$?
  fi
  set -e

  write_log "codex_exec_exit" ",\"exit_code\":$codex_exit_code"
  if [[ "$codex_exit_code" != "0" ]]; then
    report_status="codex_failed"
    write_report
    exit "$codex_exit_code"
  fi

  [[ -f "$output_file" ]] || fail_with_status "missing_output" "codex exec completed without writing output file"

  if [[ -n "$output_schema" ]]; then
    if run_schema_check; then
      write_log "schema_ok"
    else
      report_status="invalid_output"
      write_log "schema_failed"
      write_report
      exit 1
    fi
  fi

  if (( skip_verify )); then
    report_status="verify_skipped"
    write_report
    exit 0
  fi

  used_verify="$verify_command"
  if [[ -z "$used_verify" ]]; then
    used_verify="$(default_verify_command)"
  fi

  if [[ -z "$used_verify" ]]; then
    report_status="verify_skipped"
    write_log "verify_skipped"
    write_report
    exit 0
  fi

  write_log "verify_start" ",\"command\":\"$(json_escape "$used_verify")\""
  set +e
  bash -lc "$used_verify"
  verify_exit_code=$?
  set -e
  write_log "verify_exit" ",\"exit_code\":$verify_exit_code"

  if [[ "$verify_exit_code" != "0" ]]; then
    report_status="verify_failed"
    write_report
    exit "$verify_exit_code"
  fi

  report_status="ok"
  write_report
}

parse_args "$@"
main
