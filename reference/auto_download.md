# Download GAO Reports in One Step

Convenience wrapper that loads the bundled report links, optionally
filters by fiscal year, and downloads reports as PDF, HTML, or both. In
interactive sessions, prompts for format and year range when not
supplied.

## Usage

``` r
auto_download(
  format = NULL,
  year = NULL,
  download_dir = "gao_reports",
  sleep_time = 1,
  confirm = TRUE
)
```

## Arguments

- format:

  Character. `"pdf"`, `"html"`, or `"both"`. `NULL` (default) prompts
  interactively; in non-interactive sessions defaults to `"pdf"`.

- year:

  Integer vector of 4-digit fiscal years, e.g. `2024` or `2020:2024`.
  `NULL` (default) prompts interactively; in non-interactive sessions
  uses all available years.

- download_dir:

  Character. Base directory for downloads. `pdf/` and/or `html/`
  subdirectories are created beneath it.

- sleep_time:

  Numeric. Seconds to pause between downloads.

- confirm:

  Logical. If `TRUE` (default), prompts for confirmation before
  downloading. In non-interactive sessions, `confirm = TRUE` raises an
  error to prevent accidental mass downloads — set `confirm = FALSE`
  explicitly.

## Value

Invisible character vector of downloaded file paths.

## Details

PDF URLs are constructed directly from report IDs (e.g.,
`/products/gao-24-106198` becomes `/assets/gao-24-106198.pdf`) rather
than scraping each report page, so no extra HTTP requests are needed for
link extraction.

## Examples

``` r
if (FALSE) { # \dontrun{
# Interactive: walks through prompts
auto_download()

# Non-interactive: download 2024 PDFs
auto_download(format = "pdf", year = 2024, confirm = FALSE)
} # }
```
