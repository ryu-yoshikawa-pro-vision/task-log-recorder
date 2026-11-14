# Tasks

## Now
- [x] 1. AGENTS、PROJECT_CONTEXT、ADR、READMEとpackage/test構成を確認する。
- [x] 2. 変更範囲、DoD、副作用境界をdocs/plansの計画書に保存する。
- [x] 3. run artifactsとleast-privilege PR workflowをfeature branchに追加する。
- [x] 4. PRを作成し、latest head SHAでinstall/format/lint/test successを確認する。
- [x] 5. REPORTにrun結果、head SHA、PR状態、残件を記録する。

## Discovered
- D1. 依存更新PRで不足パッケージや脆弱性が発見された場合は、Security-onlyの範囲で別PRに分ける。
- D2. CIのBiome format checkで既存2ファイルのformat driftを検出。Biome formatterの提案を該当ファイルに適用し、CIで再検証済み。

## Blocked
- None.

Progress: 100% (5/5)
