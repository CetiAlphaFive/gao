# Extract GAO Report Links

Scrapes report links from the GAO reports and testimonies listing pages.

## Usage

``` r
extract_links(
  base_url = "https://www.gao.gov/reports-testimonies",
  last_page = NULL,
  verbose = TRUE,
  save_to_file = FALSE,
  sleep_time = 1,
  output_file = "gao_report_links.txt"
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

  Logical. If `TRUE`, saves links to a text file (default: `FALSE`).

- sleep_time:

  Numeric. Seconds to pause between page requests.

- output_file:

  Character. File path for the output.

## Value

A character vector of full GAO report URLs.

## Examples

``` r
# \donttest{
links <- extract_links(last_page = 5)
#> Using manually specified last page: 5
#>   |                                                                              |                                                                      |   0%
#> 
#> Failed page 0: curl-impersonate not found on your system.
#> GAO.gov requires browser-like TLS fingerprints.
#> Install curl-impersonate: https://github.com/lexiforest/curl-impersonate
#>   Arch Linux: pacman -S curl-impersonate
#>   macOS: brew install lexiforest/curl-impersonate/curl-impersonate
#> Set a different binary with: options(gao.curl_bin = "curl_chrome145")
#>   |                                                                              |============                                                          |  17%
#> 
#> Failed page 1: curl-impersonate not found on your system.
#> GAO.gov requires browser-like TLS fingerprints.
#> Install curl-impersonate: https://github.com/lexiforest/curl-impersonate
#>   Arch Linux: pacman -S curl-impersonate
#>   macOS: brew install lexiforest/curl-impersonate/curl-impersonate
#> Set a different binary with: options(gao.curl_bin = "curl_chrome145")
#>   |                                                                              |=======================                                               |  33%
#> 
#> Failed page 2: curl-impersonate not found on your system.
#> GAO.gov requires browser-like TLS fingerprints.
#> Install curl-impersonate: https://github.com/lexiforest/curl-impersonate
#>   Arch Linux: pacman -S curl-impersonate
#>   macOS: brew install lexiforest/curl-impersonate/curl-impersonate
#> Set a different binary with: options(gao.curl_bin = "curl_chrome145")
#>   |                                                                              |===================================                                   |  50%
#> 
#> Failed page 3: curl-impersonate not found on your system.
#> GAO.gov requires browser-like TLS fingerprints.
#> Install curl-impersonate: https://github.com/lexiforest/curl-impersonate
#>   Arch Linux: pacman -S curl-impersonate
#>   macOS: brew install lexiforest/curl-impersonate/curl-impersonate
#> Set a different binary with: options(gao.curl_bin = "curl_chrome145")
#>   |                                                                              |===============================================                       |  67%
#> 
#> Failed page 4: curl-impersonate not found on your system.
#> GAO.gov requires browser-like TLS fingerprints.
#> Install curl-impersonate: https://github.com/lexiforest/curl-impersonate
#>   Arch Linux: pacman -S curl-impersonate
#>   macOS: brew install lexiforest/curl-impersonate/curl-impersonate
#> Set a different binary with: options(gao.curl_bin = "curl_chrome145")
#>   |                                                                              |==========================================================            |  83%
#> 
#> Failed page 5: curl-impersonate not found on your system.
#> GAO.gov requires browser-like TLS fingerprints.
#> Install curl-impersonate: https://github.com/lexiforest/curl-impersonate
#>   Arch Linux: pacman -S curl-impersonate
#>   macOS: brew install lexiforest/curl-impersonate/curl-impersonate
#> Set a different binary with: options(gao.curl_bin = "curl_chrome145")
#>   |                                                                              |======================================================================| 100%
#> Found 1 report links
# }
```
