# data-raw/backfill_metadata.R
# One-time metadata backfill for ~53k GAO report pages
#
# Run phases independently:
#   Phase 1 (download): ~29 hours, fully resumable — interrupt/resume freely
#   Phase 2-4 (parse, merge, save): minutes
#
# Before Phase 1: pause Dropbox sync to avoid syncing 53k small HTML files

# ── Phase 0: Setup ──────────────────────────────────────────────────────────

devtools::load_all()

cache.dir <- "data-raw/gao_report_pages"
if (!dir.exists(cache.dir)) dir.create(cache.dir, recursive = TRUE)

current <- readRDS("inst/extdata/gao_links.rds")
message("Total reports: ", nrow(current))

needs.backfill <- is.na(current$title)
urls.todo <- current$url[needs.backfill]
message("Reports needing metadata: ", length(urls.todo))

# Slug from URL for cache filenames
slugs <- basename(urls.todo)

# ── Phase 1: Download ───────────────────────────────────────────────────────
# Skip files that already exist and are >= 200 bytes

message("Starting Phase 1: Download")
n.downloaded <- 0L
n.skipped <- 0L
n.failed <- 0L
failures <- character(0)

for (i in seq_along(urls.todo)) {
  dest <- file.path(cache.dir, paste0(slugs[i], ".html"))

  if (file.exists(dest) && file.size(dest) >= 200) {
    n.skipped <- n.skipped + 1L
    next
  }

  tryCatch({
    html.text <- .fetch_html_raw(urls.todo[i])
    writeLines(html.text, dest)
    n.downloaded <- n.downloaded + 1L
  }, error = function(e) {
    n.failed <<- n.failed + 1L
    failures <<- c(failures, urls.todo[i])
    message("Failed [", i, "]: ", urls.todo[i], " - ", e$message)
  })

  Sys.sleep(2)
  if (i %% 100 == 0) {
    message("Progress: ", i, "/", length(urls.todo),
            " (downloaded: ", n.downloaded,
            ", skipped: ", n.skipped,
            ", failed: ", n.failed, ")")
  }
}

message("Phase 1 complete: downloaded ", n.downloaded,
        ", skipped ", n.skipped, ", failed ", n.failed)
if (length(failures) > 0) {
  writeLines(failures, file.path(cache.dir, "failures.txt"))
  message("Failed URLs written to: ", file.path(cache.dir, "failures.txt"))
}

# ── Phase 2: Parse ──────────────────────────────────────────────────────────

message("Starting Phase 2: Parse")
html.files <- list.files(cache.dir, pattern = "\\.html$", full.names = TRUE)
html.files <- html.files[file.size(html.files) >= 200]
message("HTML files to parse: ", length(html.files))

parsed <- vector("list", length(html.files))
parse.failures <- character(0)

for (i in seq_along(html.files)) {
  parsed[[i]] <- tryCatch({
    page <- rvest::read_html(html.files[i])
    meta <- .scrape_report_metadata(page)
    # Attach URL by matching slug back to original URL
    slug <- sub("\\.html$", "", basename(html.files[i]))
    meta$url <- urls.todo[match(slug, slugs)]
    meta
  }, error = function(e) {
    parse.failures <<- c(parse.failures, html.files[i])
    NULL
  })
  if (i %% 5000 == 0) message("Parsed: ", i, "/", length(html.files))
}

backfill <- do.call(rbind, parsed[!vapply(parsed, is.null, logical(1))])
message("Successfully parsed: ", nrow(backfill), " reports")
if (length(parse.failures) > 0) {
  message("Parse failures: ", length(parse.failures))
}

# ── Phase 3: Merge ──────────────────────────────────────────────────────────

message("Starting Phase 3: Merge")

# Add new columns if missing
if (!"topics" %in% names(current)) current$topics <- NA_character_
if (!"subject_terms" %in% names(current)) current$subject_terms <- NA_character_

# Match backfill rows to current rows by URL
idx <- match(backfill$url, current$url)
matched <- !is.na(idx)
message("Matched URLs: ", sum(matched), " of ", nrow(backfill))

# Fields to backfill — only fill where current value is NA or empty
fields <- c("title", "report_id", "published", "released", "summary",
             "topics", "subject_terms")

for (field in fields) {
  needs.fill <- is.na(current[[field]][idx[matched]]) |
    current[[field]][idx[matched]] == ""
  current[[field]][idx[matched]][needs.fill] <- backfill[[field]][matched][needs.fill]
}

# ── Phase 4: Validate and save ──────────────────────────────────────────────

message("\n=== Validation ===")
message("NA counts per column:")
for (col in fields) {
  message("  ", col, ": ", sum(is.na(current[[col]])))
}

dates <- as.Date(current$published, format = "%Y-%m-%d")
message("\nPublished date range: ", min(dates, na.rm = TRUE), " to ",
        max(dates, na.rm = TRUE))

message("\nTopics populated: ", sum(!is.na(current$topics)))
message("Subject terms populated: ", sum(!is.na(current$subject_terms)))

message("\nSpot-check (10 random backfilled rows):")
set.seed(1995)
sample.idx <- sample(idx[matched], min(10, sum(matched)))
print(current[sample.idx, c("url", "title", "report_id", "published", "topics")])

saveRDS(current, "inst/extdata/gao_links.rds")
message("\nSaved updated dataset to inst/extdata/gao_links.rds")
message("Total rows: ", nrow(current))
