# 計画書

## 0. 依頼概要
- 依頼内容: Chrome 拡張プロジェクトへ formatter、linter、unit test を導入し、品質を担保できるようにする。
- 背景: 現状は Codex 運用基盤向け verify のみがあり、拡張本体には自動の静的解析やテストがない。
- 期待成果: `npm` コマンドで format / lint / test / verify が実行でき、導入直後からグリーンで維持できる。

## 1. ゴール / 完了条件
- ゴール: 拡張本体に対する静的解析と unit test の最小実用基盤を追加する。
- 完了条件（DoD）:
  - `npm run format:check`
  - `npm run lint`
  - `npm run test`
  - `npm run verify:quality`
  - `bash scripts/verify`
  - `powershell -ExecutionPolicy Bypass -File scripts/verify.ps1`
  上記がすべて成功する。

## 2. スコープ
- In Scope:
  - `package.json` と依存導入
  - `biome.json`、`.htmlvalidate.json`、`vitest.config.js`、test setup の追加
  - `chrome-extension/` の format / lint 是正
  - `scripts/verify*` の quality check 統合
  - README / PROJECT_CONTEXT / history / ADR / report 更新
- Out of Scope:
  - TypeScript 化
  - E2E テスト
  - 拡張機能の機能仕様変更

## 3. 実行タスク
- [x] 1. 現状の構成と verify を調査する
- [x] 2. 採用ツールと初回是正方針を決める
- [ ] 3. `npm` 品質基盤と test/config を追加する
- [ ] 4. `chrome-extension/` の既存指摘を解消する
- [ ] 5. verify と docs を更新し、全検証を実行する

## 4. マイルストーン
- M1: 計画書と run artifact を保存する
- M2: 品質基盤と tests を実装し、ローカル check を通す
- M3: verify / docs / report を更新して完了にする

## 5. リスクと対策
- リスク: HTML / CSS / JS の整形差分が広く出る
  - 対策: format は機械適用し、lint 指摘だけを機能非変更で修正する
- リスク: Node test で `chrome` API 依存が詰まる
  - 対策: 初回は pure function と storage wrapper に限定し、test setup で mock する

## 6. 検証方法
- 実施する確認:
  - `npm install`
  - `npm run format:check`
  - `npm run lint`
  - `npm run test`
  - `npm run verify:quality`
  - `bash scripts/verify`
  - `powershell -ExecutionPolicy Bypass -File scripts/verify.ps1`
- 成功判定:
  - すべて成功し、拡張の runtime 仕様に変更がない

## 7. 成果物
- 変更ファイル:
  - root config / scripts / tests / `chrome-extension/` / docs
- 付随ドキュメント:
  - `docs/plans/2026-03-14_215231_quality-tooling-rollout.md`
  - 実装後の `docs/reports/...`

## 8. 備考
- package manager は `npm`
- quality stack は Biome + html-validate + Vitest
- HTML は validator 主体で扱う
