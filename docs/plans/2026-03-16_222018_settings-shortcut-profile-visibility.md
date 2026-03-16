# 設定画面整理とプロファイル名の可視化

## Summary
- 設定画面を `基本` / `コピー` / `ショートカット` の3カード構成に整理し、`ショートカット時のタスク名` を `コピー` から分離する。
- `ショートカット` カードに、各コマンドの現在割り当て表示、未割り当て案内、`chrome://extensions/shortcuts` を開く導線を追加する。
- `プロファイル名` は各ログの `profile_label` として保存されることを明示し、抽出 TSV にも `プロファイル名` 列として出力する。

## Key Changes
- `chrome-extension/options.html`
  - `コピー` カードには `ヘッダー行` だけを残す。
  - 新しい `ショートカット` カードを追加し、`ショートカット時のタスク名`、割り当て状況表示、ショートカット設定を開くボタン、補足説明を配置する。
  - `基本` カードの `プロファイル名` に用途説明を追加する。
- `chrome-extension/options.js`
  - `chrome.commands.getAll()` の結果から、開始 / 休憩 / 終了それぞれの現在ショートカットを表示する処理を追加する。
  - `ショートカット設定を開く` ボタンを追加し、可能なら `chrome://extensions/shortcuts` を開き、失敗時は案内文へフォールバックする。
- `chrome-extension/lib/shortcut.js`
  - 既存の未割り当て要約メッセージは維持しつつ、options 画面で使えるコマンド一覧向けの整形ヘルパーを追加する。
- `chrome-extension/lib/utils.js`
  - `logsToTsv()` のヘッダーと行データに `プロファイル名` 列を追加する。
- `chrome-extension/styles.css`
  - 新しい `ショートカット` カード用に、割り当て一覧と補助テキストのスタイルを追加する。

## Test Plan
- `tests/shortcut.test.js` でコマンド一覧整形ヘルパーと既存要約メッセージを確認する。
- `tests/utils.test.js` で `logsToTsv()` が `プロファイル名` 列をヘッダーあり/なしの両方で出力することを確認する。
- `npm run test` と `npm run lint` を実行する。

## Assumptions
- Chrome 拡張はショートカット自体を独自 UI で編集できないため、実際の割り当て変更先は `chrome://extensions/shortcuts` のままとする。
- TSV の `プロファイル名` 列は末尾追加とし、既存利用者の先頭列解釈をできるだけ崩さない。
- popup のショートカット案内は現状どおり簡潔表示を維持し、詳細案内は options 画面に集約する。
