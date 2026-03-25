# data-raw/backfill_1990s.R
# Download + OCR + parse 1990s reports that are still NA.
#
# 1. Download PDFs from gao.gov for 1990s NAs without OCR text
# 2. OCR with Surya GPU → save to ocr_text_cache/
# 3. Parse all 1990s OCR text with requester functions
# 4. Merge, validate, save

devtools::load_all()

ocr.dir <- "data-raw/ocr_text_cache"
tmp.pdf.dir <- file.path(tempdir(), "gao_1990s_pdfs")
dir.create(tmp.pdf.dir, showWarnings = FALSE)
dir.create(ocr.dir, showWarnings = FALSE)

current <- readRDS("inst/extdata/gao_links.rds")
current$year <- as.numeric(format(as.Date(current$published), "%Y"))
current$slug <- tolower(basename(current$url))

# 1990s NAs
na90 <- which(is.na(current$requester_type) &
              !is.na(current$year) & current$year >= 1990 & current$year <= 1999)
message("1990s NAs: ", length(na90))

# Which need downloading? (no OCR text cached yet)
needs.download <- na90[!file.exists(file.path(ocr.dir, paste0(current$slug[na90], ".txt")))]
message("Need download + OCR: ", length(needs.download))

# ── Step 1: Download PDFs ────────────────────────────────────────────────────

if (length(needs.download) > 0) {
  message("\nDownloading ", length(needs.download), " PDFs...")
  n.ok <- 0L
  for (j in seq_along(needs.download)) {
    i <- needs.download[j]
    slug <- current$slug[i]
    pdf.path <- file.path(tmp.pdf.dir, paste0(slug, ".pdf"))
    if (file.exists(pdf.path) && file.size(pdf.path) >= 200) {
      n.ok <- n.ok + 1L; next
    }
    pdf.url <- paste0(sub("/products/", "/assets/", current$url[i]), ".pdf")
    tryCatch({
      .download_file(pdf.url, pdf.path)
      n.ok <- n.ok + 1L
    }, error = function(e) NULL)
    Sys.sleep(1)
    if (j %% 200 == 0) message("  Downloaded: ", j, "/", length(needs.download),
                                 " (ok: ", n.ok, ")")
  }
  message("Downloaded: ", n.ok, " of ", length(needs.download))

  # ── Step 2: OCR with Surya GPU ──────────────────────────────────────────────

  # Write list of downloaded PDFs for the OCR script
  pdf.files <- list.files(tmp.pdf.dir, pattern = "\\.pdf$", full.names = TRUE)
  pdf.files <- pdf.files[file.size(pdf.files) >= 200]
  list.file <- file.path(tempdir(), "ocr_1990s_list.txt")
  writeLines(pdf.files, list.file)
  message("\nOCR'ing ", length(pdf.files), " PDFs with Surya GPU...")

  venv.python <- "data-raw/ocr-env/bin/python3"
  exit.code <- system2(venv.python,
                       c("data-raw/ocr_backfill.py", list.file, ocr.dir),
                       stdout = "", stderr = "")
  if (exit.code != 0) warning("OCR exited with code ", exit.code)

  # Clean up temp PDFs
  unlink(tmp.pdf.dir, recursive = TRUE)
  message("Temp PDFs cleaned up.")
}

# ── Step 3: Parse all 1990s OCR text ─────────────────────────────────────────

message("\nParsing OCR text for 1990s NAs...")
n.filled <- 0L

for (i in na90) {
  slug <- current$slug[i]
  txt.file <- file.path(ocr.dir, paste0(slug, ".txt"))
  if (!file.exists(txt.file) || file.size(txt.file) < 50) next

  text <- paste(readLines(txt.file, warn = FALSE), collapse = "\n")
  text <- gsub("<[^>]+>", "", text)

  info <- .parse_addressee_block(text)
  if (is.na(info$requester_type)) info <- .parse_pdf_cover_subtitle(text)

  if (!is.na(info$requester_type)) {
    current$requester_type[i] <- info$requester_type
    if (!is.na(info$requester_committees))
      current$requester_committees[i] <- info$requester_committees
    if (!is.na(info$requester_members))
      current$requester_members[i] <- info$requester_members
    n.filled <- n.filled + 1L
  }
}

# ── Step 4: Validate ─────────────────────────────────────────────────────────

message("\n=== 1990s Validation ===")
message("Filled: ", n.filled)

n90 <- current[!is.na(current$year) & current$year >= 1990 & current$year <= 1999, ]
for (y in 1990:1999) {
  sub <- n90[n90$year == y, ]
  message(y, ": ", nrow(sub), " total, ", sum(is.na(sub$requester_type)), " NA (",
          round(100 * mean(!is.na(sub$requester_type)), 1), "% coverage)")
}
message("\n1990s overall: ", nrow(n90), " total, ",
        sum(is.na(n90$requester_type)), " NA (",
        round(100 * mean(!is.na(n90$requester_type)), 1), "% coverage)")

current$year <- NULL
current$slug <- NULL
saveRDS(current, "inst/extdata/gao_links.rds", compress = "xz")
message("Saved.")
