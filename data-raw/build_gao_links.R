## build_gao_links.R — scrape full GAO report link list
## Run once to build initial dataset, then GitHub Action keeps it current

library(gao)

links <- extract_links(
  save_to_file = FALSE,
  sleep_timer  = 1,
  verbose      = TRUE
)

# Save as plain text, one URL per line
dir.create("inst/extdata", recursive = TRUE, showWarnings = FALSE)
writeLines(sort(unique(links)), "inst/extdata/gao_links.csv")
message("Saved ", length(links), " links to inst/extdata/gao_links.csv")
