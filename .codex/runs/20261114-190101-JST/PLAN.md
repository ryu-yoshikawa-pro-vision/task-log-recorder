# Plan

## Objective
- Dependabot security update PRのための安全な継続検証を提案する。

## Scope
- In: .github/workflows/ci.yml、docs/plansの計画、run artifacts。
- Out: security/Dependabot settings、通常version update schedule、branch protection、Secrets、実ブラウザー操作、default branchへの直接push、merge/close。

## Assumptions
- npm package-lock.jsonとnpm scriptsが本repoの品質検証の正本。
- Actions PR runにはrepository secretsを渡さず、read-only permissionだけを使う。

## Hypotheses
- H1: ADR 001のnpm run verify:quality（format、lint、unit test）はCIでsecretなしに実行可能。
- H2: unit testsはbrowser storage mockを使い、外部サービスや実Chromeへ接続しない。

## Research Plan
- Round 1 Query: AGENTS、PROJECT_CONTEXT、ADR、README、package scripts、test suiteを確認。
- Round 2 Query: workflow PRのheadとActions runを照合。
- Exit Criteria:
  - H1/H2をrepoの仕様・静的調査とCIで確認する。
  - CI失敗が残る場合は除外せず理由と次の対応を記録する。

## Approach
- AGENTSに従い、この計画とrun artifactsを保存する。
- feature branchにleast-privilege CI workflowを追加し、既存quality commandだけを実行する。
- PRを作成し、run結果をhead SHAへ照合して報告する。

## Definition of Done
- workflowがPRおよびmain pushでnpm ciとnpm run verify:qualityを実行する。
- secret不要・contents:read・checkout credential非保存が確認できる。
- PR latest headのCI全stepがsuccess。PRは未mergeのまま。

## Risks / Unknowns
- 既存quality checksが現在のdefault branchで失敗する可能性がある。実行結果をそのまま報告し、無関係なsource修正やcheck除外をしない。

## Thinking Log
- 2026-11-14 JST: ADR 001がnpm / Biome / html-validate / Vitestを規定。workflow fileと外部CIはなし。unit testsは純粋ロジックを対象にし、network APIs・環境変数・process起動・実ファイル書込みをテストから検出しなかった。https URL文字列はshortcut fixture用で、fetch等の呼出しは未検出。npm run verify:qualityをPR CIで検証する。
