# Planning Workflow

## 使う場面
- 複雑な依頼
- 複数ファイルや複数段階にまたがる依頼
- Plan Mode
- 実装前に変更範囲、検証、移行を固める必要がある依頼

## 固定すること
1. Objective / Scope / Definition of Done
2. Assumptions / Risks / Open Issues
3. 変更対象の責務またはファイル群
4. 検証手順
5. 移行影響とロールバック観点

## 出力ルール
- 実装順に沿って書く。
- 判定条件を曖昧にしない。
- 実装へ進む前に `docs/plans/{yyyy-mm-dd}_{HHMMSS}_{plan_name}.md` を保存する。
- 必要なら `.codex/runs/<run_id>/PLAN.md` と `TASKS.md` にも落とし込む。
