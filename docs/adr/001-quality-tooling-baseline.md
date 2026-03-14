# ADR 001: 品質基盤の初期スタック

## Context

- 拡張本体は `chrome-extension/` 配下の素の ESM JavaScript / HTML / CSS で構成されている。
- これまで自動検証は Codex 運用基盤向けの `scripts/verify*` が中心で、拡張本体には format / lint / test の常設コマンドがなかった。
- runtime 仕様やビルド工程を増やさずに、ローカルで再現しやすい品質基盤を追加したい。

## Decision

- package manager は `npm` を採用する。
- JS / CSS / JSON の format / lint には `Biome` を採用する。
- HTML は `Biome` の formatter に依存せず、`html-validate` で検証する。
- unit test には `Vitest` を採用し、初回は `chrome-extension/lib/utils.js` と `chrome-extension/lib/storage.js` を対象にする。
- `scripts/verify` と `scripts/verify.ps1` は、既存の Codex 運用基盤チェックに加えて `npm run verify:quality` を実行する。

## Consequences

- 拡張本体の品質確認は `npm run format:check`、`npm run lint`、`npm run test`、`npm run verify:quality` で一貫して実行できる。
- HTML は validator による構文・アクセシビリティ寄りの検査が中心となり、整形は手動管理を維持する。
- TypeScript や E2E は今回は見送り、必要になった時点で追加 ADR を検討する。
