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
if (FALSE) { # \dontrun{
download_pdfs("/assets/gao-24-106198.pdf", download_dir = tempdir())
} # }
```
