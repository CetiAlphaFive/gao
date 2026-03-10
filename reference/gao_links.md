# Get Bundled GAO Report Links

Returns the character vector of GAO report URLs bundled with the
package.

## Usage

``` r
gao_links()
```

## Value

A character vector of GAO report URLs.

## Examples

``` r
links <- gao_links()
#> Warning: No bundled link data found. Run extract_links() to build it.
length(links)
#> [1] 0
head(links)
#> character(0)
```
