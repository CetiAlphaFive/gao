# Update GAO Report Links

Scrapes the most recent GAO report listing pages and appends any new
links not already in the bundled dataset. Stops automatically when it
reaches reports that are already known (3 consecutive pages with no new
links) or after 3 consecutive fetch failures.

## Usage

``` r
update_links(verbose = TRUE, sleep_time = 1)
```

## Arguments

- verbose:

  Logical. Show progress messages (default: `TRUE`).

- sleep_time:

  Numeric. Seconds between requests (default: 1).

## Value

A character vector of all known report URLs (old + new), sorted.

## Examples

``` r
# \donttest{
all_links <- update_links()
#> Warning: No bundled link data found. Run extract_links() to build it.
#> Bundled links: 0
#> Failed page 0: curl-impersonate not found on your system.
#> GAO.gov requires browser-like TLS fingerprints.
#> Install curl-impersonate: https://github.com/lexiforest/curl-impersonate
#>   Arch Linux: pacman -S curl-impersonate
#>   macOS: brew install lexiforest/curl-impersonate/curl-impersonate
#> Set a different binary with: options(gao.curl_bin = "curl_chrome145")
#> Failed page 1: curl-impersonate not found on your system.
#> GAO.gov requires browser-like TLS fingerprints.
#> Install curl-impersonate: https://github.com/lexiforest/curl-impersonate
#>   Arch Linux: pacman -S curl-impersonate
#>   macOS: brew install lexiforest/curl-impersonate/curl-impersonate
#> Set a different binary with: options(gao.curl_bin = "curl_chrome145")
#> Failed page 2: curl-impersonate not found on your system.
#> GAO.gov requires browser-like TLS fingerprints.
#> Install curl-impersonate: https://github.com/lexiforest/curl-impersonate
#>   Arch Linux: pacman -S curl-impersonate
#>   macOS: brew install lexiforest/curl-impersonate/curl-impersonate
#> Set a different binary with: options(gao.curl_bin = "curl_chrome145")
#> Stopping: 3 consecutive fetch failures
#> New links found: 0
# }
```
