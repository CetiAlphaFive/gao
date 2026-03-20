d <- readRDS("inst/extdata/gao_links.rds")

# Check NA rates by year for key metadata fields
d$year <- as.integer(substr(d$published, 1, 4))
years <- sort(unique(d$year[!is.na(d$year) & d$year >= 2020]))

cat("Year | N | topics_NA% | subject_terms_NA% | agencies_NA% | recs_all_0% | summary_empty%\n")
cat(strrep("-", 90), "\n")

for (yr in years) {
  sub <- d[!is.na(d$year) & d$year == yr, ]
  n <- nrow(sub)
  topics_na <- round(100 * mean(is.na(sub$topics) | sub$topics == ""), 1)
  st_na <- round(100 * mean(is.na(sub$subject_terms) | sub$subject_terms == ""), 1)
  ag_na <- round(100 * mean(is.na(sub$agencies_affected) | sub$agencies_affected == ""), 1)
  recs_zero <- round(100 * mean(sub$n_recommendations == 0, na.rm=TRUE), 1)
  summ_empty <- round(100 * mean(is.na(sub$summary) | sub$summary == ""), 1)
  cat(sprintf("%4d | %5d | %5.1f%% | %5.1f%% | %5.1f%% | %5.1f%% | %5.1f%%\n",
              yr, n, topics_na, st_na, ag_na, recs_zero, summ_empty))
}
