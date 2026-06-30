# inspect.R
#
# Connects to Athena, discovers every table in the data catalog, and writes two
# artifacts per run into subfolders of this directory (gitignored apart from
# this script):
#
#   glimpse/<timestamp>-glimpse.txt  human-readable glimpse of each table
#   schema/<timestamp>-schema.csv    schema, table, column, type per row, for
#                                     diffing schema drift between runs
#
# Run from this directory: `Rscript inspect.R`. Paths below are relative to
# inspect/, one level under the project root.

suppressPackageStartupMessages({
  library(DBI)
  library(RAthena)
  library(dplyr)
  library(dbplyr)
  library(purrr)
})

# Configuration --------------------------------------------------------------

# Load AWS / Athena settings from the gitignored .env at the project root (one
# level up from this script).
env_file <- file.path("..", ".env")
if (file.exists(env_file)) dotenv::load_dot_env(env_file)

athena_profile     <- Sys.getenv("AWS_PROFILE")
athena_region      <- Sys.getenv("AWS_REGION")
athena_staging_dir <- Sys.getenv("ATHENA_S3_STAGING_DIR")

missing_settings <- c(
  AWS_PROFILE           = athena_profile,
  AWS_REGION            = athena_region,
  ATHENA_S3_STAGING_DIR = athena_staging_dir
)
missing_settings <- names(missing_settings[missing_settings == ""])
if (length(missing_settings) > 0) {
  stop(
    "Missing required setting(s): ", paste(missing_settings, collapse = ", "),
    ". Set them in a .env file at the project root or export them in the shell."
  )
}

glimpse_dir <- "glimpse"
schema_dir  <- "schema"
sample_rows <- 100

dir.create(glimpse_dir, showWarnings = FALSE)
dir.create(schema_dir, showWarnings = FALSE)

# A filesystem-safe, lexically-sortable timestamp, no colons: 2026-06-30T134354
timestamp    <- format(Sys.time(), "%Y-%m-%dT%H%M%S")
glimpse_file <- file.path(glimpse_dir, paste0(timestamp, "-glimpse.txt"))
schema_file  <- file.path(schema_dir, paste0(timestamp, "-schema.csv"))

# Show more of each column's sample values than the default 80-column width.
options(width = 200)

# Connection -----------------------------------------------------------------

con <- dbConnect(
  RAthena::athena(),
  profile_name   = athena_profile,
  region_name    = athena_region,
  s3_staging_dir = athena_staging_dir
)

# Glimpse one table ----------------------------------------------------------

# Writes a delimited block for one table: a header, total/column counts, and a
# dplyr::glimpse() of a small sample. Wrapped in tryCatch so one unreadable
# table does not abort the whole run.
glimpse_table <- function(schema, table) {
  qualified <- paste0(schema, ".", table)
  cat("\n", strrep("=", 80), "\n", sep = "")
  cat("TABLE: ", qualified, "\n", sep = "")
  cat(strrep("=", 80), "\n", sep = "")

  tryCatch(
    {
      source_tbl <- tbl(con, in_schema(schema, table))

      total_rows <- source_tbl |>
        summarise(n = n()) |>
        pull(n)

      sample <- source_tbl |>
        head(sample_rows) |>
        collect()

      cat("Total rows:   ", format(total_rows, big.mark = ","), "\n", sep = "")
      cat("Columns:      ", ncol(sample), "\n", sep = "")
      cat("Sample below: up to ", sample_rows, " rows\n\n", sep = "")
      glimpse(sample)
      cat("\n")
    },
    error = function(e) {
      cat("ERROR reading table: ", conditionMessage(e), "\n", sep = "")
    }
  )

  invisible(NULL)
}

# Read one table's schema ----------------------------------------------------

# Returns a data frame of column/type rows from information_schema, read
# straight from the catalog metadata rather than by sampling the table, and
# reporting precise SQL types.
table_schema <- function(schema, table) {
  query <- paste0(
    "SELECT column_name, data_type FROM information_schema.columns ",
    "WHERE table_schema = '", schema, "' AND table_name = '", table, "'"
  )
  tryCatch(
    {
      cols <- dbGetQuery(con, query)
      if (nrow(cols) == 0) return(NULL)
      data.frame(
        schema = schema,
        table  = table,
        column = cols$column_name,
        type   = cols$data_type,
        stringsAsFactors = FALSE
      )
    },
    error = function(e) {
      message("Could not read schema for ", schema, ".", table, ": ",
              conditionMessage(e))
      NULL
    }
  )
}

# Discover and glimpse every table -------------------------------------------

tables <- RAthena::dbGetTables(con) |>
  filter(TableType == "BASE TABLE") |>
  arrange(Schema, TableName)

# Schema manifest: accumulate every table's columns, then sort deterministically
# (schema, table, column) so the file diffs cleanly between runs.
schema_rows <- map2(tables$Schema, tables$TableName, table_schema) |>
  list_rbind()
schema_rows <- schema_rows[order(schema_rows$schema,
                                 schema_rows$table,
                                 schema_rows$column), ]
write.csv(schema_rows, schema_file, row.names = FALSE)

# Sink only stdout to the file; RAthena's "Data scanned" notes go to the
# message stream (the console), keeping the file itself clean.
sink(glimpse_file)

cat("Athena data catalog glimpse\n")
cat("Generated: ",
    format(Sys.time(), tz = "America/Toronto", usetz = TRUE), "\n", sep = "")
cat("Tables found: ", nrow(tables), "\n", sep = "")

for (i in seq_len(nrow(tables))) {
  glimpse_table(tables$Schema[i], tables$TableName[i])
}

sink()

cat("Wrote glimpse of", nrow(tables), "tables to", glimpse_file, "\n")
cat("Wrote schema manifest to", schema_file, "\n")

# Compare schema against the previous run ------------------------------------

# Snapshots sort lexically by their timestamped names, so the last is the run
# we just wrote and the second-to-last is the previous one.
schema_snapshots <- sort(list.files(schema_dir, pattern = "-schema\\.csv$",
                                    full.names = TRUE))
if (length(schema_snapshots) >= 2) {
  previous <- schema_snapshots[length(schema_snapshots) - 1]
  current  <- schema_snapshots[length(schema_snapshots)]
  cat("\nSchema changes since previous snapshot (", basename(previous), "):\n",
      sep = "")
  diff_out <- system2("diff", c(shQuote(previous), shQuote(current)),
                      stdout = TRUE, stderr = TRUE)
  if (length(diff_out) == 0) {
    cat("  (no schema changes)\n")
  } else {
    cat(diff_out, sep = "\n")
    cat("\n")
  }
} else {
  cat("\nNo previous snapshot to compare against; this is the first one.\n")
}
