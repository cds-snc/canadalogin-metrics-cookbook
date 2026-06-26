# get-table-info.R
#
# Connects to Athena, discovers every table in the data catalog, and writes a
# glimpse of each (total row count, column count, every column name and type,
# and a sample of values) to a text file.


suppressPackageStartupMessages({
  library(DBI)
  library(RAthena)
  library(dplyr)
  library(dbplyr)
})

# Configuration --------------------------------------------------------------

# Load AWS / Athena settings from the gitignored .env at the project root (the
# same file the parity tests use). source()-ing this script does not otherwise
# pick up .env, so Sys.getenv() would return empty strings.
if (file.exists(".env")) dotenv::load_dot_env(".env")

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
    ". Set them in a .env file at the project root or export them in your shell."
  )
}

output_file <- "table-info.txt"
sample_rows <- 100

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

# Discover and glimpse every table -------------------------------------------

tables <- RAthena::dbGetTables(con) |>
  filter(TableType == "BASE TABLE") |>
  arrange(Schema, TableName)

# Sink only stdout to the file; RAthena's "Data scanned" notes go to the
# message stream (the console), keeping the file itself clean.
sink(output_file)

cat("Athena data catalog glimpse\n")
cat("Generated: ", format(Sys.time(), tz = "America/Toronto", usetz = TRUE), "\n", sep = "")
cat("Tables found: ", nrow(tables), "\n", sep = "")

for (i in seq_len(nrow(tables))) {
  glimpse_table(tables$Schema[i], tables$TableName[i])
}

sink()

cat("Wrote a glimpse of", nrow(tables), "tables to", output_file, "\n")
