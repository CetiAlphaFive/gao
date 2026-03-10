# Download GAO Report HTML Pages

Downloads HTML files from a list of GAO report URLs.

## Usage

``` r
download_htmls(links, target_directory = getwd(), sleep_time = 1)
```

## Arguments

- links:

  Character vector. Full URLs of GAO report pages.

- target_directory:

  Character. Directory to save HTML files (default: working directory).

- sleep_time:

  Numeric. Seconds to pause between downloads (default: 1).

## Value

Invisible character vector of downloaded file paths.

## Examples

``` r
# \donttest{
download_htmls("https://www.gao.gov/products/gao-24-106198",
               target_directory = tempdir())
#> Failed: gao-24-106198.html - curl-impersonate not found on your system.
#> GAO.gov requires browser-like TLS fingerprints.
#> Install curl-impersonate: https://github.com/lexiforest/curl-impersonate
#>   Arch Linux: pacman -S curl-impersonate
#>   macOS: brew install lexiforest/curl-impersonate/curl-impersonate
#> Set a different binary with: options(gao.curl_bin = "curl_chrome145")
# }
```
