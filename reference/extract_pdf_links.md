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
# \donttest{
pdf_links <- extract_pdf_links("https://www.gao.gov/products/gao-24-106198")
#> Failed: https://www.gao.gov/products/gao-24-106198 - curl-impersonate not found on your system.
#> GAO.gov requires browser-like TLS fingerprints.
#> Install curl-impersonate: https://github.com/lexiforest/curl-impersonate
#>   Arch Linux: pacman -S curl-impersonate
#>   macOS: brew install lexiforest/curl-impersonate/curl-impersonate
#> Set a different binary with: options(gao.curl_bin = "curl_chrome145")
# }
```
