# data-raw/backfill_remaining.R
# Download + parse PDFs for reports still missing requester_type
# that don't have local PDF copies.
#
# Resumable: caches downloaded PDFs to tmp.dir, skips already-parsed.

devtools::load_all()

tmp.dir <- file.path(tempdir(), "gao_pdf_backfill")
dir.create(tmp.dir, showWarnings = FALSE)

current <- readRDS("inst/extdata/gao_links.rds")
message("Total reports: ", nrow(current))
message("With requester_type: ", sum(!is.na(current$requester_type)))
message("Still NA: ", sum(is.na(current$requester_type)))

# Find NAs that don't have local PDFs
local.pdf.dir <- "/run/media/jack/Storage/gao_reports/gao_report_archive_pdf"
current$slug <- tolower(basename(current$url))
na.idx <- which(is.na(current$requester_type))
has.local <- file.exists(file.path(local.pdf.dir, paste0(current$slug[na.idx], ".pdf")))

# Only target reports WITHOUT local PDFs (local ones already failed the parser)
target.idx <- na.idx[!has.local]
message("\nReports to process (no local PDF): ", length(target.idx))

# ── Download and parse in batches ─────────────────────────────────────────────

n.filled <- 0L
n.errors <- 0L
batch.size <- 100L
n.batches <- ceiling(length(target.idx) / batch.size)

for (batch in seq_len(n.batches)) {
  start <- (batch - 1) * batch.size + 1
  end <- min(batch * batch.size, length(target.idx))
  batch.idx <- target.idx[start:end]

  for (i in batch.idx) {
    slug <- current$slug[i]
    pdf.path <- file.path(tmp.dir, paste0(slug, ".pdf"))

    # Download if not already cached
    if (!file.exists(pdf.path) || file.size(pdf.path) < 200) {
      pdf.url <- paste0(sub("/products/", "/assets/", current$url[i]), ".pdf")
      tryCatch(
        .download_file(pdf.url, pdf.path),
        error = function(e) NULL
      )
      Sys.sleep(1)
    }

    # Parse if downloaded
    if (file.exists(pdf.path) && file.size(pdf.path) >= 200) {
      info <- tryCatch({
        pages <- pdftools::pdf_text(pdf.path)
        text <- paste(pages[seq_len(min(5, length(pages)))], collapse = "\n")
        res <- .parse_addressee_block(text)
        if (is.na(res$requester_type)) {
          res2 <- .parse_pdf_cover_subtitle(text)
          if (!is.na(res2$requester_type)) res <- res2
        }
        res
      }, error = function(e) NULL)

      if (!is.null(info) && !is.na(info$requester_type)) {
        current$requester_type[i] <- info$requester_type
        if (!is.na(info$requester_committees))
          current$requester_committees[i] <- info$requester_committees
        if (!is.na(info$requester_members))
          current$requester_members[i] <- info$requester_members
        n.filled <- n.filled + 1L
      }
    } else {
      n.errors <- n.errors + 1L
    }
  }

  message("Batch ", batch, "/", n.batches,
          " | filled: ", n.filled, " | errors: ", n.errors)

  # Save progress every 10 batches
  if (batch %% 10 == 0) {
    current$slug <- NULL
    saveRDS(current, "inst/extdata/gao_links.rds", compress = "xz")
    current$slug <- tolower(basename(current$url))
    message("  [checkpoint saved]")
  }
}

current$slug <- NULL

# ── Validate ──────────────────────────────────────────────────────────────────

message("\n=== Validation ===")
message("Filled: ", n.filled, " | Download errors: ", n.errors)
print(table(current$requester_type, useNA = "ifany"))
message("Coverage: ", sum(!is.na(current$requester_type)), " / ", nrow(current),
        " (", round(100 * mean(!is.na(current$requester_type)), 1), "%)")

# ── Save ──────────────────────────────────────────────────────────────────────

saveRDS(current, "inst/extdata/gao_links.rds", compress = "xz")
message("Saved.")

# Clean up temp PDFs
unlink(tmp.dir, recursive = TRUE)
message("Cleaned up temp directory.")
