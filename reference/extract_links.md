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
  output_file = "gao_report_links.rds"
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

## Value

A data.frame with columns: url, title, report_id, published, released,
summary.

## Examples

``` r
if (FALSE) { # \dontrun{
links <- extract_links(last_page = 5)
} # }
```
