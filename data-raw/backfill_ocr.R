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

# Find NAs with local PDFs
current$slug <- tolower(basename(current$url))
na.idx <- which(is.na(current$requester_type))
paths <- file.path(pdf.dir, paste0(current$slug[na.idx], ".pdf"))
has.pdf <- file.exists(paths)
target.paths <- paths[has.pdf]
target.idx <- na.idx[has.pdf]
message("PDFs to OCR: ", length(target.paths))

# ── Step 1: Export PDF list ──────────────────────────────────────────────────

list.file <- file.path(tempdir(), "ocr_pdf_list.txt")
writeLines(target.paths, list.file)

# ── Step 2: Run tesseract OCR ────────────────────────────────────────────────

message("\nStarting tesseract OCR (parallel)...")
exit.code <- system2("python3",
                     c("data-raw/ocr_backfill.py", list.file, ocr.dir, "12"),
                     stdout = "", stderr = "")
if (exit.code != 0) warning("OCR script exited with code ", exit.code)

# ── Step 3: Parse OCR'd text ─────────────────────────────────────────────────

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
