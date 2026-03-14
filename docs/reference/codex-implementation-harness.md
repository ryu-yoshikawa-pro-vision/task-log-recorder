# Codex実装ハーネス運用ガイド

## 目的
- Codex の実行経路を `manual interactive` / `non-interactive task` / `docker sandbox` に分け、用途ごとに安全性と再現性を揃える。

## 使い分け
- `scripts/codex-safe.ps1|sh`
  - 手動対話用の安全 wrapper。
  - preflight、危険引数拒否、sandbox/approval 固定、JSONL ログを提供する。
- `scripts/codex-task.ps1|sh`
  - 非対話 `codex exec` 用 wrapper。
  - 実行順は `preflight -> codex exec -> output/schema check -> verify -> report`。
  - `output-last-message` と machine-readable report JSON を必ず残す。
- `scripts/codex-sandbox.ps1|sh`
  - `codex-task --runtime docker-sandbox` の薄い互換 wrapper。
  - Docker image と認証が明示設定されている場合だけ使う experimental path。

## `codex-task` の主な引数
- `--preset safe|readonly`
- `--runtime host|docker-sandbox`
- `--prompt-file <path>` または末尾 prompt
- `--output-file <path>`
- `--output-schema <path>`
- `--report-path <path>`
- `--verify-command <cmd>`
- `--allow-search`
- `--skip-preflight`
- `--skip-verify`

### `--verify-command` の扱い
- PowerShell wrapper:
  - 実在する `.ps1` / `.cmd` / `.bat` / `.sh` / 実行ファイル path は拡張子に応じて直接実行する。
  - それ以外は PowerShell command として実行する。
- bash wrapper:
  - `bash -lc "<cmd>"` として実行する。

## 成果物
- output file:
  - `codex exec --output-last-message` の最終出力
- report JSON:
  - 必須キーは `runtime`, `preset`, `prompt_source`, `output_file`, `output_schema`, `log_path`, `codex_exit_code`, `verify_exit_code`, `status`
- JSONL log:
  - wrapper start、preflight、codex exec、schema check、verify のイベントを追記する

## `--output-schema` の対応範囲
- repo-local validator が対応するのは、`type`, `enum`, `required`, `properties`, `items`, `additionalProperties` とメタデータ系キーのみ。
- `oneOf`, `anyOf`, `allOf`, `const`, `pattern`, `minimum` など未対応の keyword を含む schema は `invalid_output` ではなく「unsupported schema keyword」として失敗させる。

## Docker sandbox
- 既定では無効。`CODEX_DOCKER_IMAGE` を設定しない限り `docker-sandbox` runtime は失敗する。
- repo root を `/workspace` に mount し、必要なら `~/.codex` と `OPENAI_API_KEY` を container へ渡す。
- host fallback はしない。Docker 実行に必要な前提が足りない場合は明示エラーで止める。

## 推奨フロー
- 手動で探索・相談しながら進める:
  - `codex-safe`
- 生成物をファイルで残す自動実装・CI 補助:
  - `codex-task`
- 外部隔離環境を明示的に用意できる:
  - `codex-sandbox`

## 関連資料
- `docs/reference/codex-safety-harness.md`
- `docs/reference/repository-layout.md`
