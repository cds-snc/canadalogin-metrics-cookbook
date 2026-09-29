# CanadaLogin Metrics Cookbook

The ***[CanadaLogin Metrics Cookbook](https://cds-snc.github.io/canadalogin-metrics-cookbook/)***
documents commonly used CanadaLogin metrics: their definitions, plain-language names, 
calculation logic, and example SQL and R queries. A companion data catalog describes 
the underlying tables field by field.

## Structure

The document is built using the [Quarto](https://quarto.org/) publishing system. Under
the hood, each Quarto document (.qmd) is just a Markdown file wearing a fancy hat.

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
`call_centre/`) is a folder with one page per metric or table, plus a sibling
source page (`ibm_verify.qmd`). Each metric or table page has a `title` and a
one-line `description` in its front matter; catalog titles are `schema.table`.
The source page holds what its metrics or tables share and lists them with a
Quarto listing. Each home page lists every metric or table.

## Adding a catalog table

1. Create `catalog/<schema>/<table>.qmd` with `title` and `description` front
   matter. Follow an existing table page for the body: intro, `Keywords`, then
   `## Provenance`, `## Fields`, and `## Notes`.
2. Add it to the `contents:` of the listing on the source page
   (`catalog/<schema>.qmd`).
3. Add it to the sidebar in `_quarto.yml`, under its source's section.

The site structure test fails if a rendered page is missing from the sidebar,
or if a sidebar entry points to a page that does not exist:

```bash
Rscript -e 'testthat::test_file("tests/test_site_structure.R", load_helpers = FALSE, stop_on_failure = TRUE)'
```

It runs on every pull request.

## Local preview

```bash
quarto preview
```

This starts a local server and opens the book in a browser. Changes to any `.qmd` file
trigger a live reload.

## Deployment

Pushing to `main` triggers a GitHub Actions workflow (`.github/workflows/deploy.yml`)
that renders the site and deploys it to GitHub Pages automatically. The workflow can also
be triggered manually from the Actions tab.

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

1. Create `cookbook/<source>/<metric>.qmd`, named after the metric, with
   `title` and `description` front matter.
2. Add it to the `contents:` of the right listing on the source page
   (`cookbook/<source>.qmd`).
3. Add it to the sidebar in `_quarto.yml`, under its source's section.

Follow an existing metric page for the body: a leading description,
`## Calculation` with the collapsed SQL/R example queries, then
`## Interpretation notes` and `## Alternative names`. The site structure test
above catches a page missing from the sidebar.

As long as the metric uses the standard `## SQL` / `## R` panel-tabset, the
parity test picks it up automatically - keep the SQL and R blocks paired in the
same order, and have each R block self-declare its source with
`tbl(con, in_schema(...))`.
