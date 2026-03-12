# Get Bundled GAO Report Data

Returns a data.frame of GAO report metadata bundled with the package.

## Usage

``` r
gao_links()
```

## Value

A data.frame with columns: url, title, report_id, published, released,
summary.

## Examples

``` r
reports <- gao_links()
nrow(reports)
#> [1] 56117
head(reports)
#>                                   url title report_id published released
#> 1 https://www.gao.gov/products/087286  <NA>      <NA>      <NA>     <NA>
#> 2 https://www.gao.gov/products/087364  <NA>      <NA>      <NA>     <NA>
#> 3 https://www.gao.gov/products/087365  <NA>      <NA>      <NA>     <NA>
#> 4 https://www.gao.gov/products/087528  <NA>      <NA>      <NA>     <NA>
#> 5 https://www.gao.gov/products/087529  <NA>      <NA>      <NA>     <NA>
#> 6 https://www.gao.gov/products/087530  <NA>      <NA>      <NA>     <NA>
#>   summary
#> 1    <NA>
#> 2    <NA>
#> 3    <NA>
#> 4    <NA>
#> 5    <NA>
#> 6    <NA>
```
