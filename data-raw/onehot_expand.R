# Validate and save core-only gao_links.rds with xz compression
# Indicator columns are computed on the fly by gao_links()
# Run from package root: Rscript data-raw/onehot_expand.R

devtools::load_all()

rds.path <- "inst/extdata/gao_links.rds"
d <- readRDS(rds.path)
message("Loaded ", nrow(d), " rows, ", ncol(d), " columns")

# Expand indicators in memory for validation only
expanded <- .expand_indicators(d)
indicator.cols <- .indicator_colnames()
stopifnot(all(indicator.cols %in% names(expanded)))

# Column sums (excluding NA)
topic.sums <- colSums(expanded[, grep("^topic_", names(expanded)), drop = FALSE], na.rm = TRUE)
agency.sums <- colSums(expanded[, grep("^agency_", names(expanded)), drop = FALSE], na.rm = TRUE)
message("\n=== Topic column sums ===")
print(sort(topic.sums, decreasing = TRUE))
message("\n=== Agency column sums ===")
print(sort(agency.sums, decreasing = TRUE))

# Coverage checks
n.with.topic <- sum(rowSums(expanded[, grep("^topic_", names(expanded)), drop = FALSE],
                             na.rm = TRUE) > 0)
n.with.agency <- sum(rowSums(expanded[, grep("^agency_", names(expanded)), drop = FALSE],
                              na.rm = TRUE) > 0)
message("\nRows with any topic indicator: ", n.with.topic)
message("Rows with any agency indicator: ", n.with.agency)

# Save core columns only (indicators computed on the fly by gao_links())
core.cols <- c("url", "title", "report_id", "published", "released", "summary",
               "page_count", "topics", "subject_terms", "has_recommendations",
               "n_recommendations", "has_matters", "n_matters", "agencies_affected",
               "requester_type", "requester_committees", "requester_members")
d <- d[, intersect(core.cols, names(d)), drop = FALSE]
saveRDS(d, rds.path, compress = "xz")
message("\nSaved ", ncol(d), " core columns to ", rds.path,
        " (", round(file.size(rds.path) / 1e6, 2), " MB)")
