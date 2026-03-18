# One-hot expand topics and agencies in bundled gao_links.rds
# Run from package root: Rscript data-raw/onehot_expand.R

devtools::load_all()

rds.path <- "inst/extdata/gao_links.rds"
d <- readRDS(rds.path)
message("Loaded ", nrow(d), " rows, ", ncol(d), " columns")

d <- .expand_indicators(d)
message("Expanded to ", ncol(d), " columns")

# --- Validation ---
indicator.cols <- .indicator_colnames()
stopifnot(all(indicator.cols %in% names(d)))

# Column sums (excluding NA)
topic.sums <- colSums(d[, grep("^topic_", names(d)), drop = FALSE], na.rm = TRUE)
agency.sums <- colSums(d[, grep("^agency_", names(d)), drop = FALSE], na.rm = TRUE)
message("\n=== Topic column sums ===")
print(sort(topic.sums, decreasing = TRUE))
message("\n=== Agency column sums ===")
print(sort(agency.sums, decreasing = TRUE))

# Coverage checks
n.with.topic <- sum(rowSums(d[, grep("^topic_", names(d)), drop = FALSE],
                             na.rm = TRUE) > 0)
n.with.agency <- sum(rowSums(d[, grep("^agency_", names(d)), drop = FALSE],
                              na.rm = TRUE) > 0)
message("\nRows with any topic indicator: ", n.with.topic)
message("Rows with any agency indicator: ", n.with.agency)

# Save
saveRDS(d, rds.path)
message("\nSaved to ", rds.path)
