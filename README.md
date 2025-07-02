# AACT Bot - Shiny Application

AACT (Aggregate Analysis of ClinicalTrials.gov) データベースの分析を支援するAIチャットボットです。

## 機能

- **AACT データベース接続**: PostgreSQL データベースへの接続機能
- **AI チャットインターフェース**: Google Gemini APIを使用した対話型分析
- **SQL クエリ実行**: AACT データベースに対するSQL クエリの実行
- **R コード実行**: 統計解析とデータ可視化
- **リアルタイム結果表示**: チャット形式での結果表示

## 必要な環境

### Rパッケージ

以下のパッケージが必要です：

- shiny
- bslib  
- shinyjs
- htmltools
- ellmer
- shinychat
- DBI
- RPostgreSQL
- fastmap
- R6
- jsonlite
- knitr
- base64enc
- evaluate
- promises
- coro
- whisker
- tibble
- withr
- utils
- rlang

### API キー

Google Gemini API キーが必要です。以下の環境変数のいずれかを設定してください：

- `GEMINI_API_KEY`
- `AACTBOT_API_KEY`

### AACT データベースアクセス

AACT データベースにアクセスするには、以下が必要です：

1. [AACT ウェブサイト](https://aact-db.ctti-clinicaltrials.org/)でアカウント登録
2. データベースのユーザー名とパスワード

## インストールと実行

### 1. 依存パッケージのインストール

```r
# CRAN パッケージ
install.packages(c(
  "shiny", "bslib", "shinyjs", "htmltools", "DBI", "RPostgreSQL",
  "fastmap", "R6", "jsonlite", "knitr", "base64enc", "evaluate",
  "promises", "coro", "whisker", "tibble", "withr", "rlang"
))

# GitHub パッケージ
remotes::install_github("tidyverse/ellmer#503")
remotes::install_github("posit-dev/shinychat", subdir = "pkg-r")
```

### 2. 環境変数の設定

```r
# R セッション内で設定
Sys.setenv(GEMINI_API_KEY = "your_api_key_here")

# または .Renviron ファイルに追加
# GEMINI_API_KEY=your_api_key_here
```

### 3. アプリケーションの実行

```r
# R コンソールで実行
shiny::runApp()

# または
source("app.R")
```

## ファイル構造

```
.
├── app.R              # メインアプリケーションファイル
├── global.R           # グローバル設定と依存関係
├── functions/         # 関数ファイル
│   ├── util.R         # ユーティリティ関数
│   ├── prompt.R       # AIプロンプト設定
│   ├── mdstreamer.R   # マークダウンストリーマー
│   ├── functions.R    # データ処理関数
│   ├── tools.R        # AIツール関数
│   └── chat_bot.R     # チャットボット設定
└── README.md          # このファイル
```

## 使用方法

1. アプリケーションを起動
2. 上部のフォームにAACTのユーザー名とパスワードを入力
3. 「接続」ボタンをクリックしてデータベースに接続
4. チャットインターフェースで質問や分析依頼を入力
5. AIが適切なSQL クエリやR コードを生成・実行して結果を表示

## 主要なAACTテーブル

- `studies`: 臨床試験の基本情報
- `interventions`: 介入方法
- `conditions`: 対象疾患  
- `outcomes`: アウトカム指標
- `facilities`: 実施施設
- `eligibility_criteria`: 適格基準
- `design_groups`: 試験デザイン群
- `sponsors`: スポンサー情報

## ライセンス

MIT License
