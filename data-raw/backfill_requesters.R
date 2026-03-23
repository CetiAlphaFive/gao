# data-raw/backfill_requesters.R
# One-time backfill of requester columns from local cache
#
# Adds: requester_type, requester_committees, requester_members
#
# Data sources (in priority order):
#   1. Report ID format (testimony, legal_decision, correspondence) — no I/O
#   2. Product page HTMLs (gao.gov/products/) — highlights subtitle parsing
#   3. Report PDFs (fallback) — addressee block from PDF text
#
# Run phases independently — each is resumable/idempotent.
#
# ── Config ────────────────────────────────────────────────────────────────────

page.html.dir   <- "/run/media/jack/Storage/gao_reports/gao_page_archive_html"
report.pdf.dir  <- "/run/media/jack/Storage/gao_reports/gao_report_archive_pdf"

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

# ── Phase 2: Parse product page HTMLs (highlights subtitle) ──────────────────

message("\n=== Phase 2: Product page HTML parsing ===")

if (is.null(page.html.dir) || !dir.exists(page.html.dir)) {
  message("Product page HTML directory not set or not found: ", page.html.dir)
  message("Skipping Phase 2.")
} else {
  html.files <- list.files(page.html.dir, pattern = "\\.html$", full.names = TRUE)
  html.files <- html.files[file.size(html.files) >= 200]
  message("Product page HTML files to parse: ", length(html.files))

  hl.parsed <- vector("list", length(html.files))

  for (i in seq_along(html.files)) {
    hl.parsed[[i]] <- tryCatch({
      page <- rvest::read_html(html.files[i])
      info <- .parse_highlights_subtitle(page)
      slug <- sub("\\.html$", "", tolower(basename(html.files[i])))
      data.frame(
        slug = slug,
        hl_requester_type = info$requester_type,
        hl_requester_committees = info$requester_committees,
        hl_requester_members = info$requester_members,
        stringsAsFactors = FALSE
      )
    }, error = function(e) {
      NULL
    })
    if (i %% 5000 == 0) message("Parsed: ", i, "/", length(html.files))
  }

  hl.data <- do.call(rbind, hl.parsed[!vapply(hl.parsed, is.null, logical(1))])
  message("Successfully parsed: ", nrow(hl.data), " reports")
  message("  with requester_type: ", sum(!is.na(hl.data$hl_requester_type)))
  message("  with committees: ", sum(!is.na(hl.data$hl_requester_committees)))
  message("  with members: ", sum(!is.na(hl.data$hl_requester_members)))

  # Merge: product page data fills where still NA
  current$slug <- tolower(basename(current$url))
  idx <- match(current$slug, hl.data$slug)
  matched <- !is.na(idx)
  message("Matched to dataset: ", sum(matched))

  # requester_type: fill where still NA (ID-based takes priority)
  needs.type <- matched & is.na(current$requester_type)
  current$requester_type[needs.type] <- hl.data$hl_requester_type[idx[needs.type]]

  # committees: product page data fills where still NA
  needs.comm <- matched & is.na(current$requester_committees)
  current$requester_committees[needs.comm] <- hl.data$hl_requester_committees[idx[needs.comm]]

  # members: product page data fills where still NA
  needs.mem <- matched & is.na(current$requester_members)
  current$requester_members[needs.mem] <- hl.data$hl_requester_members[idx[needs.mem]]

  current$slug <- NULL
}

# ── Phase 3: Parse report PDFs (fallback for reports still missing data) ─────

message("\n=== Phase 3: PDF fallback parsing ===")

if (is.null(report.pdf.dir) || !dir.exists(report.pdf.dir)) {
  message("PDF directory not set or not found.")
  message("Skipping Phase 3.")
} else {
  if (!requireNamespace("pdftools", quietly = TRUE)) {
    stop("pdftools package required. Install with: install.packages('pdftools')")
  }

  # Only parse PDFs for reports still missing requester_type
  current$slug <- tolower(basename(current$url))
  needs.pdf <- which(is.na(current$requester_type))
  message("Reports still missing requester_type: ", length(needs.pdf))

  if (length(needs.pdf) > 0) {
    pdf.slugs <- current$slug[needs.pdf]
    pdf.paths <- file.path(report.pdf.dir, paste0(pdf.slugs, ".pdf"))
    exists.mask <- file.exists(pdf.paths)
    pdf.paths <- pdf.paths[exists.mask]
    message("PDF files found for missing reports: ", length(pdf.paths))

    if (length(pdf.paths) > 0) {
      if (requireNamespace("furrr", quietly = TRUE) &&
          requireNamespace("future", quietly = TRUE)) {
        message("Using parallel processing...")
        future::plan(future::multisession,
                     workers = max(1, parallel::detectCores() - 1))

        ab.parsed <- furrr::future_map(pdf.paths, function(f) {
          tryCatch({
            pages <- pdftools::pdf_text(f)
            text <- paste(pages[seq_len(min(2, length(pages)))], collapse = "\n")
            # Try addressee block first ("The Honorable" patterns)
            info <- gao:::.parse_addressee_block(text)
            # Fall back to cover-page subtitle ("Report to..." patterns)
            if (is.na(info$requester_type)) {
              info2 <- gao:::.parse_pdf_cover_subtitle(text)
              if (!is.na(info2$requester_type)) info <- info2
            }
            slug <- sub("\\.pdf$", "", tolower(basename(f)))
            data.frame(
              slug = slug,
              ab_requester_type = info$requester_type,
              ab_requester_committees = info$requester_committees,
              ab_requester_members = info$requester_members,
              stringsAsFactors = FALSE
            )
          }, error = function(e) NULL)
        }, .progress = TRUE)

        future::plan(future::sequential)
      } else {
        message("furrr not available, using sequential processing...")
        ab.parsed <- vector("list", length(pdf.paths))
        for (i in seq_along(pdf.paths)) {
          ab.parsed[[i]] <- tryCatch({
            pages <- pdftools::pdf_text(pdf.paths[i])
            text <- paste(pages[seq_len(min(2, length(pages)))], collapse = "\n")
            info <- .parse_addressee_block(text)
            if (is.na(info$requester_type)) {
              info2 <- .parse_pdf_cover_subtitle(text)
              if (!is.na(info2$requester_type)) info <- info2
            }
            slug <- sub("\\.pdf$", "", tolower(basename(pdf.paths[i])))
            data.frame(
              slug = slug,
              ab_requester_type = info$requester_type,
              ab_requester_committees = info$requester_committees,
              ab_requester_members = info$requester_members,
              stringsAsFactors = FALSE
            )
          }, error = function(e) NULL)
          if (i %% 5000 == 0) message("Parsed: ", i, "/", length(pdf.paths))
        }
      }

      ab.data <- do.call(rbind, ab.parsed[!vapply(ab.parsed, is.null, logical(1))])
      message("Successfully parsed: ", nrow(ab.data), " PDFs")

      # Merge: only fill where still NA
      idx <- match(current$slug, ab.data$slug)
      matched <- !is.na(idx)

      needs.type <- matched & is.na(current$requester_type)
      current$requester_type[needs.type] <- ab.data$ab_requester_type[idx[needs.type]]

      needs.comm <- matched & is.na(current$requester_committees)
      current$requester_committees[needs.comm] <- ab.data$ab_requester_committees[idx[needs.comm]]

      needs.mem <- matched & is.na(current$requester_members)
      current$requester_members[needs.mem] <- ab.data$ab_requester_members[idx[needs.mem]]
    }
  }

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
