# tests/helper.R
#
# Shared connection factory and comparison helpers for the parity tests.
# Source this at the top of the runner; do not run it directly.
#
# Configuration comes from a .env file at the project root (see .env.example).
# Required variables:
#   AWS_PROFILE            AWS named profile (AWS SSO) for the connection
#   AWS_REGION             AWS region, e.g. ca-central-1
#   ATHENA_S3_STAGING_DIR  S3 path Athena writes results to
#
# Authenticate first with: aws sso login --profile <AWS_PROFILE>

suppressPackageStartupMessages({
  library(testthat)
  library(DBI)
  library(RAthena)
  library(dplyr)
  library(dbplyr)
  library(stringr)
  library(dotenv)
})

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

if (file.exists(".env")) load_dot_env(".env")

# ---------------------------------------------------------------------------
# Connection
# ---------------------------------------------------------------------------

connect_athena <- function() {
  dbConnect(
    RAthena::athena(),
    profile_name   = Sys.getenv("AWS_PROFILE"),
    region_name    = Sys.getenv("AWS_REGION", "ca-central-1"),
    s3_staging_dir = Sys.getenv("ATHENA_S3_STAGING_DIR")
  )
}

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# Execute a SQL string against con and return a tibble.
run_sql <- function(con, sql) {
  dbGetQuery(con, sql) |> as_tibble()
}

# Normalise a data frame for comparison:
#   - coerce all numeric columns to double (avoids integer vs double mismatches)
#   - sort columns alphabetically
#   - sort rows by all columns (makes row order irrelevant)
normalize <- function(df) {
  out <- df |>
    ungroup() |>
    as_tibble() |>
    mutate(across(where(\(x) is.numeric(x) || inherits(x, "integer64")), as.double)) |>
    select(sort(names(df))) |>
    arrange(across(everything()))
  # RAthena returns data.table-backed frames; strip the externalptr reference so
  # waldo::compare doesn't trip on mismatched attribute list lengths.
  attr(out, ".internal.selfref") <- NULL
  out
}

# Assert that a SQL result and an R result are equal.
#
# The documented R is occasionally not a literal mirror of the SQL: a block may
# end in pull(), which returns an atomic vector rather than a one-column frame.
# In that case compare the vector against the single SQL column. Otherwise
# compare as normalised data frames (row and column order irrelevant).
check_results_equal <- function(sql_result, r_result) {
  if (!is.data.frame(r_result)) {
    expect_equal(ncol(sql_result), 1L, label = "SQL columns (vs scalar R result)")
    expect_equal(
      sort(as.double(r_result)),
      sort(as.double(sql_result[[1]])),
      tolerance = 1e-9,
      ignore_attr = TRUE
    )
    return(invisible())
  }

  s <- normalize(sql_result)
  r <- normalize(r_result)
  expect_equal(nrow(s), nrow(r), label = "row count")
  expect_equal(names(s), names(r), label = "column names")
  expect_equal(s, r, tolerance = 1e-9, ignore_attr = TRUE)
}
