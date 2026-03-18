# Get Bundled GAO Report Data

Returns a data.frame of GAO report metadata bundled with the package.

## Usage

``` r
gao_links()
```

## Value

A data.frame with columns: url, title, report_id, published, released,
summary, page_count (integer, may be `NA` for reports without a matching
PDF in the bundled archive), topics, subject_terms, has_recommendations
(logical), n_recommendations (integer), has_matters (logical), n_matters
(integer), and agencies_affected (character, semicolon-separated).

## Examples

``` r
reports <- gao_links()
nrow(reports)
#> [1] 56270
head(reports)
#>                                   url
#> 1 https://www.gao.gov/products/087286
#> 2 https://www.gao.gov/products/087364
#> 3 https://www.gao.gov/products/087365
#> 4 https://www.gao.gov/products/087528
#> 5 https://www.gao.gov/products/087529
#> 6 https://www.gao.gov/products/087530
#>                                                                                                                                                                                  title
#> 1                                                                                                        Request for Exemption from Standard Authorization Process on Security Grounds
#> 2                                                                                                                                       Comments on TVA Treasurer Accounts and Records
#> 3 Request for Advance Decision as to Availability of Pending Appropriation for Credit of 5 Percent to Salary Accounts of Civilian Professors and Instructors at the U.S. Naval Academy
#> 4                                                                                                                                             Comptroller General's Annual Report 1965
#> 5                                                                                                                                             Comptroller General's Annual Report 1970
#> 6                                                                                                                                             Comptroller General's Annual Report 1966
#>   report_id  published   released
#> 1    087286 1944-11-13 1944-11-13
#> 2    087364 1942-09-21 1950-09-21
#> 3    087365 1936-06-08 1936-06-08
#> 4    087528 1966-01-10 1966-01-10
#> 5    087529 1971-01-21 1971-01-21
#> 6    087530 1967-01-10 1967-01-10
#>                                                                                                                                                    summary
#> 1   GAO commented on a Department of Defense (DOD) request for exemption from the standard way funds were advanced to its national defense project. DOD...
#> 2        GAO commented on the bonding of Tennessee Valley Authority (TVA) agent officers and its internal control procedures concerning the handling of...
#> 3  GAO commented on whether funds from the Navy's 1937 appropriations act were available to pay the salaries of civilian professors and instructors for...
#> 4 GAO reported on its activities for the fiscal year ended June 30, 1965. GAO highlighted its: (1) assistance to Congress; (2) audits of civil, defense...
#> 5 GAO reported on its activities for the fiscal year ended June 30, 1970. GAO highlighted its: (1) assistance to Congress; (2) audits of civil, defense...
#> 6 GAO reported on its activities for the fiscal year ended June 30, 1966. GAO highlighted its: (1) assistance to Congress; (2) audits of defense, civil...
#>   page_count topics subject_terms has_recommendations n_recommendations
#> 1          2   <NA>          <NA>               FALSE                 0
#> 2         NA   <NA>          <NA>               FALSE                 0
#> 3         NA   <NA>          <NA>               FALSE                 0
#> 4        399   <NA>          <NA>               FALSE                 0
#> 5        179   <NA>          <NA>               FALSE                 0
#> 6        315   <NA>          <NA>               FALSE                 0
#>   has_matters n_matters agencies_affected
#> 1       FALSE         0              <NA>
#> 2       FALSE         0              <NA>
#> 3       FALSE         0              <NA>
#> 4       FALSE         0              <NA>
#> 5       FALSE         0              <NA>
#> 6       FALSE         0              <NA>
```
