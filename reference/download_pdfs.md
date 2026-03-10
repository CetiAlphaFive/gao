# Download GAO PDF Reports

Downloads PDF files from extracted PDF links.

## Usage

``` r
download_pdfs(pdf_links, download_dir = getwd(), sleep_time = 1)
```

## Arguments

- pdf_links:

  Character vector. PDF paths as returned by
  [`extract_pdf_links()`](https://cetialphafive.github.io/gao/reference/extract_pdf_links.md)
  (relative paths like `"/assets/gao-24-106198.pdf"` or full URLs).

- download_dir:

  Character. Directory to save PDFs (default: working directory).

- sleep_time:

  Numeric. Seconds to pause between downloads (default: 1).

## Value

Invisible character vector of downloaded file paths.

## Examples

``` r
# \donttest{
download_pdfs("/assets/gao-24-106198.pdf", download_dir = tempdir())
#> Failed: gao-24-106198.pdf - curl-impersonate not found on your system.
#> GAO.gov requires browser-like TLS fingerprints.
#> Install curl-impersonate: https://github.com/lexiforest/curl-impersonate
#>   Arch Linux: pacman -S curl-impersonate
#>   macOS: brew install lexiforest/curl-impersonate/curl-impersonate
#> Set a different binary with: options(gao.curl_bin = "curl_chrome145")
# }
```
