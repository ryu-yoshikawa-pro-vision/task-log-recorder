# Repository Layout

```text
.
├─ chrome-extension/
│  ├─ manifest.json
│  ├─ popup.html / popup.js
│  ├─ options.html / options.js
│  ├─ service_worker.js
│  ├─ lib/
│  ├─ icons/
│  └─ styles.css
├─ AGENTS.md
├─ PLANS.md
├─ CODE_REVIEW.md
├─ .codex/
├─ .agents/
├─ docs/
└─ scripts/
```

## 補足
- `chrome-extension/` がプロダクト本体で、Manifest V3 の unpacked extension として読み込む。
- `.codex/runs/` と `.codex/logs/` は実行時に増える。
- `.agents/skills/*/references/` は task-specific workflow の詳細手順。
- `docs/reference/` は人間向けの補助文書。
- `docs/plans/` と `docs/reports/` は成果物の保存先。
- `scripts/` には `codex-safe`、`codex-task`、`codex-sandbox`、`verify` が含まれる。
