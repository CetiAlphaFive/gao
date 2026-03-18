# Download Updated GAO Report Data

Downloads the latest `gao_links.rds` from the package's GitHub Releases
and caches it locally. Subsequent calls to
[`gao_links()`](https://cetialphafive.github.io/gao/reference/gao_links.md)
will use the updated data. Uses base R
[`download.file()`](https://rdrr.io/r/utils/download.file.html) — no
`curl-impersonate` needed.

## Usage

``` r
gao_update_data(quiet = FALSE)
```

## Arguments

- quiet:

  Logical. Suppress progress messages (default: `FALSE`).

## Value

Invisible path to the cached RDS file.

## Examples

``` r
if (FALSE) { # \dontrun{
gao_update_data()
gao_links()  # now returns the latest data
} # }
```
