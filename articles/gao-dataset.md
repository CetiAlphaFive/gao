# The GAO report dataset

The heart of the `gao` package is a dataset covering every product the
U.S. Government Accountability Office has published since 1921 —
reports, testimonies, correspondence, and legal decisions. This article
walks through what is in it and how to work with it.

## Loading the data

The dataset ships with the package, so this works offline:

``` r

library(gao)

reports <- gao_links()
dim(reports)
#> [1] 56422   113
```

One row per GAO product. Here is a recent slice:

``` r

subset(reports, pub_fiscal_year == 2025,
       select = c(report_id, published, title)) |>
  head(3)
#>       report_id  published                                title
#> 16111    d27128 2024-10-29 Professional Standards Update No. 94
#> 16113    e11084 2025-01-30 Professional Standards Update No. 95
#> 16114    e11677 2025-04-28 Professional Standards Update No. 96
```

## The columns, in three groups

### 1. Core metadata

What GAO publishes about each report: `title`, `summary`, `published`
and `released` dates, `page_count`, `topics`, `subject_terms`, the
`agencies_affected`, how many recommendations it makes
(`n_recommendations`), and who asked for it (`requester_type`,
`requester_committees`, `requester_members`).

``` r

one <- subset(reports, report_id == "GAO-24-105891")
one$title
#> [1] "Public Health Preparedness: Building and Maintaining Infrastructure beyond the COVID-19 Pandemic"
one$topics
#> [1] "Health Care"
one$agencies_affected
#> [1] ""
one$n_recommendations
#> [1] 0
```

### 2. Indicator columns

Fields like `topics` pack several values into one semicolon-separated
string, which is awkward to filter on. So the dataset also includes
ready-made 0/1 indicator columns: 31 `topic_*` columns and 50 `agency_*`
columns (plus `agency_other`) for the most frequently reviewed agencies.

``` r

# Defense-related reports affecting the Department of Veterans Affairs
subset(reports,
       topic_national_defense == 1 &
         agency_department_of_veterans_affairs == 1,
       select = c(report_id, published, title)) |>
  head(3)
#>        report_id  published
#> 21729 GAO-05-632 2005-07-14
#> 27087 GAO-12-676 2012-08-28
#> 27314 GAO-12-919 2012-09-20
#>                                                                                                                                                                    title
#> 21729 Defense Health Care: Improvements Needed in Occupational and Environmental Health Surveillance During Deployments to Address Immediate and Long-Term Health Issues
#> 27087                                                                      Military Disability System: Improved Monitoring Needed to Better Track and Manage Performance
#> 27314                                                                      Strategic Sourcing: Improved and Expanded Use Could Save Billions in Annual Procurement Costs
```

Indicators are `NA` (not 0) when the underlying field is missing, which
is common for older reports.

### 3. Derived covariates

Columns computed from the metadata that are handy for analysis:

- `product_type` — what kind of product this is:

``` r

table(reports$product_type)
#> 
#> correspondence legal_decision    legal_other         report      testimony 
#>           4268           6566            551          38650           6386
```

- `pub_fiscal_year`, `fiscal_quarter`, `pub_month`, `pub_dow`,
  `election_year`, `release_lag_days` — timing covariates (federal
  fiscal years start in October).
- `issuing_division` — the GAO unit that produced the report, decoded
  from older report IDs.
- `n_topics`, `n_subject_terms` — how broad the report is.
- `requester_party`, `requester_chamber`, `requester_majority_status`,
  `requester_bipartisan` — who in Congress requested the report,
  resolved against [Voteview](https://voteview.com/) membership data.
  These are only populated for reports that name individual members as
  requesters:

``` r

table(reports$requester_party)
#> 
#>     D mixed Other     R 
#>  2465   230     3   688
```

## A quick look at the whole library

``` r

counts <- table(reports$pub_fiscal_year)
plot(as.integer(names(counts)), as.integer(counts), type = "h",
     xlab = "Fiscal year", ylab = "Reports published",
     main = "GAO products per fiscal year, 1922-present")
```

![](gao-dataset_files/figure-html/reports-per-year-1.png)

## A note on missing values

GAO’s own pages are sparser for older material, so expect more `NA`s as
you go back in time: summaries, topics, and requester fields are richest
from the 1970s onward, and page counts exist only where a PDF is
available. Always check [`is.na()`](https://rdrr.io/r/base/NA.html)
before filtering on these columns.

## Getting the newest data

The dataset is refreshed daily. To pick up the latest version without
reinstalling the package:

``` r

gao_update_data()
```

This caches the new dataset locally, and
[`gao_links()`](https://cetialphafive.github.io/gao/reference/gao_links.md)
uses it automatically from then on.
