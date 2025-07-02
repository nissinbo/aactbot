# Global settings and dependencies for AACT Bot Shiny Application
# ================================================================

# Suppress ANSI formatting
Sys.setenv(NO_COLOR = "1")

# Required libraries
library(tidyverse)
library(shiny)
library(bslib)
library(shinyjs)
library(htmltools)
library(ellmer)
library(shinychat)
library(DBI)
library(RPostgreSQL)
library(fastmap)
library(R6)
library(jsonlite)
library(knitr)
library(base64enc)
library(evaluate)
library(promises)
library(coro)
library(whisker)
library(withr)
library(utils)
library(rlang)

# Source all utility functions
source("functions/util.R", local = TRUE)
source("functions/prompt.R", local = TRUE)
source("functions/mdstreamer.R", local = TRUE)
source("functions/functions.R", local = TRUE)
source("functions/tools.R", local = TRUE)
source("functions/chat_bot.R", local = TRUE)

# Session-specific storage
session_storage <- new.env(parent = emptyenv())

# Global storage
globals <- new.env(parent = emptyenv())

# Helper functions for session management
reset_session_state <- function(session_id) {
  # Disconnect any existing AACT connection
  if (exists(session_id, envir = session_storage) &&
    !is.null(session_storage[[session_id]]$aact_connection)) {
    try(DBI::dbDisconnect(session_storage[[session_id]]$aact_connection), silent = TRUE)
  }

  session_storage[[session_id]] <- list(
    turns = NULL,
    ui_messages = fastmap::fastqueue(),
    pending_output = fastmap::fastqueue(),
    aact_connection = NULL,
    connection_status = FALSE
  )
  invisible()
}

save_messages_for_session <- function(session_id, ...) {
  for (msg in list(...)) {
    session_storage[[session_id]]$ui_messages$add(msg)
  }
  invisible()
}

save_output_chunk_for_session <- function(session_id, chunk) {
  session_storage[[session_id]]$pending_output$add(chunk)
  invisible()
}

take_pending_output <- function(session_id) {
  chunks <- unlist(session_storage[[session_id]]$pending_output$as_list())
  session_storage[[session_id]]$pending_output$reset()
  paste(collapse = "", chunks)
}

# Stream decorator that saves each chunk to session-specific pending_output
save_stream_output <- function(session_id) {
  coro::async_generator(function(stream) {
    session <- getDefaultReactiveDomain()
    for (chunk in coro::await_each(stream)) {
      if (session$isClosed()) {
        req(FALSE)
      }
      save_output_chunk_for_session(session_id, chunk)
      coro::yield(chunk)
    }
  })
}

last_chat <- function(session_id = NULL) {
  if (is.null(session_id)) {
    # For backward compatibility
    return(NULL)
  }
  session_storage[[session_id]]$last_chat
}

# CSS for styling
app_css <- "
.data-frame {
  max-height: 400px;
  overflow-y: auto;
  margin-bottom: 1rem;
}

#connection_status {
  border-radius: 4px;
}

.alert {
  padding: 0.75rem 1.25rem;
  margin-bottom: 1rem;
  border: 1px solid transparent;
  border-radius: 0.25rem;
}

.alert-success {
  color: #155724;
  background-color: #d4edda;
  border-color: #c3e6cb;
}

.alert-danger {
  color: #721c24;
  background-color: #f8d7da;
  border-color: #f5c6cb;
}
"
