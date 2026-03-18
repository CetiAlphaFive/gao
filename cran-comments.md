## R CMD check results

0 errors | 0 warnings | 2 notes

* New submission.
* URL `https://www.gao.gov` returns HTTP 403 from automated checks.
  GAO.gov uses TLS fingerprint filtering that blocks standard HTTP
  clients — this is the reason the package requires `curl-impersonate`
  as a system dependency for scraping. The bundled dataset and
  `gao_update_data()` function work without `curl-impersonate`.
* `checking for future file timestamps` — transient network/clock check.

## System dependency

This package requires 'curl-impersonate' (<https://github.com/lexiforest/curl-impersonate>)
for scraping GAO.gov and downloading reports. The bundled dataset
(`gao_links()`) and data updates from GitHub (`gao_update_data()`)
work without it. Installation instructions are in the README and
DESCRIPTION.

## Test environment

* local: Arch Linux (EndeavourOS), R 4.5.2
* GitHub Actions: ubuntu-latest, R release
