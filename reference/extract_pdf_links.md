# Extract PDF Links from GAO Report Pages

Visits each report page and extracts the PDF download link(s). Highlight
PDFs are excluded automatically.

## Usage

``` r
extract_pdf_links(page_links, sleep_time = 1)
```

## Arguments

- page_links:

  Character vector. Full URLs of GAO report pages (e.g.,
  `"https://www.gao.gov/products/gao-24-106198"`).

- sleep_time:

  Numeric. Seconds to pause between requests (default: 1).

## Value

A character vector of unique PDF paths (relative to gao.gov).

## Examples

``` r
if (FALSE) { # \dontrun{
pdf_links <- extract_pdf_links("https://www.gao.gov/products/gao-24-106198")
} # }
```
