# 2026-03-14 22:00:35 JST Quality Tooling Rollout

## Summary

- `npm` ベースの品質基盤を追加し、`Biome`、`html-validate`、`Vitest` を導入した。
- `chrome-extension/` の既存コードへ format を適用し、HTML validator 指摘を解消した。
- `scripts/verify*` に `npm run verify:quality` を統合した。
- README、`docs/PROJECT_CONTEXT.md`、history、ADR、plan を更新した。

## Main Changes

- 追加:
  - `package.json`
  - `package-lock.json`
  - `biome.json`
  - `.htmlvalidate.json`
  - `vitest.config.js`
  - `tests/setup.js`
  - `tests/utils.test.js`
  - `tests/storage.test.js`
  - `docs/adr/001-quality-tooling-baseline.md`
  - `docs/history/2026-03-14_215233_quality-tooling-context-update.md`
  - `docs/plans/2026-03-14_215231_quality-tooling-rollout.md`
- 更新:
  - `chrome-extension/manifest.json`
  - `chrome-extension/options.html`
  - `chrome-extension/options.js`
  - `chrome-extension/popup.html`
  - `chrome-extension/popup.js`
  - `chrome-extension/service_worker.js`
  - `chrome-extension/styles.css`
  - `chrome-extension/lib/storage.js`
  - `chrome-extension/lib/utils.js`
  - `scripts/verify`
  - `scripts/verify.ps1`
  - `README.md`
  - `docs/PROJECT_CONTEXT.md`
  - `.gitignore`

## Verification

- `npm install`
  - success
- `npm run format`
  - success, `Formatted 14 files`, `Fixed 12 files`
- `npm run lint`
  - success
- `npm run test`
  - success, `Test Files 2 passed`, `Tests 12 passed`
- `npm run verify:quality`
  - success
- `powershell -ExecutionPolicy Bypass -File scripts/verify.ps1`
  - success, `PASS=4 FAIL=0 SKIP=0`
- `bash scripts/verify`
  - 失敗、既定の `bash.exe` が WSL ラッパーで `WSL_OPTIONAL_COMPONENT_REQUIRED`
- `C:\Program Files\Git\bin\bash.exe scripts/verify`
  - success, `PASS=5 FAIL=0 SKIP=0`

## Notes

- この環境では `bash` の PATH 解決先が WindowsApps の WSL ラッパーだったため、Bash verify は Git Bash 実体で実行した。
- 手動 smoke test は未実施。必要なら unpacked extension を読み込んで popup / options / export の基本操作を確認する。
