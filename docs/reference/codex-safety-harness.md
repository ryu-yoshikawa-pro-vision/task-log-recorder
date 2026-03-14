# Codex安全ハーネス運用ガイド

## 目的
- リポジトリ内で Codex を使う際に、危険な実行オプションやコマンドを減らすための実務的なガードレールを提供する。
- `AGENTS.md` のルールに加え、`execpolicy` ルールと wrapper で技術的制御を追加する。

## 構成
- `scripts/codex-safe.ps1`
  - Codex 起動 wrapper
  - 危険 CLI 引数（`--dangerously-bypass-approvals-and-sandbox`, `-c/--config`, `--add-dir` など）を拒否
  - 安全デフォルト（`--sandbox`, `--ask-for-approval`）を固定注入
  - 起動前に `codex execpolicy check` でルールのスモークテストを実施（preflight）
  - JSONL ログ（既定: `.codex/logs/codex-safe-YYYYMMDD.jsonl`）に開始/ブロック/preflight/起動イベントを追記
- `scripts/codex-safe.sh`
  - bash 向け Codex 起動 wrapper（PowerShell 版と同方針）
  - 危険 CLI 引数の拒否、`--sandbox` / `--ask-for-approval` 固定注入、preflight を実施
  - `--print-command` / `--preflight-only` / `--allow-search` / `--log-path` をサポート
- `.codex/rules/*.rules`
  - `execpolicy` ルール
  - 読み取り系の allow、広い prompt、破壊系の forbidden を定義
- `.codex/config.toml`
  - 任意の project profile（`repo_safe`, `repo_readonly`）
- `.codex/requirements.toml`
  - 管理配布/機能有効化時に使う補助的な最小要件定義
- `scripts/verify`
  - 品質ゲート実行の統一エントリポイント
  - execpolicy 判定、bash wrapper preflight、bash/PowerShell テスト（可能環境のみ）を実行

関連する上位ガイド:
- `docs/reference/codex-implementation-harness.md`
  - `codex-safe` / `codex-task` / `codex-sandbox` の使い分け

## 推奨起動方法
PowerShell から実行:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/codex-safe.ps1
```

非対話実行の例:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/codex-safe.ps1 exec "作業内容..."
```

read-only preset:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/codex-safe.ps1 -Preset readonly
```

preflight のみ:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/codex-safe.ps1 -PreflightOnly
```

bash から実行:

```bash
bash scripts/codex-safe.sh
```

## 何をブロックするか（例）
- `--dangerously-bypass-approvals-and-sandbox`
- `-c` / `--config`
- `--add-dir`
- `-C` / `--cd`
- `-s` / `--sandbox`
- `-a` / `--ask-for-approval`
- `-p` / `--profile`
- `--enable` / `--disable`

## 運用メモ
- ルール変更後は `-PreflightOnly` と `codex execpolicy check` で確認する。
- 破壊系ルールの追加時は、`docs/reports/` に検証結果を残す。
- consumer repo では `bash scripts/verify` を最初の確認コマンドとして使う。
- 非対話実行では `codex-safe` ではなく `codex-task` を使い、`output/report` を成果物として残す。
