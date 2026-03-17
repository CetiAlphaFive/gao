
<!-- README.md is generated from README.Rmd. Please edit that file -->

# A Complete Library of GAO Reports and Metadata

<!-- badges: start -->

[![R-CMD-check](https://github.com/CetiAlphaFive/gao/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/CetiAlphaFive/gao/actions/workflows/R-CMD-check.yaml)
[![CRAN
status](https://www.r-pkg.org/badges/version/gao)](https://CRAN.R-project.org/package=gao)
[![Lifecycle:
experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
<!-- badges: end -->

`gao` provides tools for downloading reports published by the United
States Government Accountability Office (GAO). It ships with a bundled
dataset of over 55,000 report URLs (1921–present, updated daily via
GitHub Actions) and a one-step function for batch downloading reports as
PDF or HTML.

**Disclaimer:** This package is not affiliated with, endorsed by, or in
any way officially connected to the U.S. Government Accountability
Office. All data is obtained from public web pages at
[gao.gov](https://www.gao.gov).

## Installation

`gao` requires
[curl-impersonate](https://github.com/lexiforest/curl-impersonate) as a
system dependency (GAO.gov uses TLS fingerprint filtering that blocks
standard HTTP clients).

``` bash
# Arch Linux
sudo pacman -S curl-impersonate

# macOS
brew install lexiforest/curl-impersonate/curl-impersonate
```

Then install the package:

``` r
# From CRAN (when available)
install.packages("gao")

# Development version from GitHub
# install.packages("pak")
pak::pak("CetiAlphaFive/gao")
```

## Quick start

``` r
library(gao)

# Interactive --- prompts for format and year range
auto_download()

# Or specify everything up front
auto_download(format = "pdf", year = 2020:2024, confirm = FALSE)
```

`auto_download()` loads the bundled dataset, filters by fiscal year, and
downloads PDFs, HTMLs, or both into `gao_reports/pdf/` and
`gao_reports/html/`. That’s it.

## Advanced usage

The functions below give you finer control over each step. Most users
won’t need them.

### Browse the bundled dataset

``` r
links <- gao_links()
length(links)
head(links)
```

### Update the link list

Fetch any reports published since the last package update:

``` r
all_links <- update_links()
```

### Extract PDF download links

``` r
pdf_links <- extract_pdf_links(links[1:10])
```

### Download reports

Download as PDFs:

``` r
download_pdfs(pdf_links, download_dir = "gao_pdfs")
```

Or download report pages as HTML:

``` r
download_htmls(links[1:10], target_directory = "gao_htmls")
```

### Full pipeline from scratch

Re-scrape the entire report listing (not usually necessary):

``` r
links <- extract_links(save_to_file = FALSE)
```

## License

MIT
