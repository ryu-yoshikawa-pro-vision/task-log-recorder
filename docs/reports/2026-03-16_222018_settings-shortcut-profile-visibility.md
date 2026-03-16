# 設定画面整理とプロファイル名の可視化 レポート

## Summary
- 設定画面を `基本` / `コピー` / `ショートカット` に分割し、ショートカット時のタスク名設定を `コピー` から分離した。
- options 画面に開始 / 休憩 / 終了のショートカット割り当て一覧と `chrome://extensions/shortcuts` への導線を追加した。
- `プロファイル名` の用途を設定画面で明示し、TSV の末尾列にも `プロファイル名` を出力するようにした。
- `tests/shortcut.test.js` と `tests/utils.test.js` を更新し、割り当て一覧整形と TSV 列追加を検証した。

## Verification
- `node --check chrome-extension/options.js`
  - 成功。
- `node --check chrome-extension/lib/shortcut.js`
  - 成功。
- `node --check chrome-extension/lib/utils.js`
  - 成功。
- `npm run test`
  - 成功。`3` files / `24` tests passed。
- `npm run lint`
  - 成功。Biome lint / html-validate ともに通過。

## Files
- `chrome-extension/options.html`
- `chrome-extension/options.js`
- `chrome-extension/lib/shortcut.js`
- `chrome-extension/lib/utils.js`
- `chrome-extension/styles.css`
- `tests/shortcut.test.js`
- `tests/utils.test.js`
- `docs/PROJECT_CONTEXT.md`
- `README.md`
