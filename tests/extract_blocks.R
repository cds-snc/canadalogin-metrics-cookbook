# tests/extract_blocks.R
#
# Parses a cookbook metric .qmd file and returns its SQL/R query pairs.
#
# Each metric page documents one or more calculations inside a
# `::: {.panel-tabset}`, with a `## SQL` section followed by a `## R` section.
# SQL and R blocks pair by order (1st SQL <-> 1st R, ...). Files with more than
# one pair separate them with identical prose sub-labels in both sections
# (for example "By week:" then "Total over a period:").
#
# This parser keys off the ```sql / ```r fences and the `## SQL` / `## R`
# headings only, so it is independent of Quarto rendering.

# Collect fenced code blocks of a given language from a slice of lines.
# Returns a list of list(body, label), where label is the most recent non-blank
# prose line above the opening fence (empty string when there is none).
collect_blocks <- function(lines, lang) {
  open_fence <- paste0("```", lang)
  blocks <- list()
  i <- 1L
  last_prose <- ""

  while (i <= length(lines)) {
    line <- lines[[i]]
    trimmed <- trimws(line)

    if (trimmed == open_fence) {
      # Consume the body up to the closing fence.
      body <- character(0)
      i <- i + 1L
      while (i <= length(lines) && trimws(lines[[i]]) != "```") {
        body <- c(body, lines[[i]])
        i <- i + 1L
      }
      blocks[[length(blocks) + 1L]] <- list(
        body = paste(body, collapse = "\n"),
        label = last_prose
      )
      last_prose <- ""  # reset; the next block needs its own preceding label
      i <- i + 1L        # skip the closing fence
      next
    }

    # Track the most recent non-blank, non-fence prose line as a candidate label.
    if (nzchar(trimmed) && !startsWith(trimmed, "```") && !startsWith(trimmed, ":::")) {
      last_prose <- trimmed
    }
    i <- i + 1L
  }

  blocks
}

# Find the line index of a heading like "## SQL" (exact, after trimming).
# Returns NA when absent.
find_heading <- function(lines, heading) {
  idx <- which(trimws(lines) == heading)
  if (length(idx) == 0) NA_integer_ else idx[[1]]
}

# Extract the SQL/R query pairs from one .qmd file.
# Returns a list of list(label, sql, r). Stops with an error if the SQL and R
# block counts differ - that is a real authoring mistake the tests should catch.
extract_pairs <- function(path) {
  lines <- readLines(path, warn = FALSE)
  file_label <- tools::file_path_sans_ext(basename(path))

  sql_idx <- find_heading(lines, "## SQL")
  r_idx   <- find_heading(lines, "## R")

  if (is.na(sql_idx) || is.na(r_idx)) {
    stop(sprintf("%s: missing '## SQL' or '## R' heading", file_label))
  }

  # SQL section runs from the SQL heading to the R heading; R section from the
  # R heading to the closing ::: of the panel-tabset (or end of file).
  sql_lines <- lines[(sql_idx + 1L):(r_idx - 1L)]
  close_rel <- which(trimws(lines[(r_idx + 1L):length(lines)]) == ":::")
  r_end <- if (length(close_rel) > 0) r_idx + close_rel[[1]] else length(lines)
  r_lines <- lines[(r_idx + 1L):r_end]

  sql_blocks <- collect_blocks(sql_lines, "sql")
  r_blocks   <- collect_blocks(r_lines, "r")

  if (length(sql_blocks) != length(r_blocks)) {
    stop(sprintf(
      "%s: %d SQL block(s) but %d R block(s) - blocks must pair one-to-one",
      file_label, length(sql_blocks), length(r_blocks)
    ))
  }
  if (length(sql_blocks) == 0) {
    stop(sprintf("%s: no SQL/R blocks found", file_label))
  }

  pairs <- vector("list", length(sql_blocks))
  for (k in seq_along(sql_blocks)) {
    sublabel <- sql_blocks[[k]]$label
    label <- if (nzchar(sublabel)) {
      sprintf("%s [%s]", file_label, sub(":$", "", sublabel))
    } else {
      file_label
    }
    pairs[[k]] <- list(
      label = label,
      sql = sql_blocks[[k]]$body,
      r = r_blocks[[k]]$body
    )
  }
  pairs
}
