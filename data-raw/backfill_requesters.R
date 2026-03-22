# data-raw/backfill_requesters.R
# One-time backfill of requester columns from report HTMLs
#
# Adds: requester_type, requester_committees, requester_members
#
# Data sources (in priority order):
#   1. Report ID format (testimony, legal_decision, correspondence) — no I/O
#   2. HTML reports from files.gao.gov — subtitle + addressee block + mandate check
#   3. Report PDFs (fallback) — addressee block from PDF text
#
# Run phases independently — each is resumable/idempotent.
#
# ── Config ────────────────────────────────────────────────────────────────────
# Set these paths before running:

report.html.dir  <- NULL   # path to HTML reports from files.gao.gov/reports/[ID]/
report.pdf.dir   <- NULL   # path to downloaded report PDFs (fallback)

# ── Phase 0: Setup ───────────────────────────────────────────────────────────

devtools::load_all()

current <- readRDS("inst/extdata/gao_links.rds")
message("Total reports in dataset: ", nrow(current))

# Initialize new columns if missing
if (!"requester_type" %in% names(current)) current$requester_type <- NA_character_
if (!"requester_committees" %in% names(current)) current$requester_committees <- NA_character_
if (!"requester_members" %in% names(current)) current$requester_members <- NA_character_

# ── Phase 1: ID-based classification (instant, no I/O) ───────────────────────

message("\n=== Phase 1: ID-based classification ===")

id.types <- .classify_report_type(current$report_id)
n.classified <- sum(!is.na(id.types))
message("Classified by ID: ", n.classified, " reports")
message("  testimony: ", sum(id.types == "testimony", na.rm = TRUE))
message("  legal_decision: ", sum(id.types == "legal_decision", na.rm = TRUE))
message("  correspondence: ", sum(id.types == "correspondence", na.rm = TRUE))

# ID classification takes priority — overwrite any existing value
current$requester_type[!is.na(id.types)] <- id.types[!is.na(id.types)]

# ── Phase 2: Parse HTML reports (subtitle + addressee + mandate check) ───────

message("\n=== Phase 2: HTML report parsing ===")

if (is.null(report.html.dir) || !dir.exists(report.html.dir)) {
  message("HTML report directory not set or not found: ", report.html.dir)
  message("Skipping Phase 2. Set report.html.dir to the path containing")
  message("  HTML reports from files.gao.gov/reports/[ID]/index.html")
} else {
  html.files <- list.files(report.html.dir, pattern = "\\.html$", full.names = TRUE)
  html.files <- html.files[file.size(html.files) >= 200]
  message("HTML report files to parse: ", length(html.files))

  rh.parsed <- vector("list", length(html.files))

  for (i in seq_along(html.files)) {
    rh.parsed[[i]] <- tryCatch({
      page <- rvest::read_html(html.files[i])
      info <- .parse_report_html(page)
      slug <- sub("\\.html$", "", tolower(basename(html.files[i])))
      data.frame(
        slug = slug,
        rh_requester_type = info$requester_type,
        rh_requester_committees = info$requester_committees,
        rh_requester_members = info$requester_members,
        stringsAsFactors = FALSE
      )
    }, error = function(e) {
      NULL
    })
    if (i %% 5000 == 0) message("Parsed: ", i, "/", length(html.files))
  }

  rh.data <- do.call(rbind, rh.parsed[!vapply(rh.parsed, is.null, logical(1))])
  message("Successfully parsed: ", nrow(rh.data), " reports")
  message("  with requester_type: ", sum(!is.na(rh.data$rh_requester_type)))
  message("  with committees: ", sum(!is.na(rh.data$rh_requester_committees)))
  message("  with members: ", sum(!is.na(rh.data$rh_requester_members)))

  # Merge: HTML report data fills or overwrites
  current$slug <- tolower(basename(current$url))
  idx <- match(current$slug, rh.data$slug)
  matched <- !is.na(idx)
  message("Matched to dataset: ", sum(matched))

  # requester_type: fill where still NA (ID-based takes priority)
  needs.type <- matched & is.na(current$requester_type)
  current$requester_type[needs.type] <- rh.data$rh_requester_type[idx[needs.type]]

  # committees: HTML report data overwrites (richest source)
  has.comm <- matched & !is.na(rh.data$rh_requester_committees[idx])
  current$requester_committees[has.comm] <- rh.data$rh_requester_committees[idx[has.comm]]

  # members: HTML report data overwrites
  has.mem <- matched & !is.na(rh.data$rh_requester_members[idx])
  current$requester_members[has.mem] <- rh.data$rh_requester_members[idx[has.mem]]

  current$slug <- NULL
}

# ── Phase 3: Parse report PDFs (fallback for missing HTML) ───────────────────

message("\n=== Phase 3: PDF fallback parsing ===")

if (is.null(report.pdf.dir) || !dir.exists(report.pdf.dir)) {
  message("PDF directory not set or not found.")
  message("Skipping Phase 3. Set report.pdf.dir to enable PDF fallback parsing.")
} else {
  if (!requireNamespace("pdftools", quietly = TRUE)) {
    stop("pdftools package required. Install with: install.packages('pdftools')")
  }
  pdf.files <- list.files(report.pdf.dir, pattern = "\\.pdf$", full.names = TRUE)
  pdf.files <- pdf.files[file.size(pdf.files) >= 200]
  message("PDF files to parse: ", length(pdf.files))

  ab.parsed <- vector("list", length(pdf.files))

  for (i in seq_along(pdf.files)) {
    ab.parsed[[i]] <- tryCatch({
      pages <- pdftools::pdf_text(pdf.files[i])
      text <- paste(pages[seq_len(min(2, length(pages)))], collapse = "\n")
      info <- .parse_addressee_block(text)
      slug <- sub("\\.pdf$", "", tolower(basename(pdf.files[i])))
      data.frame(
        slug = slug,
        ab_requester_type = info$requester_type,
        ab_requester_committees = info$requester_committees,
        ab_requester_members = info$requester_members,
        stringsAsFactors = FALSE
      )
    }, error = function(e) {
      NULL
    })
    if (i %% 5000 == 0) message("Parsed: ", i, "/", length(pdf.files))
  }

  ab.data <- do.call(rbind, ab.parsed[!vapply(ab.parsed, is.null, logical(1))])
  message("Successfully parsed: ", nrow(ab.data), " reports")

  # Merge: only fill where still NA (HTML report data takes priority)
  current$slug <- tolower(basename(current$url))
  idx <- match(current$slug, ab.data$slug)
  matched <- !is.na(idx)

  needs.type <- matched & is.na(current$requester_type)
  current$requester_type[needs.type] <- ab.data$ab_requester_type[idx[needs.type]]

  needs.comm <- matched & is.na(current$requester_committees)
  current$requester_committees[needs.comm] <- ab.data$ab_requester_committees[idx[needs.comm]]

  needs.mem <- matched & is.na(current$requester_members)
  current$requester_members[needs.mem] <- ab.data$ab_requester_members[idx[needs.mem]]

  current$slug <- NULL
}

# ── Phase 4: Validate ────────────────────────────────────────────────────────

message("\n=== Validation ===")
message("requester_type distribution:")
type.table <- table(current$requester_type, useNA = "ifany")
print(type.table)
message("\nTotal with requester_type: ", sum(!is.na(current$requester_type)),
        " (", round(100 * mean(!is.na(current$requester_type)), 1), "%)")
message("Total with requester_committees: ", sum(!is.na(current$requester_committees)),
        " (", round(100 * mean(!is.na(current$requester_committees)), 1), "%)")
message("Total with requester_members: ", sum(!is.na(current$requester_members)),
        " (", round(100 * mean(!is.na(current$requester_members)), 1), "%)")

message("\nSpot-check (10 random reports with requester_type):")
set.seed(2024)
has.type <- which(!is.na(current$requester_type))
if (length(has.type) > 0) {
  sample.idx <- sample(has.type, min(10, length(has.type)))
  print(current[sample.idx, c("report_id", "requester_type",
                               "requester_committees", "requester_members")])
}

# ── Phase 5: Save ────────────────────────────────────────────────────────────

saveRDS(current, "inst/extdata/gao_links.rds", compress = "xz")
message("\nSaved updated dataset to inst/extdata/gao_links.rds")
message("Total rows: ", nrow(current))
