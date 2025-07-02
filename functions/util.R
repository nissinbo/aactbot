as_str <- function(..., collapse = "\n", sep = "") {
  # Collapse each character vector in ..., then concatenate
  lst <- list2(...)
  strings <- vapply(lst, paste, character(1), collapse = collapse)
  paste(strings, collapse = sep)
}

rule <- function(...) {
  text <- paste0(..., collapse = "")
  width <- getOption("width") - nchar(text) - 3
  paste0("- ", text, " ", strrep("-", width))
}

# Helper function for null-coalescing
`%||%` <- function(a, b) {
  if (is.null(a)) b else a
}

# Import rlang functions
list2 <- rlang::list2
abort <- rlang::abort
