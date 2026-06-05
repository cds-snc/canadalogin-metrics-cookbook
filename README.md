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

## Adding a metric

1. Create a new `.qmd` file in the appropriate `cookbook/<source>/` subfolder, named after the metric (for example, `cookbook/ibm_verify/new-metric.qmd`).
2. Start the file with a `###`-level heading.
3. Add an `{{< include >}}` line in the chapter wrapper (`cookbook/<source>.qmd`) at the appropriate position.

Follow the existing metric files for the content structure: leading description, 
alternative names, calculation, SQL/R tabset, and interpretation notes.
