## extract_page_counts.R
## ─────────────────────────────────────────────────────────────────
## One-time script to extract page counts (and optional PDF metadata)
## from the local PDF archive and merge into gao_links.rds.
##
## Requires: pdftools
## PDF archive: /run/media/jack/Storage/gao_reports/gao_report_archive_pdf/
## ─────────────────────────────────────────────────────────────────

pacman::p_load(pdftools, furrr, future)

pdf.dir <- "/run/media/jack/Storage/gao_reports/gao_report_archive_pdf"
links   <- readRDS("inst/extdata/gao_links.rds")

## ── 1. List PDFs and build lookup key ──────────────────────────

pdf.files <- list.files(pdf.dir, pattern = "\\.pdf$", full.names = FALSE)
cat("PDFs found:", length(pdf.files), "\n")

## key = lowercase filename without .pdf
pdf.key <- tolower(sub("\\.pdf$", "", pdf.files))

## key from metadata = lowercase URL slug
links$slug <- tolower(basename(links$url))

## ── 2. Extract page counts with parallel processing ────────────

plan(multisession, workers = parallel::detectCores() - 1)

safe.page.count <- function(f) {
  tryCatch(
    pdftools::pdf_length(f),
    error = function(e) NA_integer_
  )
}

cat("Extracting page counts...\n")
t0 <- Sys.time()

pdf.paths <- file.path(pdf.dir, pdf.files)
page.counts <- future_map_int(pdf.paths, safe.page.count,
                               .progress = TRUE,
                               .options = furrr_options(seed = NULL))

elapsed <- difftime(Sys.time(), t0, units = "mins")
cat(sprintf("Done in %.1f minutes.\n", as.numeric(elapsed)))

plan(sequential)

## ── 3. Build PDF-level data.frame ──────────────────────────────

pdf.data <- data.frame(
  slug       = pdf.key,
  page_count = page.counts,
  stringsAsFactors = FALSE
)

cat("PDFs with valid page counts:", sum(!is.na(pdf.data$page_count)), "\n")
cat("PDFs that failed extraction:", sum(is.na(pdf.data$page_count)), "\n")

## ── 4. Merge into links ────────────────────────────────────────

links <- merge(links, pdf.data, by = "slug", all.x = TRUE, sort = FALSE)
links$slug <- NULL

## Restore original sort order
links <- links[order(links$url), , drop = FALSE]
rownames(links) <- NULL

cat("\nMatch summary:\n")
cat("  Metadata rows with page_count:", sum(!is.na(links$page_count)),
    "of", nrow(links), "\n")
cat("  Missing page_count:", sum(is.na(links$page_count)), "\n")

## ── 5. Summary statistics ──────────────────────────────────────

cat("\nPage count distribution:\n")
print(summary(links$page_count))

## ── 6. Save ────────────────────────────────────────────────────

saveRDS(links, "inst/extdata/gao_links.rds")
cat("\nSaved updated gao_links.rds with page_count column.\n")
