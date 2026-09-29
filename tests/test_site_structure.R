# tests/test_site_structure.R
#
# Checks that the sidebar in _quarto.yml and the pages on disk agree. The
# sidebar is an explicit list, so a new page that is not added to it renders
# but cannot be reached by navigation. Needs no Athena connection.
#
# Run from the project root. `load_helpers = FALSE` stops testthat sourcing
# tests/helper.R, which loads the Athena packages the parity tests need.
#
#   Rscript -e 'testthat::test_file("tests/test_site_structure.R", load_helpers = FALSE, stop_on_failure = TRUE)'

library(testthat)
library(yaml)

# Helpers --------------------------------------------------------------------

# testthat may run this file from tests/, so walk up to the project root.
find_root <- function(dir = getwd()) {
  while (!file.exists(file.path(dir, "_quarto.yml"))) {
    parent <- dirname(dir)
    if (parent == dir) stop("_quarto.yml not found above ", getwd())
    dir <- parent
  }
  dir
}

# Every href in the sidebar, at any nesting depth. Entries are either a bare
# path string or a list with `href` and/or nested `contents`.
sidebar_hrefs <- function(entries) {
  unlist(lapply(entries, function(entry) {
    if (is.character(entry)) return(entry)
    c(entry$href, sidebar_hrefs(entry$contents))
  }))
}

# The pages Quarto renders, resolved from the project `render:` list. Negated
# entries are either a folder (trailing slash) or a single file.
rendered_pages <- function(root, render) {
  excludes <- sub("^!", "", render[startsWith(render, "!")])
  includes <- render[!startsWith(render, "!")]
  pages <- unique(unlist(lapply(includes, function(pattern) {
    sub(paste0("^", root, "/"), "", Sys.glob(file.path(root, pattern)))
  })))
  excluded <- vapply(pages, function(page) {
    any(ifelse(endsWith(excludes, "/"), startsWith(page, excludes), page == excludes))
  }, logical(1))
  sort(pages[!excluded])
}

front_matter <- function(path) {
  lines <- readLines(path, warn = FALSE)
  if (length(lines) == 0 || lines[[1]] != "---") return(list())
  end <- which(lines[-1] == "---")[[1]] + 1L
  yaml.load(paste(lines[2:(end - 1L)], collapse = "\n")) %||% list()
}

# Fixtures -------------------------------------------------------------------

root <- find_root()
config <- read_yaml(file.path(root, "_quarto.yml"))
hrefs <- sidebar_hrefs(config$website$sidebar$contents)
pages <- rendered_pages(root, config$project$render)
drafts <- pages[vapply(
  file.path(root, pages),
  function(path) isTRUE(front_matter(path)$draft),
  logical(1)
)]
table_pages <- grep("^catalog/[^/]+/", pages, value = TRUE)

# Tests ----------------------------------------------------------------------

test_that("the render list resolves to some pages", {
  expect_gt(length(pages), 0)
  expect_gt(length(table_pages), 0)
})

test_that("every rendered page is in the sidebar", {
  expect_equal(setdiff(setdiff(pages, drafts), hrefs), character(0))
})

test_that("every sidebar entry points to a file that exists", {
  expect_equal(hrefs[!file.exists(file.path(root, hrefs))], character(0))
})

test_that("every sidebar entry points to a page that renders", {
  expect_equal(setdiff(hrefs, pages), character(0))
})

test_that("no page appears in the sidebar twice", {
  expect_equal(hrefs[duplicated(hrefs)], character(0))
})

test_that("draft pages are kept out of the sidebar", {
  expect_equal(intersect(drafts, hrefs), character(0))
})

test_that("every catalog table page has a title for listings", {
  missing <- table_pages[!vapply(
    file.path(root, table_pages),
    function(path) nzchar(front_matter(path)$title %||% ""),
    logical(1)
  )]
  expect_equal(missing, character(0))
})

test_that("every catalog table page has a description for listings", {
  missing <- table_pages[!vapply(
    file.path(root, table_pages),
    function(path) nzchar(front_matter(path)$description %||% ""),
    logical(1)
  )]
  expect_equal(missing, character(0))
})
