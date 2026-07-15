# Changelog

## gao 0.6.1

- **New-report discovery is now RSS-based.** gao.gov put the paginated
  HTML listing page (`/reports-testimonies`) behind an Akamai Bot
  Manager JS challenge (`bm-verify`); curl-impersonate defeats
  TLS-fingerprint filtering but cannot execute JS, so the daily CI job
  silently scraped 0 rows from that page for weeks while still exiting
  green. `update_links()` now discovers new reports from the GAO RSS
  feed (`https://www.gao.gov/rss/reports.xml`) instead, via a new
  internal `.fetch_rss_links()`/`.parse_rss()`. Individual report-page
  metadata scraping (`.fetch_html()`, `.scrape_report_metadata()`) is
  unaffected – only the listing-page discovery path was replaced.
  **Known limitation:** the RSS feed carries only the ~25 most recent
  reports, so discovery depends on the daily job running reliably;
  gap-fill (Phase 2) recovers missing *metadata* for known reports but
  does not rediscover report URLs that fell outside the RSS window
  between runs.
- `.fetch_html()` now detects bot-challenge/blocked response bodies (a
  `bm-verify` marker, a `<meta http-equiv="refresh">` bounce to a
  `bm-verify` URL, or the legacy “Access Denied” page) via the new
  `.is_challenge_page()` predicate and treats them the same as a failed
  fetch (retry, then error) instead of parsing the challenge page as
  content.
- Daily CI workflow (`update-links.yml`) Phase 2 gap-fill selector no
  longer re-selects reports every day solely because `requester_type` is
  `NA` – that’s a legitimate, permanent state for reports with no named
  requester (statutory mandates, legal decisions), and gating on it too
  meant ~9556 reports were re-scraped in every run and the 5000/day
  batch never converged. The selector now gates on `topics` only (the
  self-clearing sentinel a successful scrape always writes). `n.filled`
  is now incremented only when a scrape actually produced usable data,
  so the “N gaps filled” commit message is accurate.

## gao 0.6.0

- [`gao_links()`](https://cetialphafive.github.io/gao/reference/gao_links.md)
  now returns derived covariate columns computed on the fly:
  `issuing_division` and `product_type` (decoded from report-ID
  prefixes), neutral temporal features (`pub_month`, `pub_dow`,
  `pub_fiscal_year`, `fiscal_quarter`, `election_year`,
  `release_lag_days`), scope counts (`n_topics`, `n_subject_terms`), and
  requester party covariates (`requester_party`,
  `requester_majority_status`, `requester_chamber`,
  `requester_bipartisan`) resolved against a bundled VoteView crosswalk.
- Fixed noise in `requester_committees` / `requester_members` (injected
  “GAO” tokens, “RELEASED” bleed, OCR mid-word capitalization); the
  daily update now cleans these fields on save.
- Requester party/majority covariates corrected: multi-word, hyphenated,
  and suffixed surnames (Van Hollen, Ros-Lehtinen, de la Garza,
  Wasserman Schultz, Diaz-Balart, Dingell Jr.) now resolve; the lookup
  is chamber-aware so House/Senate namesakes (Mark/Mike Kelly,
  Rick/Bobby Scott, John/Joe Kennedy) no longer collide; majority status
  is computed per the requester’s chamber; independents are labeled
  `requester_party = "Other"` with majority status resolved via caucus.
- Senate majority table corrected for independents/near-ties (e.g. the
  110th and 117th Senates are now “D”).
- Parser root-cause fixes: injected “GAO” wordmark,
  distribution/security stamp bleed (“RELEASED”/“RESTRICTED”/OCR
  “PESTRICTUD”), committee names with internal commas, and highlights
  over-capture of “Why GAO Did This Study” prose.
- Indicators use exact per-item matching for agencies and topics (GAO
  sub-office strings no longer flip a parent-department flag); empty
  source fields now yield `NA` rather than all-zero.
- Downloads use curl `--fail`; HTML fetch keys on HTTP status; dates
  parse locale-independently; `gao-YY` URL fiscal years pivot to the
  2000s.

## gao 0.5.0

- CRAN preparation release.
- Bundled RDS shrunk from 6.4 MB to 3.7 MB by storing only 14 core
  columns with xz compression. The 82 indicator columns are now computed
  on the fly by
  [`gao_links()`](https://cetialphafive.github.io/gao/reference/gao_links.md)
  and cached in memory.
- New
  [`gao_update_data()`](https://cetialphafive.github.io/gao/reference/gao_update_data.md)
  function downloads the latest data from GitHub Releases using base R
  [`download.file()`](https://rdrr.io/r/utils/download.file.html) — no
  `curl-impersonate` needed.
  [`gao_links()`](https://cetialphafive.github.io/gao/reference/gao_links.md)
  checks for user-local cached data before the bundled copy.
- [`auto_download()`](https://cetialphafive.github.io/gao/reference/auto_download.md)
  now offers to check for updated data in interactive sessions before
  proceeding.
- Daily CI workflow now uploads the RDS to a pinned GitHub Release
  (`data-latest`) for
  [`gao_update_data()`](https://cetialphafive.github.io/gao/reference/gao_update_data.md)
  to fetch.
- Fixed missing `lifecycle-deprecated.svg` badge referenced by
  `extract_pdf_links.Rd`.
- Updated `CITATION.cff` to match current version and license.

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
- Fixed `update_links()` column mismatch when bundled data has columns
  that new scrape results lack.
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
- `extract_links()` and `update_links()` now return data.frames with
  full report metadata.
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
- `update_links()` to scrape newly published reports.
- `extract_links()` to build the full link list from scratch.
- [`extract_pdf_links()`](https://cetialphafive.github.io/gao/reference/extract_pdf_links.md)
  to find PDF download links from report pages.
- `download_pdfs()` and `download_htmls()` for batch downloading.
- Requires ‘curl-impersonate’ for TLS fingerprint compatibility.
