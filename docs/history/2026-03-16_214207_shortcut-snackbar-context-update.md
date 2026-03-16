# Project Context History

- 日時: 2026-03-16 21:42:07 JST
- 要約: ショートカット記録の shared module 化、ページ内 snackbar、shortcut task name mode 追加を反映

## 変更点
- `chrome-extension/lib/shortcut.js` を主要実装へ追加
- `service_worker.js` の役割を「記録 + ページ通知」に更新
- `storage.js` に旧 shortcut 設定からの移行責務を追記
- `shortcutTaskNameMode` と `chrome.scripting.executeScript()` ベースの通知制約を記録
