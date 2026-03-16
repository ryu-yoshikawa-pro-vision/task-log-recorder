# ショートカット記録修正とページ内スナックバー追加

## Summary
- `chrome.commands` の記録処理を service worker に集約したまま整理し、ポップアップ非表示時でも Chrome 内で記録できる状態にする。
- ショートカット実行時の既定タスク名を現在ページタイトルに変更し、設定で直近タスク名へ切り替えられるようにする。
- 記録成功時は現在ページ上へスナックバーを表示し、重複や失敗は warning 表示へフォールバックする。

## Key Changes
- `manifest.json` に `scripting` 権限を追加する。
- `chrome-extension/lib/shortcut.js` を追加し、command 変換、payload 生成、設定互換、重複判定、ステータス文言を集約する。
- `service_worker.js` は shared module を呼び出し、必要時だけ `chrome.scripting.executeScript()` でページ内 snackbar を表示する。
- 設定値は `shortcutTaskNameMode: "page-title" | "last-task"` に移行し、旧 `shortcutUsesLastTask` は読み替える。
- popup / options で `chrome.commands.getAll()` を読み、未割り当てショートカットを案内する。

## Test Plan
- `tests/storage.test.js` で旧設定値の移行を確認する。
- `tests/shortcut.test.js` で command 変換、task name 決定、重複時の warning、通知失敗時の継続、保存失敗時の error を確認する。
- `npm run test` と `npm run lint` を実行する。依存未導入なら `npm install` を先に実施する。

## Assumptions
- 対象は Chrome 内ショートカットであり、OS グローバルショートカット化はスコープ外。
- ページ通知は `alert()` ではなく自動で消える snackbar を使う。
- 注入不可ページではページ通知を諦め、拡張内の `shortcutStatus` 更新のみ行う。
