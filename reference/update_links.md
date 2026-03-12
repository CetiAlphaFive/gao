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

A data.frame of all known reports (old + new), sorted by url.

## Examples

``` r
if (FALSE) { # \dontrun{
all_data <- update_links()
} # }
```
