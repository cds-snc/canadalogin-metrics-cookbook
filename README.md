# CanadaLogin Metrics Cookbook

A [Quarto book](https://quarto.org/docs/books/) documenting commonly used CanadaLogin 
metrics: their definitions, plain-language names, calculation logic, and example SQL 
and R queries. A companion data catalog describes the underlying tables field by field.

## Structure

```
_quarto.yml              # book config, chapter list, render settings
index.qmd                # introduction, conventions, scope

cookbook/                # Metrics Cookbook section
  ibm_verify.qmd         # IBM Verify chapter wrapper
  ibm_verify/            # one file per metric (included via {{< include >}})
  call_centre.qmd        # Call Centre chapter wrapper
  call_centre/           # one file per metric
  notes.qmd              # notes on metric interpretation

catalog/                 # Data Catalog section
  ibm_verify.qmd         # IBM Verify catalog wrapper
  ibm_verify/            # one file per table
  call_centre.qmd        # Call Centre catalog wrapper
  call_centre/           # one file per table
  index.qmd              # catalog introduction
```

Each metric file is a self-contained `.qmd` fragment starting at heading level `###`. 
The chapter wrapper assembles them with `{{< include >}}` and provides `##`-level 
section groupings.

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

Copy `.env.example` to `.env` and fill in the missing values. Then:

```bash
aws sso login --profile cl-data
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
