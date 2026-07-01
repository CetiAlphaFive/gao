# One-time: string-clean requester fields in the shipped RDS in place.
# Run manually: Rscript data-raw/clean_requester_fields.R
# Idempotent — safe to re-run.
suppressMessages(devtools::load_all("."))

path <- "inst/extdata/gao_links.rds"
d <- readRDS(path)

before.c <- d$requester_committees
before.m <- d$requester_members
d$requester_committees <- gao:::.clean_requester_string(d$requester_committees)
d$requester_members    <- gao:::.clean_requester_string(d$requester_members)

cat("committee changes:",
    sum(before.c != d$requester_committees, na.rm = TRUE), "\n")
cat("member changes:",
    sum(before.m != d$requester_members, na.rm = TRUE), "\n")

saveRDS(d, path, compress = "xz")
cat("Rewrote", path, "\n")
