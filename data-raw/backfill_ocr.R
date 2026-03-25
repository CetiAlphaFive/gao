# data-raw/backfill_ocr.R
# Re-OCR PDFs with tesseract for reports where pdftools text was garbled.
#
# Prerequisites: tesseract + tesseract-data-eng installed
#
# Steps:
#   1. Export list of PDFs needing OCR
#   2. Run Python OCR script (parallel tesseract)
#   3. Read back OCR'd text, parse with our requester functions
#   4. Merge, validate, save

devtools::load_all()

pdf.dir   <- "/run/media/jack/Storage/gao_reports/gao_report_archive_pdf"
ocr.dir   <- "data-raw/ocr_text_cache"
dir.create(ocr.dir, showWarnings = FALSE)

current <- readRDS("inst/extdata/gao_links.rds")
message("Total: ", nrow(current), " | With type: ", sum(!is.na(current$requester_type)),
        " | NA: ", sum(is.na(current$requester_type)))

# Match OCR cache files to NA reports
current$slug <- tolower(basename(current$url))
na.idx <- which(is.na(current$requester_type))
message("Reports still NA: ", length(na.idx))

ocr.files <- list.files(ocr.dir, pattern = "\\.txt$", full.names = FALSE)
ocr.slugs <- sub("\\.txt$", "", ocr.files)
message("OCR text files available: ", length(ocr.files))

# Find NAs that have OCR text
target.idx <- na.idx[current$slug[na.idx] %in% ocr.slugs]
message("NAs with OCR text: ", length(target.idx))

# ── Parse OCR'd text ─────────────────────────────────────────────────────────

message("\nParsing OCR results...")
n.filled <- 0L

for (j in seq_along(target.idx)) {
  i <- target.idx[j]
  slug <- current$slug[i]
  txt.file <- file.path(ocr.dir, paste0(slug, ".txt"))

  if (!file.exists(txt.file) || file.size(txt.file) < 50) next

  text <- paste(readLines(txt.file, warn = FALSE), collapse = "\n")

  info <- .parse_addressee_block(text)
  if (is.na(info$requester_type)) {
    info <- .parse_pdf_cover_subtitle(text)
  }

  if (!is.na(info$requester_type)) {
    current$requester_type[i] <- info$requester_type
    if (!is.na(info$requester_committees))
      current$requester_committees[i] <- info$requester_committees
    if (!is.na(info$requester_members))
      current$requester_members[i] <- info$requester_members
    n.filled <- n.filled + 1L
  }

  if (j %% 1000 == 0) message("  Parsed: ", j, "/", length(target.idx),
                                " | filled: ", n.filled)
}

current$slug <- NULL

# ── Step 4: Validate ─────────────────────────────────────────────────────────

message("\n=== Validation ===")
message("Filled from OCR: ", n.filled)
print(table(current$requester_type, useNA = "ifany"))
message("Coverage: ", sum(!is.na(current$requester_type)), " / ", nrow(current),
        " (", round(100 * mean(!is.na(current$requester_type)), 1), "%)")
message("Committees: ", sum(!is.na(current$requester_committees)))
message("Members: ", sum(!is.na(current$requester_members)))

# ── Step 5: Save ─────────────────────────────────────────────────────────────

saveRDS(current, "inst/extdata/gao_links.rds", compress = "xz")
message("Saved.")
