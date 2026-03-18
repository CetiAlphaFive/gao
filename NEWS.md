# gao 0.5.0

* CRAN preparation release.
* Bundled RDS shrunk from 6.4 MB to 3.7 MB by storing only 14 core columns
  with xz compression. The 82 indicator columns are now computed on the fly
  by `gao_links()` and cached in memory.
* New `gao_update_data()` function downloads the latest data from GitHub
  Releases using base R `download.file()` — no `curl-impersonate` needed.
  `gao_links()` checks for user-local cached data before the bundled copy.
* `auto_download()` now offers to check for updated data in interactive
  sessions before proceeding.
* Daily CI workflow now uploads the RDS to a pinned GitHub Release
  (`data-latest`) for `gao_update_data()` to fetch.
* Fixed missing `lifecycle-deprecated.svg` badge referenced by
 `extract_pdf_links.Rd`.
* Updated `CITATION.cff` to match current version and license.

# gao 0.4.0

* New `extract_text()` function for extracting text from downloaded PDFs.
  Requires `pdftools` (added to `Suggests`).
* Bundled dataset now includes `page_count`, `topics`, and `subject_terms`
  columns. `gao_links()` returns a 9-column data.frame.
* Full metadata backfill: `title`, `published`, `released` are now 100%
  populated across all 56,000+ reports. `summary` at 97.5%.
* Missing `report_id` values filled from URL slugs (now 100% complete).
* Page counts extracted from 55,000+ PDF archive and matched to metadata
  via URL slug and report ID (80.7% coverage).
* Daily CI workflow now backfills `page_count` for newly added reports.
* Fixed `update_links()` column mismatch when bundled data has columns
  that new scrape results lack.
* License changed from MIT to GPL (>= 3).

# gao 0.3.0

* **Breaking:** `gao_links()` now returns a data.frame with columns `url`,
  `title`, `report_id`, `published`, `released`, and `summary` instead of a
  character vector.
* Bundled dataset switched from text (`.txt`) to RDS (`.rds`) for compression
  with rich metadata.
* Year filtering in `auto_download()` now uses published date and fiscal year
  calculation instead of regex on report IDs, fixing ~29% of reports with
  legacy ID formats that previously yielded `NA` years.
* `extract_links()` and `update_links()` now return data.frames with full
  report metadata.
* Fixed R-CMD-check GitHub Action syntax error (`args` parameter).

# gao 0.2.0

* Added `auto_download()` convenience wrapper that handles the full pipeline
  (load links, filter by year, download as PDF/HTML) in one call.
* PDF URLs are now constructed directly from report IDs, avoiding one HTTP
  request per report compared to `extract_pdf_links()`.
* Interactive prompts for format and year range when arguments are omitted.
* Non-interactive safety: `confirm = TRUE` errors unless explicitly set to
  `FALSE`, preventing accidental mass downloads.

# gao 0.1.0

* Initial release.
* Bundled dataset of ~55,000 GAO report URLs (1921--present).
* `gao_links()` to access bundled report URLs.
* `update_links()` to scrape newly published reports.
* `extract_links()` to build the full link list from scratch.
* `extract_pdf_links()` to find PDF download links from report pages.
* `download_pdfs()` and `download_htmls()` for batch downloading.
* Requires 'curl-impersonate' for TLS fingerprint compatibility.
