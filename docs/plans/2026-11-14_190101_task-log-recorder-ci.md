# task-log-recorder Dependabot PR検証CI 計画

## 0. 依頼概要
- 依頼内容: npm依存security-only更新PRで、安全な既存品質検証を自動実行できるようにする。
- 背景: main SHA 941d859c395a0a5c9a5ea78c1c58e50f6d8c5d75にActions/外部CIがなく、ADR 001でnpm・Biome・html-validate・Vitestの品質基盤が定義されている。
- 期待成果: PRおよびmain pushでnpm ciとnpm run verify:qualityを実行する提案PRと、最新head上のCI結果。

## 1. ゴール / 完了条件
- ゴール: 既存の個別quality commandsを使ったread-only・secret不要のPR検証を提案する。
- 完了条件（DoD）: 変更はfeature branchのPRに限定し、workflow permissionはcontents: read、npm ciが成功し、format / lint / unit testの各stepが最新headでsuccessする。mergeやbranch protection変更はしない。

## 2. スコープ
- In Scope: .github/workflows/ci.yml、本計画、.codex/runs/20261114-190101-JST/のTASKS/REPORT/PLAN記録。
- Out of Scope: security/Dependabot settings、通常version update schedule、Secrets、実行時のChrome拡張操作、管理設定、merge/close、default branchへの直接push。

## 3. 実行タスク
- [x] 1. AGENTS/PROJECT_CONTEXT/ADR/README、npm scripts、Vitest対象と副作用境界を調査する。
- [x] 2. 対象とDoDを計画書に固定する。
- [ ] 3. run artifactsを保存し、PR CI workflowを作成する。
- [ ] 4. PRを作成し、最新head SHAのCIを検証する。
- [ ] 5. run REPORTと外部進捗メモへ結果・残件を記録する。

## 4. マイルストーン
- M1: 調査と計画を保存（完了）。
- M2: feature branch上にworkflow/run artifactsを含むPRを作成。
- M3: CI結果を最新PR headへ照合し、未merge状態とともに報告。

## 5. リスクと対策
- リスク: CIから秘密情報を利用したり、実ブラウザー/外部サービスへ接続する。
  - 対策: ADRで規定されたformat/lint/unit testのみ実行し、workflowはcontents: read、Secretsなし、checkout credentialsを保持しない。
- リスク: 既存テストが失敗している可能性。
  - 対策: 失敗をCIで可視化し、範囲外の不具合修正や検査除外を独断で行わない。

## 6. 検証方法
- 実施する確認: PR CIでnpm ciのあと、npm run format:check、npm run lint、npm run testを独立stepで確認する。各stepはinstall成功時に実行し、先行品質stepの失敗でskipしない。
- 成功判定: runがcompleted/successで、PRのlatest head SHAとrunのSHAが一致する。

## 7. 成果物
- 変更ファイル: .github/workflows/ci.yml
- 付随ドキュメント: 本計画、run PLAN/TASKS/REPORT。

## 8. 備考
- Security-only方針を維持し、Dependabotの定期version updatesは追加しない。
- CIを有効化する既存GitHub管理設定・branch protectionは変更しない。
