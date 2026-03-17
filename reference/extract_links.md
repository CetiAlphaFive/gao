# Extract GAO Report Links

Scrapes report links and metadata from the GAO reports and testimonies
listing pages.

## Usage

``` r
extract_links(
  base_url = "https://www.gao.gov/reports-testimonies",
  last_page = NULL,
  verbose = TRUE,
  save_to_file = FALSE,
  sleep_time = 1,
  output_file = "gao_report_links.rds",
  cache_dir = NULL
)
```

## Arguments

- base_url:

  Character. The base URL for GAO reports (default:
  `"https://www.gao.gov/reports-testimonies"`).

- last_page:

  Integer. Last page number to scrape. If `NULL`, detected automatically
  from the pagination.

- verbose:

  Logical. If `TRUE`, shows a progress bar (default: `TRUE`).

- save_to_file:

  Logical. If `TRUE`, saves data to an RDS file (default: `FALSE`).

- sleep_time:

  Numeric. Seconds to pause between page requests.

- output_file:

  Character. File path for the output.

- cache_dir:

  Character or `NULL`. Directory to cache raw HTML listing pages. If
  `NULL` (default), pages are fetched into memory only. If set, pages
  are saved as `page_0.html`, `page_1.html`, etc., and
  already-downloaded pages are skipped.

## Value

A data.frame with columns: url, title, report_id, published, released,
summary.

## Details

When `cache_dir` is set, raw HTML pages are saved to disk and
already-downloaded pages are skipped on subsequent runs. This makes
large scrapes resumable.

## Examples

``` r
if (FALSE) { # \dontrun{
links <- extract_links(last_page = 5)

# Resumable: caches HTML to disk
links <- extract_links(cache_dir = "data-raw/gao_pages")
} # }
```
