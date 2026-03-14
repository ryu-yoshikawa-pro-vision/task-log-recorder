# 2026-03-14 21:52:33 JST

## Summary

- `docs/PROJECT_CONTEXT.md` に、`npm` ベースの品質基盤と `tests/` ディレクトリを反映した。
- `README.md` に開発用セットアップと `format / lint / test / verify` の実行方法を追記した。
- `scripts/verify*` が `package.json` 存在時に quality check も実行する前提へ変わった。

## Notes

- 静的解析スタックは `Biome`、`html-validate`、`Vitest` を採用した。
- HTML は formatter ではなく validator 主体で扱い、`button type` などの構文品質を検査する。
