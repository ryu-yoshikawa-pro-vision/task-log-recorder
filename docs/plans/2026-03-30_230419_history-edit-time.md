# 履歴編集の時刻変更対応

## 0. 依頼概要
- 依頼内容: 履歴タブの編集で、既存ログの時刻を変更できるようにする。
- 背景: 現状の編集モーダルでは種別、タスク名、メモ、タイトル、URL のみ編集でき、記録時刻は変更できない。
- 期待成果: 編集した時刻が履歴一覧、並び順、日付抽出、TSV プレビューに一貫して反映される。

## 1. ゴール / 完了条件
- ゴール: 履歴編集モーダルから同一日内の時刻を `HH:MM` 単位で変更できるようにする。
- 完了条件（DoD）:
  - 編集モーダルに `時刻` 入力が追加されている。
  - 保存時に `recorded_at_iso`、`recorded_at_local`、`created_at_epoch` が再計算される。
  - 既存 timestamp が壊れている場合や入力時刻が不正な場合は保存せず、警告を表示する。
  - unit test を追加し、`npm run lint` と `npm test` が成功する。

## 2. スコープ
- In Scope:
  - 編集モーダルへの時刻入力追加
  - timestamp 再計算ロジックの純粋関数化
  - 関連 unit test の追加
- Out of Scope:
  - 日付変更
  - ストレージ schema 変更
  - 履歴以外の入力フォーム変更

## 3. 実行タスク
- [ ] 1. 編集モーダルに `時刻` 入力を追加し、既存ログから `HH:MM` を初期表示する。
- [ ] 2. timestamp 再計算の純粋関数を追加し、保存処理で利用する。
- [ ] 3. unit test を追加し、lint と test を実行する。

## 4. マイルストーン
- M1: 計画書と run artifact を作成し、変更方針を固定する。
- M2: UI と保存ロジックを実装する。
- M3: テストと静的検証を通し、結果を記録する。

## 5. リスクと対策
- リスク:
  - 既存 timestamp が壊れているログで誤った日付を推測する可能性がある。
  - 対策: `recorded_at_iso` と時刻入力を厳格に検証し、解釈できない場合は保存を中断する。
- リスク:
  - 並び順や TSV 出力に使う timestamp の更新漏れが起きる可能性がある。
  - 対策: 保存時に 3 つの timestamp フィールドをまとめて再計算する関数を使う。

## 6. 検証方法
- 実施する確認:
  - `HH:MM` 変換関数の unit test
  - 同一日を維持した timestamp 再計算関数の unit test
  - `npm run lint`
  - `npm test`
- 成功判定:
  - 追加した test を含めて全テスト成功
  - lint 成功
  - 手動確認観点をレポートへ記録

## 7. 成果物
- 変更ファイル:
  - `chrome-extension/popup.html`
  - `chrome-extension/popup.js`
  - `chrome-extension/lib/utils.js`
  - `tests/utils.test.js`
- 付随ドキュメント:
  - `docs/plans/2026-03-30_230419_history-edit-time.md`
  - `.codex/runs/20260330-230419-JST/PLAN.md`
  - `.codex/runs/20260330-230419-JST/TASKS.md`
  - `.codex/runs/20260330-230419-JST/REPORT.md`

## 8. 備考
- 編集範囲はユーザー合意どおり「時刻のみ」、精度は「分単位」とする。
- 同日判定と時刻合成はブラウザのローカルタイムゾーン基準で行う。
