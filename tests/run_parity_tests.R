# tests/run_parity_tests.R
#
# Parses the SQL and R blocks out of every cookbook metric .qmd file, runs both
# against Athena, and asserts they return the same result. The docs are the
# single source of truth - new metric files are picked up automatically.
#
# Run from the project root. Connection settings are read from a .env file at the
# project root by tests/helper.R (AWS_PROFILE, AWS_REGION, ATHENA_S3_STAGING_DIR).
# Authenticate first, then run:
#
#   aws sso login --profile "$AWS_PROFILE"
#   Rscript tests/run_parity_tests.R
#
# Exits non-zero if any pair fails to run or the results disagree.

source("tests/helper.R")
source("tests/extract_blocks.R")

# Directories whose .qmd files contain documented metric queries.
cookbook_dirs <- c("cookbook/ibm_verify", "cookbook/call_centre")

# Evaluate a documented R block. The block self-declares its source table via
# tbl(con, in_schema(...)). Blocks that end in pull() return a vector; blocks
# that don't explicitly collect() return a lazy tbl, which we collect here so
# the comparator always sees a data frame or vector.
eval_r_block <- function(r_code, con) {
  env <- new.env(parent = globalenv())
  env$con <- con
  result <- eval(parse(text = r_code), envir = env)

  # Make sure we collect the query at the end
  if (inherits(result, "tbl_lazy")) {
    collect(result)
  } else {
    result
  }
}

con <- connect_athena()
on.exit(dbDisconnect(con), add = TRUE)

files <- list.files(cookbook_dirs, pattern = "[.]qmd$", full.names = TRUE)
files <- sort(files)

message(sprintf("Discovered %d metric files:", length(files)))
for (f in files) message("  ", f)
message("")

all_ok <- TRUE
n_pairs <- 0L

for (path in files) {
  pairs <- extract_pairs(path)
  for (pair in pairs) {
    n_pairs <- n_pairs + 1L
    ok <- test_that(pair$label, {
      sql_result <- run_sql(con, pair$sql)
      r_result <- eval_r_block(pair$r, con)
      check_results_equal(sql_result, r_result)
    })
    all_ok <- all_ok && isTRUE(ok)
  }
}

message(
  sprintf("\nRan %d query pair(s) across %d file(s).",
    n_pairs,
    length(files)
  )
)

if (!all_ok) {
  message("FAIL: at least one query pair did not match.")
  quit(status = 1L)
}
message("PASS: all query pairs match.")
