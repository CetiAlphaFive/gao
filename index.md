# A Complete Library of GAO Reports and Metadata

`gao` provides tools for downloading reports and associated metadata
published by the United States Government Accountability Office (GAO).
It ships with a bundled dataset covering over 55,000 reports
(1921–present, updated daily) and a one-step function for batch
downloading reports as PDF, HTML, or both.

**Disclaimer:** This package is not affiliated with, endorsed by, or in
any way officially connected to the U.S. Government Accountability
Office. All data is obtained from public web pages at
[gao.gov](https://www.gao.gov). \## Installation

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

[`auto_download()`](https://cetialphafive.github.io/gao/reference/auto_download.md)
loads the bundled dataset, filters by fiscal year, and downloads PDFs,
HTMLs, or both into `gao_reports/pdf/` and `gao_reports/html/`.

The package has three main functions:

- **[`gao_links()`](https://cetialphafive.github.io/gao/reference/gao_links.md)**
  — access the bundled dataset (56,000+ reports with metadata and
  one-hot indicator columns)
- **[`auto_download()`](https://cetialphafive.github.io/gao/reference/auto_download.md)**
  — download reports as PDF, HTML, or both (or export metadata as CSV)
- **[`extract_text()`](https://cetialphafive.github.io/gao/reference/extract_text.md)**
  — extract text from downloaded PDFs via `pdftools`
