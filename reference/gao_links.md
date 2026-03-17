# Get Bundled GAO Report Data

Returns a data.frame of GAO report metadata bundled with the package.

## Usage

``` r
gao_links()
```

## Value

A data.frame with columns: url, title, report_id, published, released,
summary, and page_count (integer, may be `NA` for reports without a
matching PDF in the bundled archive).

## Examples

``` r
reports <- gao_links()
nrow(reports)
#> [1] 56263
head(reports)
#>                                   url title report_id published released
#> 1 https://www.gao.gov/products/087286  <NA>      <NA>      <NA>     <NA>
#> 2 https://www.gao.gov/products/087364  <NA>      <NA>      <NA>     <NA>
#> 3 https://www.gao.gov/products/087365  <NA>      <NA>      <NA>     <NA>
#> 4 https://www.gao.gov/products/087528  <NA>      <NA>      <NA>     <NA>
#> 5 https://www.gao.gov/products/087529  <NA>      <NA>      <NA>     <NA>
#> 6 https://www.gao.gov/products/087530  <NA>      <NA>      <NA>     <NA>
#>   summary page_count
#> 1    <NA>          2
#> 2    <NA>         NA
#> 3    <NA>         NA
#> 4    <NA>        399
#> 5    <NA>        179
#> 6    <NA>        315
```
