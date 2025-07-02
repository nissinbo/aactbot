chat_bot <- function(system_prompt = NULL, default_turns = list()) {
  system_prompt <- system_prompt %||% aactbot_prompt()

  api_key <- Sys.getenv("GEMINI_API_KEY", Sys.getenv("AACTBOT_API_KEY", ""))
  if (api_key == "") {
    abort(paste(
      "No Gemini API key found;",
      "please set GEMINI_API_KEY or AACTBOT_API_KEY env var"
    ))
  }

  chat <- ellmer::chat_google_gemini(
    system_prompt,
    model = "gemini-2.5-flash",
    echo = FALSE,
    api_key = api_key
  )
  
  chat$set_turns(default_turns)
  
  chat$register_tool(ellmer::tool(
    run_r_code,
    "Executes R code in the current session",
    code = ellmer::type_string("R code to execute")
  ))
  
  chat$register_tool(ellmer::tool(
    run_aact_query,
    "Executes SQL query against the AACT database",
    query = ellmer::type_string("SQL query to execute against AACT PostgreSQL database")
  ))
  
  chat
}
