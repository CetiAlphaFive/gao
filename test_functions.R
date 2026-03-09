## test_functions.R — smoke test for gao package
## Run interactively, one block at a time
## Minimal requests to avoid hammering GAO

library(gao)

test.dir <- file.path(tempdir(), "gao_test")
dir.create(test.dir, showWarnings = FALSE)
message("Test output directory: ", test.dir)

# ── 1. internal helper: .get_last_page() ─────────────────────────────────────
message("\n=== Test 1: .get_last_page() ===")
last.page <- gao:::.get_last_page()
stopifnot(is.numeric(last.page), last.page > 100)
message("OK — last page: ", last.page)

# ── 2. extract_links() — scrape page 0 and 1 only ────────────────────────────
message("\n=== Test 2: extract_links() ===")
links <- extract_links(
  last_page    = 1,
  save_to_file = FALSE,
  sleep_timer  = 1
)
stopifnot(is.character(links), length(links) > 0)
stopifnot(all(grepl("^https://www.gao.gov/products/", links)))
message("OK — extracted ", length(links), " report links from 2 pages")
message("Sample: ", links[1])

# ── 3. extract_pdf_links() — test on 3 report pages ──────────────────────────
message("\n=== Test 3: extract_pdf_links() ===")
test.links <- head(links, 3)
pdf.links <- extract_pdf_links(test.links, sleep_time = 1)
message("PDF links found: ", length(pdf.links))
if (length(pdf.links) > 0) {
  message("Sample: ", pdf.links[1])
  stopifnot(all(grepl("\\.pdf$", pdf.links)))
  message("OK — all end in .pdf")
} else {
  message("NOTE: no PDFs found for these reports (some reports lack PDFs)")
}

# ── 4. download_pdfs() — download 1 PDF ──────────────────────────────────────
message("\n=== Test 4: download_pdfs() ===")
if (length(pdf.links) > 0) {
  pdf.dir <- file.path(test.dir, "pdfs")
  download_pdfs(pdf.links[1], download_dir = pdf.dir, sleep_time = 0)

  downloaded <- list.files(pdf.dir, pattern = "\\.pdf$")
  stopifnot(length(downloaded) >= 1)
  fsize <- file.size(file.path(pdf.dir, downloaded[1]))
  stopifnot(fsize > 1000)
  message("OK — downloaded: ", downloaded[1], " (", round(fsize / 1024), " KB)")
} else {
  message("SKIP — no PDF links to test")
}

# ── 5. download_htmls() — download 1 HTML ────────────────────────────────────
message("\n=== Test 5: download_htmls() ===")
html.dir <- file.path(test.dir, "htmls")
download_htmls(links[1], target_directory = html.dir, sleep_time = 0)

downloaded.html <- list.files(html.dir, pattern = "\\.html$")
stopifnot(length(downloaded.html) >= 1)
fsize <- file.size(file.path(html.dir, downloaded.html[1]))
stopifnot(fsize > 1000)
message("OK — downloaded: ", downloaded.html[1], " (", round(fsize / 1024), " KB)")

# ── done ──────────────────────────────────────────────────────────────────────
message("\n=== All tests passed ===")
message("Test files in: ", test.dir)
message("Run unlink('", test.dir, "', recursive = TRUE) to clean up")
