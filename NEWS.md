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
