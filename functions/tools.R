# Access to session_storage from tools.R
get_session_storage <- function() {
  session_storage
}

# Executes R code in the current session
#
# @param code R code to execute
# @returns The results of the evaluation
# @noRd
run_r_code <- function(code) {
  # Try hard to suppress ANSI terminal formatting characters
  withr::local_envvar(NO_COLOR = 1)
  withr::local_options(rlib_interactive = FALSE, rlang_interactive = FALSE)

  if (in_shiny()) {
    session <- shiny::getDefaultReactiveDomain()
    session_id <- session$token
    
    # Make session data available in global environment for R code execution
    session_storage <- get_session_storage()
    if (exists(session_id, envir = session_storage)) {
      session_data <- session_storage[[session_id]]
      if (!is.null(session_data$uploaded_data)) {
        assign(session_data$data_name, session_data$uploaded_data, envir = .GlobalEnv)
      }
    }
    
    out <- MarkdownStreamer$new(function(md_text) {
      save_output_chunk_for_session(session_id, md_text)
      shinychat::chat_append_message(
        "chat",
        list(role = "assistant", content = md_text),
        chunk = TRUE,
        operation = "append"
      )
    })
  } else {
    out <- NullStreamer$new()
  }
  on.exit(out$close(), add = TRUE, after = FALSE)

  # What gets returned to the LLM
  result <- list()

  out_img <- function(media_type, b64data) {
    result <<- c(
      result,
      list(list(
        type = "image",
        source = list(
          type = "base64",
          media_type = media_type,
          data = b64data
        )
      ))
    )
    out$md(
      sprintf("![Plot](data:%s;base64,%s)\n\n", media_type, b64data),
      TRUE,
      FALSE
    )
  }

  out_df <- function(df) {
    ROWS_START <- 20
    ROWS_END <- 10

    # For the model
    df_json <- encode_df_for_model(
      df,
      max_rows = ROWS_START,
      show_end = ROWS_END
    )
    result <<- c(result, list(list(type = "text", text = df_json)))
    # For human
    # Make sure human sees same EXACT rows as model, this includes omitting the same rows
    split <- split_df(nrow(df), show_start = ROWS_START, show_end = ROWS_END)
    attrs <- "class=\"data-frame table table-sm table-striped\""
    md_tbl <- paste0(
      collapse = "\n",
      knitr::kable(head(df, split$head), format = "html", table.attr = attrs)
    )
    if (split$skip > 0) {
      md_tbl_skip <- sprintf("... %d rows omitted ...", split$skip)
      md_tbl_tail <- knitr::kable(
        tail(df, split$tail),
        format = "html",
        table.attr = attrs
      )
      md_tbl <- as_str(md_tbl, md_tbl_skip, md_tbl_tail)
    }
    out$md(md_tbl, TRUE, TRUE)
  }

  out_txt <- function(txt, end = NULL) {
    txt <- paste(txt, collapse = "\n")
    if (txt == "") {
      return()
    }
    if (!is.null(end)) {
      txt <- paste0(txt, end)
    }
    result <<- c(result, list(list(type = "text", text = txt)))
    out$code(txt)
  }

  out$code(code)
  # End the source code block so the outputs all appear in a separate block
  out$close()

  # Use the new evaluate_r_code function
  if (in_shiny()) {
    shiny::withLogErrors({
      evaluate_r_code(
        code,
        on_console_out = out_txt,
        on_console_err = out_txt,
        on_plot = out_img,
        on_dataframe = out_df
      )
    })
  } else {
    evaluate_r_code(
      code,
      on_console_out = out_txt,
      on_console_err = out_txt,
      on_plot = out_img,
      on_dataframe = out_df
    )
  }

  result <- coalesce_text_outputs(result)

  I(result)
}

in_shiny <- function() {
  !is.null(shiny::getDefaultReactiveDomain())
}

# Combine consecutive text outputs into one, for better readability (for both us
# and the model).
coalesce_text_outputs <- function(content_list) {
  txt_buffer <- character(0)
  result_content_list <- list()

  flush_buffer <- function() {
    if (length(txt_buffer) > 0) {
      result_content_list <<- c(
        result_content_list,
        list(list(type = "text", text = paste(txt_buffer, collapse = "\n")))
      )
      txt_buffer <<- character(0)
    }
  }

  for (content in content_list) {
    if (content[["type"]] == "text") {
      if (nzchar(content[["text"]])) {
        txt_buffer <- c(txt_buffer, content[["text"]])
      }
    } else {
      flush_buffer()
      result_content_list <- c(result_content_list, list(content))
    }
  }
  if (length(txt_buffer) > 0) {
    flush_buffer()
  }

  result_content_list
}
