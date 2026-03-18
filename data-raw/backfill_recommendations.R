# data-raw/backfill_recommendations.R
# One-time backfill of recommendation/matter columns from cached HTML files
#
# Requires: cached HTML files in data-raw/gao_report_pages/ (from backfill_metadata.R)
# Adds: has_recommendations, n_recommendations, has_matters, n_matters, agencies_affected

devtools::load_all()

# ── Load current dataset ──────────────────────────────────────────────────────

current <- readRDS("inst/extdata/gao_links.rds")
message("Total reports in dataset: ", nrow(current))

# ── List cached HTML files ────────────────────────────────────────────────────

cache.dir <- "data-raw/gao_report_pages"
html.files <- list.files(cache.dir, pattern = "\\.html$", full.names = TRUE)
html.files <- html.files[file.size(html.files) >= 200]
message("HTML files to parse: ", length(html.files))

# Build slug-to-URL lookup from current dataset
url.slugs <- basename(current$url)
names(url.slugs) <- url.slugs

# ── Parse recommendation/matter data ─────────────────────────────────────────

parsed <- vector("list", length(html.files))

for (i in seq_along(html.files)) {
  parsed[[i]] <- tryCatch({
    page <- rvest::read_html(html.files[i])

    # Recommendations for Executive Action
    rec.section <- rvest::html_node(page, "section.view--recommendations--block-1")
    has.rec <- !is.na(rec.section)
    if (has.rec) {
      rec.cells <- rvest::html_nodes(rec.section, "td.views-field-field-recommendation")
      n.rec <- length(rec.cells)
      agency.nodes <- rvest::html_nodes(rec.section, "td.views-field-name")
      agencies <- unique(sort(trimws(rvest::html_text(agency.nodes))))
      agencies <- agencies[nzchar(agencies)]
      agencies.str <- if (length(agencies) > 0L) paste(agencies, collapse = "; ") else NA_character_
    } else {
      n.rec <- 0L
      agencies.str <- NA_character_
    }

    # Matter for Congressional Consideration
    matter.section <- rvest::html_node(page, "section.view--recommendations--block-3")
    has.mat <- !is.na(matter.section)
    if (has.mat) {
      matter.cells <- rvest::html_nodes(matter.section, "td.views-field-field-recommendation")
      n.mat <- length(matter.cells)
    } else {
      n.mat <- 0L
    }

    slug <- sub("\\.html$", "", basename(html.files[i]))
    data.frame(
      slug = slug,
      has_recommendations = has.rec,
      n_recommendations = as.integer(n.rec),
      has_matters = has.mat,
      n_matters = as.integer(n.mat),
      agencies_affected = agencies.str,
      stringsAsFactors = FALSE
    )
  }, error = function(e) {
    NULL
  })

  if (i %% 5000 == 0) message("Parsed: ", i, "/", length(html.files))
}

backfill <- do.call(rbind, parsed[!vapply(parsed, is.null, logical(1))])
message("Successfully parsed: ", nrow(backfill), " reports")

# ── Merge into current dataset ────────────────────────────────────────────────

# Match by slug (filename stem = URL basename)
current$slug <- basename(current$url)
idx <- match(current$slug, backfill$slug)
matched <- !is.na(idx)
message("Matched to dataset: ", sum(matched), " of ", nrow(backfill))

# Initialize new columns
current$has_recommendations <- FALSE
current$n_recommendations <- 0L
current$has_matters <- FALSE
current$n_matters <- 0L
current$agencies_affected <- NA_character_

# Fill matched rows
current$has_recommendations[matched] <- backfill$has_recommendations[idx[matched]]
current$n_recommendations[matched] <- backfill$n_recommendations[idx[matched]]
current$has_matters[matched] <- backfill$has_matters[idx[matched]]
current$n_matters[matched] <- backfill$n_matters[idx[matched]]
current$agencies_affected[matched] <- backfill$agencies_affected[idx[matched]]

# Drop slug helper column
current$slug <- NULL

# ── Validate ──────────────────────────────────────────────────────────────────

message("\n=== Validation ===")
message("has_recommendations: ", sum(current$has_recommendations), " TRUE / ",
        sum(!current$has_recommendations), " FALSE")
message("has_matters: ", sum(current$has_matters), " TRUE / ",
        sum(!current$has_matters), " FALSE")
message("Pct with recommendations: ",
        round(100 * mean(current$has_recommendations), 1), "%")
message("Pct with matters: ",
        round(100 * mean(current$has_matters), 1), "%")

message("\nTop agencies (by frequency):")
all.agencies <- unlist(strsplit(current$agencies_affected[!is.na(current$agencies_affected)], "; "))
print(head(sort(table(all.agencies), decreasing = TRUE), 10))

# ── Save ──────────────────────────────────────────────────────────────────────

saveRDS(current, "inst/extdata/gao_links.rds")
message("\nSaved updated dataset to inst/extdata/gao_links.rds")
message("Total rows: ", nrow(current))
