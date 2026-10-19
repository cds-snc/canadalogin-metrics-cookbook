# CanadaLogin Metrics Cookbook

The ***[CanadaLogin Metrics Cookbook](https://cds-snc.github.io/canadalogin-metrics-cookbook/)***
documents commonly used CanadaLogin metrics: their definitions, plain-language names,
calculation logic, and example SQL and R queries. A companion data catalog describes
the underlying tables field by field.

## Structure

The site is built with [Quarto](https://quarto.org/). Under the hood, each
Quarto document (.qmd) is just a Markdown file wearing a fancy hat.

```text
_quarto.yml      # website config: sidebar, render list, and theme
index.qmd        # site introduction linking the two halves
cookbook/        # Metrics Cookbook: one file per metric, grouped by source
catalog/         # Data Catalog: one file per table, grouped by source
custom.scss      # theme overrides
```

## Adding a page

1. Create `cookbook/<source>/<metric>.qmd` or `catalog/<schema>/<table>.qmd`
   with `title` and `description` front matter. A metric page has leading prose,
   `## Calculation` with the collapsed SQL and R example queries,
   `## Interpretation notes`, and `## Alternative names`. A catalog page has an
   intro, `Keywords`, `## Provenance`, `## Fields`, and `## Notes`; start from
   `catalog/data-catalog-template.qmd`.
2. Add it to the listing `contents:` on its source page.
3. Add it to the sidebar in `_quarto.yml`, under its source's section.
4. Run the structure test. It fails if a rendered page is missing from the
   sidebar, a sidebar entry points nowhere, or a page lacks a `title` or
   `description`. It also runs on every pull request.

```bash
Rscript -e 'testthat::test_file("tests/test_site_structure.R", load_helpers = FALSE, stop_on_failure = TRUE)'
```

## Deployment

Pushing to `main` runs `.github/workflows/deploy.yml`, which renders the site
and deploys it to GitHub Pages. It can also be run by hand from the Actions tab.
