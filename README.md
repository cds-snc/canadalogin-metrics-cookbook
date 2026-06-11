# CanadaLogin Metrics Cookbook

A [Quarto website](https://quarto.org/docs/websites/) documenting commonly used
CanadaLogin metrics: their definitions, plain-language names, calculation logic, and
example SQL and R queries. A companion data catalog describes the underlying tables
field by field.

## Structure

```
_quarto.yml      # website config: sidebar, render list, and theme
index.qmd        # book-level introduction linking the two chapters
cookbook/        # Metrics Cookbook: one file per metric, grouped by source
catalog/         # Data Catalog: one file per table, grouped by source
custom.scss      # theme overrides (bold nav/TOC entries, wider TOC column)
```

The Metrics Cookbook and Data Catalog have parallel layouts: each opens with an
`index.qmd` "About" page, then one page per data source, then an "Additional Notes"
page (`notes.qmd`).

Within `cookbook/` and `catalog/`, each data source (for example `ibm_verify/`,
`call_centre/`) is a folder of fragment `.qmd` files plus a sibling chapter
wrapper (`ibm_verify.qmd`) that assembles them with `{{< include >}}`. The
fragment folders are include-only and are excluded from rendering via the
`render:` list in `_quarto.yml`.

## Local preview

```bash
quarto preview
```

This starts a local server and opens the book in a browser. Changes to any `.qmd` file
trigger a live reload.

## Deployment

The `_book/` directory is a self-contained static site. To publish to GitHub Pages using
the Quarto CLI:

```bash
quarto publish gh-pages
```

This renders the book and pushes the output to the `gh-pages` branch of the repository.

## Testing

`tests/run_parity_tests.R` parses the SQL and R blocks straight out of every
metric `.qmd` file, runs both against Athena, and asserts they return the same
result.

Create a `.env` file at the project root (it is gitignored) with the Athena
connection settings the tests read via `tests/helper.R`:

```bash
AWS_PROFILE=your-aws-sso-profile
AWS_REGION=ca-central-1
ATHENA_S3_STAGING_DIR=s3://your-bucket/athena-results/
```

Then authenticate and run the tests:

```bash
aws sso login --profile "$AWS_PROFILE"
Rscript tests/run_parity_tests.R
```

The script uses the `RAthena` package for the Athena connection. Install the R
dependencies if needed:

```r
install.packages(c("testthat", "DBI", "RAthena", "dplyr", "dbplyr", "stringr", "dotenv"))
```

## Adding a metric

1. Create a new `.qmd` file in the appropriate `cookbook/<source>/` subfolder, named after the metric (for example, `cookbook/ibm_verify/new-metric.qmd`).
2. Start the file with a `###`-level heading.
3. Add an `{{< include >}}` line in the chapter wrapper (`cookbook/<source>.qmd`) at the appropriate position.

Follow the existing metric files for the content structure: leading description, 
alternative names, calculation, SQL/R tabset, and interpretation notes.

As long as the metric uses the standard `## SQL` / `## R` panel-tabset, the
parity test picks it up automatically - keep the SQL and R blocks paired in the
same order, and have each R block self-declare its source with
`tbl(con, in_schema(...))`.
