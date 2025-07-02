# AACT Bot - Shiny Application
# ============================

# Load global settings and functions
source("global.R", local = FALSE)

# UI Definition
ui <- bslib::page_fillable(
  tags$head(
    tags$style(HTML(app_css))
  ),
  shinyjs::useShinyjs(),
  div(
    style = "padding: 10px; background-color: #f8f9fa; border-bottom: 1px solid #dee2e6; margin-bottom: 10px;",
    h4("AACT データベース接続", style = "margin-bottom: 15px; color: #495057;"),
    div(
      style = "display: flex; gap: 15px; flex-wrap: wrap; align-items: end;",
      div(
        style = "flex: 1; min-width: 200px;",
        textInput("aact_user", "ユーザー名", placeholder = "AACTユーザー名を入力")
      ),
      div(
        style = "flex: 1; min-width: 200px;",
        passwordInput("aact_password", "パスワード", placeholder = "AACTパスワードを入力")
      ),
      div(
        style = "flex: 0; min-width: 120px;",
        actionButton("connect_aact", "接続", class = "btn btn-primary", style = "width: 100%;")
      ),
      div(
        style = "flex: 0; min-width: 120px;",
        actionButton("disconnect_aact", "切断", class = "btn btn-secondary", style = "width: 100%;", disabled = TRUE)
      )
    ),
    div(
      id = "connection_status",
      style = "margin-top: 10px; padding: 8px; border-radius: 4px; display: none;",
      textOutput("connection_message")
    )
  ),
  shinychat::chat_ui("chat", fill = TRUE, height = "100%", width = "100%")
)

# Server Definition
server <- function(input, output, session) {
  session_id <- session$token
  
  # Initialize session-specific storage
  if (!exists(session_id, envir = session_storage)) {
    session_storage[[session_id]] <- list(
      turns = NULL,
      ui_messages = fastmap::fastqueue(),
      pending_output = fastmap::fastqueue(),
      aact_connection = NULL,
      connection_status = FALSE
    )
  }
  
  session_data <- session_storage[[session_id]]

  # Handle AACT database connection
  observeEvent(input$connect_aact, {
    req(input$aact_user, input$aact_password)
    
    tryCatch({
      # Disconnect any existing connection
      if (!is.null(session_storage[[session_id]]$aact_connection)) {
        DBI::dbDisconnect(session_storage[[session_id]]$aact_connection)
      }
      
      # Create new connection
      drv <- RPostgreSQL::PostgreSQL()
      con <- DBI::dbConnect(
        drv, 
        dbname = "aact",
        host = "aact-db.ctti-clinicaltrials.org", 
        port = 5432, 
        user = input$aact_user, 
        password = input$aact_password
      )
      
      # Test connection with a simple query
      test_result <- DBI::dbGetQuery(con, "SELECT 1 as test")
      
      # Store connection in session
      session_storage[[session_id]]$aact_connection <- con
      session_storage[[session_id]]$connection_status <- TRUE
      
      # Update UI
      shinyjs::enable("disconnect_aact")
      shinyjs::disable("connect_aact")
      shinyjs::show("connection_status")
      
      output$connection_message <- renderText({
        "AACT データベースに正常に接続されました"
      })
      
      # Style the status message as success
      shinyjs::runjs("
        $('#connection_status').removeClass('alert-danger').addClass('alert alert-success');
      ")
      
      showNotification("AACT データベースに接続しました", type = "message")
      
    }, error = function(e) {
      session_storage[[session_id]]$connection_status <- FALSE
      shinyjs::show("connection_status")
      
      output$connection_message <- renderText({
        paste("接続エラー:", e$message)
      })
      
      # Style the status message as error
      shinyjs::runjs("
        $('#connection_status').removeClass('alert-success').addClass('alert alert-danger');
      ")
      
      showNotification(paste("データベース接続に失敗しました:", e$message), type = "error")
    })
  })
  
  # Handle AACT database disconnection
  observeEvent(input$disconnect_aact, {
    tryCatch({
      if (!is.null(session_storage[[session_id]]$aact_connection)) {
        DBI::dbDisconnect(session_storage[[session_id]]$aact_connection)
        session_storage[[session_id]]$aact_connection <- NULL
        session_storage[[session_id]]$connection_status <- FALSE
        
        # Update UI
        shinyjs::enable("connect_aact")
        shinyjs::disable("disconnect_aact")
        shinyjs::hide("connection_status")
        
        showNotification("AACT データベースから切断しました", type = "message")
      }
    }, error = function(e) {
      showNotification(paste("切断エラー:", e$message), type = "error")
    })
  })

  restored_since_last_turn <- FALSE

  # Restore previous chat session for this specific session
  if (session_storage[[session_id]]$ui_messages$size() > 0) {
    ui_msgs <- session_storage[[session_id]]$ui_messages$as_list()
    if (identical(ui_msgs[[1]], list(role = "user", content = "Hello"))) {
      ui_msgs <- ui_msgs[-1]
    }
    for (msg in ui_msgs) {
      shinychat::chat_append_message("chat", msg, chunk = FALSE)
    }
    restored_since_last_turn <- TRUE
  }

  chat <- chat_bot(default_turns = session_storage[[session_id]]$turns)
  start_chat_request <- function(user_input) {
    # For local debugging
    if (interactive()) {
      session_storage[[session_id]]$last_chat <- chat
    }

    prefix <- if (restored_since_last_turn) {
      paste0(
        "(Continuing previous chat session. The R environment may have ",
        "changed since the last request/response.)\n\n"
      )
    } else {
      ""
    }
    restored_since_last_turn <<- FALSE

    # Add AACT connection context if available
    connection_context <- ""
    if (session_storage[[session_id]]$connection_status) {
      connection_context <- "AACT データベースに接続済みです。PostgreSQL データベースに対してSQL クエリを実行できます。\n\n"
    } else {
      connection_context <- "AACT データベースに接続していません。まず上部のフォームからユーザー名とパスワードを入力して接続してください。\n\n"
    }

    stream <- save_stream_output(session_id)(
      chat$stream_async(paste0(prefix, connection_context, user_input))
    )
    shinychat::chat_append("chat", stream) |>
      promises::then(
        ~ {
          if (session$isClosed()) {
            req(FALSE)
          }

          # After each successful turn, save everything for this session
          session_storage[[session_id]]$turns <- chat$get_turns()
          save_messages_for_session(
            session_id,
            list(role = "user", content = user_input),
            list(role = "assistant", content = take_pending_output(session_id))
          )
        }
      ) |>
      promises::finally(
        ~ {
          tokens <- chat$get_tokens()
          last_input <- tail(tokens[tokens$role == "user", "tokens_total"], 1)
          last_output <- tail(tokens[tokens$role == "assistant", "tokens_total"], 1)
          total_input <- sum(tokens[tokens$role == "user", "tokens_total"])
          total_output <- sum(tokens[tokens$role == "assistant", "tokens_total"])

          cat("\n")
          cat(rule("Turn ", nrow(tokens)), "\n", sep = "")
          cat("Input tokens:  ", last_input, "\n", sep = "")
          cat("Output tokens: ", last_output, "\n", sep = "")
          cat("Total input tokens:  ", total_input, "\n", sep = "")
          cat("Total output tokens: ", total_output, "\n", sep = "")
          cat("\n")
        }
      )
  }

  observeEvent(input$chat_user_input, {
    start_chat_request(input$chat_user_input)
  })

  # Kick start the chat session (unless we've restored a previous session)
  if (length(chat$get_turns()) == 0) {
    start_chat_request("Hello")
  }
  
  # Clean up database connection when session ends
  session$onSessionEnded(function() {
    if (exists(session_id, envir = session_storage) && 
        !is.null(session_storage[[session_id]]$aact_connection)) {
      try(DBI::dbDisconnect(session_storage[[session_id]]$aact_connection), silent = TRUE)
      session_storage[[session_id]]$aact_connection <- NULL
    }
  })
}

# Run the application
shinyApp(ui = ui, server = server)
