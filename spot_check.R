d <- readRDS("inst/extdata/gao_links.rds")
cat("Columns:", paste(names(d), collapse=", "), "\n")
cat("Total rows:", nrow(d), "\n\n")

d <- d[order(d$published, decreasing=TRUE), ]

top10 <- head(d, 10)
for (i in 1:nrow(top10)) {
  cat("--- Report", i, "---\n")
  cat("url:", top10$url[i], "\n")
  cat("title:", top10$title[i], "\n")
  cat("report_id:", top10$report_id[i], "\n")
  cat("published:", top10$published[i], "\n")
  cat("released:", top10$released[i], "\n")
  s <- as.character(top10$summary[i])
  cat("summary:", if (is.na(s)) "NA" else substr(s, 1, 150), "\n")
  cat("topics:", as.character(top10$topics[i]), "\n")
  st <- as.character(top10$subject_terms[i])
  cat("subject_terms:", if (is.na(st)) "NA" else substr(st, 1, 150), "\n")
  cat("has_recommendations:", top10$has_recommendations[i], "\n")
  cat("n_recommendations:", top10$n_recommendations[i], "\n")
  cat("has_matters:", top10$has_matters[i], "\n")
  cat("n_matters:", top10$n_matters[i], "\n")
  cat("agencies_affected:", as.character(top10$agencies_affected[i]), "\n")
  cat("page_count:", top10$page_count[i], "\n\n")
}
