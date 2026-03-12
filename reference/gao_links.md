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
length(links)
#> [1] 56117
head(links)
#> [1] "https://www.gao.gov/products/087286" "https://www.gao.gov/products/087364"
#> [3] "https://www.gao.gov/products/087365" "https://www.gao.gov/products/087528"
#> [5] "https://www.gao.gov/products/087529" "https://www.gao.gov/products/087530"
```
