# ポップアップ履歴UIの開閉・統計・ページネーション調整

## Summary
- 記録タブの「現在のページ」を、初期状態で閉じたエクスパンションパネルに変更した。
- 履歴タブの総件数・最新の日付・表示範囲を、1 行の横並び表示へ戻した。
- 履歴タブのページネーションをリスト上部と下部の両方に配置し、同じ state で同期するようにした。

## Progress
- Progress: 100% (4/4)

## Evidence
- `npm run format`
  - `biome format --write .` が成功した。
- `npm run lint`
  - `biome lint . && html-validate "chrome-extension/**/*.html"` が成功した。
- `npm test`
  - 3 test files / 26 tests がすべて成功した。
- 主要変更ファイル
  - `chrome-extension/popup.html`
  - `chrome-extension/popup.js`
  - `chrome-extension/styles.css`
  - `.codex/runs/20260317-004650-JST/PLAN.md`
  - `.codex/runs/20260317-004650-JST/TASKS.md`
  - `.codex/runs/20260317-004650-JST/REPORT.md`
  - `docs/plans/2026-03-17_004650_popup-history-ui-adjustments.md`

## Additional Update
- popup の高さを記録タブに近づけるため、`chrome-extension/styles.css` で次を調整した。
- `popup-body` の最小高さを `620px` に変更した。
- `card-tall` の最小高さを `252px` に変更した。
- 変更後に `npm run format` `npm run lint` `npm test` を再実行し、すべて成功した。

## Additional Update 2
- 履歴概要を横並びの情報ブロックに変更した。
- 記録タブには `record-grid` を導入し、record タブ内の panel 固定高さを外した。
- 現在のページパネルは見出しだけを常時表示する形へ簡潔化し、縦余白を削減した。
- popup 全体の最小高さは `680px` に調整した。
- 変更後に `npm run format` `npm run lint` `npm test` を再実行し、すべて成功した。

## Additional Update 3
- 記録タブの現在のページセクションは `display: none` で非表示化した。
- 記録タブは `record-grid` を 1 カラムにして、入力パネルだけが見える状態にした。
- 履歴概要ブロックは popup 幅でも 3 列の横並びを維持するよう、mobile 向けの 1 カラム化を外した。
- 変更後に `npm run format` `npm run lint` `npm test` を再実行し、すべて成功した。

## Additional Update 4
- 履歴ヘッダーを縦積みに変更し、概要ブロック 3 つが直近ログリストと同じ横幅いっぱいに広がるようにした。
- 削除ボタンとページネーションは概要ブロックの下段へ移し、ブロック幅を圧迫しない構成にした。
- 変更後に `npm run format` `npm run lint` `npm test` を再実行し、すべて成功した。

## Manual Check Notes
- popup DOM テスト基盤は追加していないため、次を手動確認対象として残す。
- 初期表示で「現在のページ」セクションが閉じていること。
- トグル操作で `aria-expanded` と詳細表示が切り替わること。
- 履歴が 11 件以上ある場合に、上下どちらのページネーション操作でも表示内容が同期すること。
- 履歴 0 件時に、統計表示と上下ページネーションが破綻しないこと。
