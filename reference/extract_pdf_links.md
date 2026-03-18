# Extract PDF Links from GAO Report Pages

**\[deprecated\]**

`extract_pdf_links()` is deprecated. Use
[`auto_download()`](https://cetialphafive.github.io/gao/reference/auto_download.md)
instead, which constructs PDF URLs directly from report IDs without
extra HTTP requests.

## Usage

``` r
extract_pdf_links(page_links, sleep_time = 1)
```

## Arguments

- page_links:

  Character vector. Full URLs of GAO report pages.

- sleep_time:

  Numeric. Seconds to pause between requests (default: 1).

## Value

A character vector of unique PDF paths (relative to gao.gov).

## Examples

``` r
if (FALSE) { # \dontrun{
# Deprecated --- use auto_download() instead
auto_download(format = "pdf", year = 2024, confirm = FALSE)
} # }
```
