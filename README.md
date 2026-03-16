# 作業ログ記録

個人利用を前提にした、Chrome 拡張ベースの作業ログ記録ツールです。  
現在開いているページのタイトルと URL を起点に、`開始` / `休憩` / `終了` のログを `chrome.storage.local` へ保存し、日付単位で TSV 抽出できます。

このリポジトリには、拡張本体に加えて Codex 運用用のドキュメント、テンプレート、検証スクリプトも含まれます。

## 現在の構成

- `chrome-extension/`: 拡張本体
- `tests/`: unit test
- `docs/`: プロジェクト理解、運用ルール、参照資料
- `scripts/`: Codex 実行ラッパーと検証スクリプト
- `.codex/`, `.agents/`: Codex 用テンプレート、ルール、skills

## 拡張の機能

- ポップアップの `記録` タブから `開始` / `休憩` / `終了` を手動記録
- 現在タブのタイトルと URL を自動取得
- タスク名とメモを任意入力
- `履歴` タブで直近ログを 10 件ずつ表示、編集、削除
- `抽出` タブでログがある日付のみ選択して TSV を生成
- クリップボードへコピーし、そのままスプレッドシートへ貼り付け可能
- ショートカット記録を service worker で処理
- 一定秒数内の同一内容ログを重複記録しない

## 技術的な前提

- Manifest V3 の Chrome 拡張
- バンドラやビルド工程なしで、そのまま読み込む構成
- データ保存先は `chrome.storage.local`
- 外部 API、バックエンド、同期サーバーは未使用

保存している主なキー:

- `logs`
- `settings`
- `lastFingerprint`
- `lastTaskName`
- `shortcutStatus`

## インストール

1. Chrome で `chrome://extensions/` を開く
2. 右上の「デベロッパーモード」を ON にする
3. 「パッケージ化されていない拡張機能を読み込む」を選ぶ
4. `chrome-extension/` ディレクトリを指定する

## 開発用セットアップ

1. Node.js 24 以降を用意する
2. リポジトリ直下で `npm install` を実行する

## 使い方

### 1. 記録

- `記録` タブを開くと、現在ページのタイトルと URL を読み込む
- 必要に応じて `タスク名` と `メモ` を調整する
- `開始` / `休憩` / `終了` のいずれかを押す

### 2. 履歴確認

- `履歴` タブで保存済みログを 10 件ずつ確認する
- 各ログから `編集` と `削除` を実行できる

### 3. 抽出

- `抽出` タブでログが存在する日付を選ぶ
- `抽出する` で TSV プレビューを生成する
- `コピー` でクリップボードへ書き出す
- TSV には `プロファイル名` 列も含まれる

## 設定

`options.html` では次を変更できます。

- プロファイル名
- 重複除外秒数
- コピー時にヘッダー行を含めるか
- ショートカット記録時に直近タスク名を使うか

`プロファイル名` は各ログに保存され、TSV 抽出にも含まれます。

## ショートカット

初期割り当ては次のとおりです。

- `Ctrl + Shift + 1`: 開始
- `Ctrl + Shift + 2`: 休憩
- `Ctrl + Shift + 3`: 終了

変更する場合は `chrome://extensions/shortcuts` を使います。

## 主要ファイル

- `chrome-extension/manifest.json`: 権限、popup、options、commands 定義
- `chrome-extension/popup.js`: 記録、履歴、抽出 UI の制御
- `chrome-extension/service_worker.js`: ショートカット記録
- `chrome-extension/lib/storage.js`: `chrome.storage.local` の読み書き
- `chrome-extension/lib/utils.js`: ログ整形、重複判定、TSV 変換

## 検証

開発時の品質確認は `npm` scripts とリポジトリ同梱の verify を使います。

- `npm run format`: Biome で JS / CSS / JSON を整形
- `npm run format:check`: format 差分のみ確認
- `npm run lint`: Biome lint と HTML validator を実行
- `npm run test`: Vitest で unit test を実行
- `npm run verify:quality`: format / lint / test を一括実行

verify スクリプトは Codex 運用基盤の整合性に加えて、`package.json` がある場合は `npm run verify:quality` も実行します。

- Bash: `bash scripts/verify`
- PowerShell: `powershell -ExecutionPolicy Bypass -File scripts/verify.ps1`

## 補足

- 現在のワークツリーには `apps-script/Code.gs` は存在しません。
- 仕様変更時は `docs/PROJECT_CONTEXT.md` と関連文書を合わせて更新します。
