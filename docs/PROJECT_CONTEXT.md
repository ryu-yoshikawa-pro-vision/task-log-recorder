# Project Context

## 目的

- このリポジトリは、個人用 Chrome 拡張「作業ログ記録」と、その保守に使う Codex 運用基盤を同居させている。
- 目的は、実装の実態、運用ルール、変更時の着眼点を短時間で共有できる状態を保つこと。

## プロダクト概要

- 拡張は Manifest V3 ベースで、現在タブのタイトルと URL を取得し、`開始` / `休憩` / `終了` のログをローカル保存する。
- ログは `chrome.storage.local` に保存され、ポップアップ UI から履歴確認、編集、削除、日付単位の TSV 抽出を行う。
- 外部 API、サーバー、認証、同期処理は現状存在しない。
- 現在のワークツリーに `apps-script/` は含まれておらず、実装主体は `chrome-extension/` 配下にある。

## 実装の要点

- `chrome-extension/manifest.json`
  - popup、options、service worker、commands を定義する。
- `chrome-extension/popup.js`
  - 3タブ UI の状態管理、ログ記録、履歴表示、編集、削除、TSV 抽出を担当する。
- `chrome-extension/options.js`
  - 基本 / コピー / ショートカット設定の表示と保存、割り当て状況表示を担当する。
- `chrome-extension/service_worker.js`
  - ショートカット入力を受けてバックグラウンドでログを追加し、必要時は現在ページへ snackbar を表示する。
- `chrome-extension/lib/shortcut.js`
  - ショートカットの command 変換、task name 決定、重複判定、通知文言を集約する。
- `chrome-extension/lib/storage.js`
  - `chrome.storage.local` のアクセスを集約し、旧 shortcut 設定値からの移行も担当する。
- `chrome-extension/lib/utils.js`
  - イベント表示名、重複判定、TSV 変換、日付抽出などの純粋関数を持つ。

## 主要なデータと制約

- 保存キーは `logs`、`settings`、`lastFingerprint`、`lastTaskName`、`shortcutStatus`。
- 各ログは `profile_label` を持てる。設定画面の `プロファイル名` に対応し、TSV 抽出でも末尾列へ出力する。
- shortcut 設定は `shortcutTaskNameMode` を使い、`page-title` を既定、`last-task` を任意切替とする。旧 `shortcutUsesLastTask` は読み出し時に移行する。
- 重複判定は「直前ログとの fingerprint 一致」かつ「設定秒数以内」で行う。
- 記録イベントの内部値は `START` / `BREAK` / `END_DAY`。文書でもこの実装との差異を生まないようにする。
- ショートカット通知は `scripting` 権限と `chrome.scripting.executeScript()` で注入し、`chrome://` 系など注入不可ページでは `shortcutStatus` のみ更新する。
- 現状はビルド工程なしで unpacked extension として読み込む前提。

## リポジトリ運用

- `AGENTS.md` の読込順、run 初期化、進捗記録のルールを守る。
- 調査ログは `.codex/runs/<run_id>/` に残し、必要に応じて `docs/reports/` にも要約を残す。
- `docs/PROJECT_CONTEXT.md` は living document とし、更新時は `docs/history/` に履歴を追記する。
- 重要な設計判断は `docs/adr/` に記録する。

## ディレクトリ構成

- `chrome-extension/`: 拡張本体
- `tests/`: 拡張本体の unit test
- `.codex/templates/`: PLAN / TASKS / REPORT の run テンプレート
- `.codex/rules/`: execpolicy ルール
- `.agents/skills/`: repo-local の planning / review workflow
- `docs/plans/`: 計画書
- `docs/reports/`: 調査・実行レポート
- `docs/reference/`: 保守者向け補助資料
- `docs/history/`: `PROJECT_CONTEXT` 変更履歴
- `scripts/`: `codex-safe` / `codex-task` / `codex-sandbox` / `verify`

## 品質確認

- `npm` ベースの品質基盤を持ち、`Biome` で JS / CSS / JSON の format / lint、`html-validate` で HTML 検証、`Vitest` で unit test を実行する。
- `npm run verify:quality` は `format:check`、`lint`、`test` をまとめて実行する。
- `bash scripts/verify` と `powershell -ExecutionPolicy Bypass -File scripts/verify.ps1` は Codex 運用基盤の整合性に加えて、`package.json` が存在する場合は `npm run verify:quality` も確認する。
- UI や Chrome 拡張挙動の変更では、手動確認の観点をレポートに残す。

## ドキュメント更新時の注意

- README の機能説明は実装のイベント名に合わせる。
- `docs/reference/repository-layout.md` など構造説明文書は、実際のディレクトリ構成と同時に更新する。
- 未存在のディレクトリや将来案を既成事実のように書かない。
