# Changelog

## gao 0.4.0

- New
  [`extract_text()`](https://cetialphafive.github.io/gao/reference/extract_text.md)
  function for extracting text from downloaded PDFs. Requires `pdftools`
  (added to `Suggests`).
- Bundled dataset now includes `page_count`, `topics`, and
  `subject_terms` columns.
  [`gao_links()`](https://cetialphafive.github.io/gao/reference/gao_links.md)
  returns a 9-column data.frame.
- Full metadata backfill: `title`, `published`, `released` are now 100%
  populated across all 56,000+ reports. `summary` at 97.5%.
- Missing `report_id` values filled from URL slugs (now 100% complete).
- Page counts extracted from 55,000+ PDF archive and matched to metadata
  via URL slug and report ID (80.7% coverage).
- Daily CI workflow now backfills `page_count` for newly added reports.
- Fixed
  [`update_links()`](https://cetialphafive.github.io/gao/reference/update_links.md)
  column mismatch when bundled data has columns that new scrape results
  lack.
- License changed from MIT to GPL (\>= 3).

## gao 0.3.0

- **Breaking:**
  [`gao_links()`](https://cetialphafive.github.io/gao/reference/gao_links.md)
  now returns a data.frame with columns `url`, `title`, `report_id`,
  `published`, `released`, and `summary` instead of a character vector.
- Bundled dataset switched from text (`.txt`) to RDS (`.rds`) for
  compression with rich metadata.
- Year filtering in
  [`auto_download()`](https://cetialphafive.github.io/gao/reference/auto_download.md)
  now uses published date and fiscal year calculation instead of regex
  on report IDs, fixing ~29% of reports with legacy ID formats that
  previously yielded `NA` years.
- [`extract_links()`](https://cetialphafive.github.io/gao/reference/extract_links.md)
  and
  [`update_links()`](https://cetialphafive.github.io/gao/reference/update_links.md)
  now return data.frames with full report metadata.
- Fixed R-CMD-check GitHub Action syntax error (`args` parameter).

## gao 0.2.0

- Added
  [`auto_download()`](https://cetialphafive.github.io/gao/reference/auto_download.md)
  convenience wrapper that handles the full pipeline (load links, filter
  by year, download as PDF/HTML) in one call.
- PDF URLs are now constructed directly from report IDs, avoiding one
  HTTP request per report compared to
  [`extract_pdf_links()`](https://cetialphafive.github.io/gao/reference/extract_pdf_links.md).
- Interactive prompts for format and year range when arguments are
  omitted.
- Non-interactive safety: `confirm = TRUE` errors unless explicitly set
  to `FALSE`, preventing accidental mass downloads.

## gao 0.1.0

- Initial release.
- Bundled dataset of ~55,000 GAO report URLs (1921–present).
- [`gao_links()`](https://cetialphafive.github.io/gao/reference/gao_links.md)
  to access bundled report URLs.
- [`update_links()`](https://cetialphafive.github.io/gao/reference/update_links.md)
  to scrape newly published reports.
- [`extract_links()`](https://cetialphafive.github.io/gao/reference/extract_links.md)
  to build the full link list from scratch.
- [`extract_pdf_links()`](https://cetialphafive.github.io/gao/reference/extract_pdf_links.md)
  to find PDF download links from report pages.
- [`download_pdfs()`](https://cetialphafive.github.io/gao/reference/download_pdfs.md)
  and
  [`download_htmls()`](https://cetialphafive.github.io/gao/reference/download_htmls.md)
  for batch downloading.
- Requires ‘curl-impersonate’ for TLS fingerprint compatibility.
