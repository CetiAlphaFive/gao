## build_gao_links.R — batch-download all GAO listing pages, then parse locally
## Two phases: (1) parallel download with xargs, (2) local parsing with rvest

library(gao)

# ── Phase 0: detect last page ────────────────────────────────────────────────
message("Detecting last page...")
last.page <- gao:::.get_last_page()
message("Last page: ", last.page)

# ── Phase 1: batch download all listing pages ────────────────────────────────
page.dir <- file.path(tempdir(), "gao_pages")
dir.create(page.dir, showWarnings = FALSE)

# Generate URL list
urls <- c(
  "https://www.gao.gov/reports-testimonies",
  paste0("https://www.gao.gov/reports-testimonies?page=", seq_len(last.page))
)
url.file <- file.path(page.dir, "urls.txt")
writeLines(urls, url.file)

message("Downloading ", length(urls), " pages with 40 concurrent workers...")

curl.bin <- gao:::.get_curl_bin()
# xargs: -P 40 for concurrency, -I{} for URL substitution
# Output filename = page number extracted from URL (or 0 for base)
download.cmd <- sprintf(
  "xargs -P 40 -a '%s' -I{} sh -c '%s -s -L -o \"%s/page_$(echo \"{}\" | grep -oP \"page=\\K[0-9]+\" || echo 0).html\" \"{}\"'",
  url.file, curl.bin, page.dir
)

t0 <- proc.time()
system(download.cmd)
elapsed <- (proc.time() - t0)[3]

n.downloaded <- length(list.files(page.dir, pattern = "\\.html$"))
message("Downloaded ", n.downloaded, " pages in ", round(elapsed, 1), "s")

# Check for blocked pages
blocked <- vapply(
  list.files(page.dir, pattern = "\\.html$", full.names = TRUE),
  function(f) any(grepl("Access Denied", readLines(f, n = 10, warn = FALSE))),
  logical(1)
)
if (any(blocked)) {
  message("WARNING: ", sum(blocked), " pages were blocked. Retrying...")
  blocked.files <- names(blocked)[blocked]
  # Extract page numbers and retry individually
  for (f in blocked.files) {
    pg <- gsub(".*page_(\\d+)\\.html$", "\\1", f)
    url <- if (pg == "0") urls[1] else paste0("https://www.gao.gov/reports-testimonies?page=", pg)
    Sys.sleep(1)
    system2(curl.bin, args = c("-s", "-L", "-o", f, url))
  }
}

# ── Phase 2: parse locally ───────────────────────────────────────────────────
message("Parsing downloaded pages...")
html.files <- list.files(page.dir, pattern = "\\.html$", full.names = TRUE)

all.links <- character(0)
for (f in html.files) {
  page <- rvest::read_html(f)
  hrefs <- rvest::html_attr(rvest::html_nodes(page, "a"), "href")
  product.links <- hrefs[grep("/products/", hrefs)]
  all.links <- c(all.links, product.links)
}

full.links <- sort(unique(paste0("https://www.gao.gov", all.links)))
message("Total unique report links: ", length(full.links))

# ── Save ──────────────────────────────────────────────────────────────────────
dir.create("inst/extdata", recursive = TRUE, showWarnings = FALSE)
writeLines(full.links, "inst/extdata/gao_links.txt")
message("Saved to inst/extdata/gao_links.txt")

# Cleanup
unlink(page.dir, recursive = TRUE)
