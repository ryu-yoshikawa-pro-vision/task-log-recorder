# プロジェクト分析と文書同期レポート

## 目的

- 現在の実装を調査し、`README.md` と `docs/PROJECT_CONTEXT.md` 関連文書の記述を実態へ揃える。

## 調査対象

- `chrome-extension/manifest.json`
- `chrome-extension/popup.js`
- `chrome-extension/service_worker.js`
- `chrome-extension/options.js`
- `chrome-extension/lib/storage.js`
- `chrome-extension/lib/utils.js`
- `scripts/verify`
- `scripts/verify.ps1`

## 主な発見

- プロダクト本体は `chrome-extension/` 配下の Manifest V3 拡張である。
- 記録イベントは `開始 / 休憩 / 終了` で、README の `メモ` 表記は実装と一致していなかった。
- ログ保存は `chrome.storage.local` のみを使用し、外部サービス連携は存在しない。
- `scripts/verify*` は Codex 運用基盤向けの整合性チェックであり、拡張 UI の自動テストではない。
- ワークツリーに `apps-script/Code.gs` は存在しない。

## 実施内容

- `README.md` を利用者向けの現行仕様に更新。
- `docs/PROJECT_CONTEXT.md` を保守者向けの実装実態へ更新。
- `docs/reference/repository-layout.md` を現構成へ同期。
- `docs/history/` に `PROJECT_CONTEXT` 更新履歴を追加。

## 検証方針

- 文書差分の妥当性確認
- `scripts/verify*` 実行による運用基盤整合性確認

## 検証結果

- `powershell -ExecutionPolicy Bypass -File scripts/verify.ps1`
  - `PASS: template contract files`
  - `PASS: execpolicy baseline decisions`
  - `PASS: PowerShell wrapper preflight`
  - `Summary: PASS=3 FAIL=0 SKIP=0`
- `bash scripts/verify`
  - WSL / Bash の optional component がないため、この環境では実行不可
