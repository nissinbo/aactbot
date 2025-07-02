aactbot_prompt <- function(has_project = TRUE, llms_txt = NULL) {
  llms_txt <- NULL
  if (file.exists("llms.txt")) {
    llms_txt <- paste(
      readLines("llms.txt", encoding = "UTF-8", warn = FALSE),
      collapse = "\n"
    )
  }

  template <- aactbot_prompt_template()

  whisker::whisker.render(
    template,
    data = list(
      has_project = TRUE, # TODO: Make this dynamic
      has_llms_txt = !is.null(llms_txt),
      llms_txt = llms_txt
    )
  )
}

aactbot_prompt_template <- function() {
  prompt_file <- file.path("inst", "prompt", "prompt.md")
  if (!file.exists(prompt_file)) {
    # Fallback to inline prompt if file doesn't exist
    return("あなたは AACT (Aggregate Analysis of ClinicalTrials.gov) データベースの分析を支援するAIアシスタントです。

主な機能:
1. AACT データベースに対するSQL クエリの生成と実行
2. 臨床試験データの分析と可視化
3. R コードの実行による統計解析
4. データの要約と洞察の提供

利用可能なツール:
- run_r_code: R コードを実行して分析や可視化を行います
- run_aact_query: AACT PostgreSQL データベースに対してSQL クエリを実行します

ユーザーが求める分析に対して、適切なSQL クエリやR コードを提案し、実行してください。
結果を分かりやすく説明し、必要に応じてグラフや表で可視化してください。

AACT データベースの主要テーブル:
- studies: 臨床試験の基本情報
- interventions: 介入方法
- conditions: 対象疾患
- outcomes: アウトカム指標
- facilities: 実施施設
- eligibility_criteria: 適格基準
- design_groups: 試験デザイン群
- sponsors: スポンサー情報

常に日本語で応答し、専門用語は適切に説明してください。")
  }
  
  paste(
    readLines(prompt_file, encoding = "UTF-8", warn = FALSE),
    collapse = "\n"
  )
}
