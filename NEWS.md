# gao 0.6.1

* Fixed daily data updates: new reports are now discovered through GAO's
  official RSS feed after a change on gao.gov broke the previous approach.
  If the feed is ever unavailable, the update fails with a clear error
  instead of quietly adding nothing.
* Metadata scraping now recognizes when gao.gov returns a block page
  instead of a report page and treats it as a failed fetch, rather than
  reading the block page as content.

# gao 0.6.0

* `gao_links()` now returns additional analysis-ready columns:
  `issuing_division` and `product_type` (decoded from report IDs), temporal
  covariates (`pub_month`, `pub_dow`, `pub_fiscal_year`, `fiscal_quarter`,
  `election_year`, `release_lag_days`), scope counts (`n_topics`,
  `n_subject_terms`), and congressional requester covariates
  (`requester_party`, `requester_majority_status`, `requester_chamber`,
  `requester_bipartisan`) resolved against Voteview membership data.
* Much cleaner requester fields: stray text no longer appears in
  `requester_committees` / `requester_members`; multi-word, hyphenated, and
  suffixed member names (Van Hollen, Ros-Lehtinen, Wasserman Schultz) now
  resolve; House/Senate members who share a surname no longer collide; and
  independents are labeled `"Other"` with majority status resolved via the
  party they caucus with.
* Topic and agency indicator columns now use exact matching, so similar
  names no longer trigger the wrong flag; empty source fields yield `NA`
  instead of all zeros.
* More reliable downloads and locale-independent date parsing.

# gao 0.5.0

* Smaller package: the bundled dataset shrank from 6.4 MB to 3.7 MB.
  Indicator columns are now computed when the data is loaded.
* New `gao_update_data()` downloads the latest dataset (refreshed daily)
  without any extra software; `gao_links()` then uses it automatically.
* `auto_download()` offers to check for updated data in interactive
  sessions.

# gao 0.4.0

* New `extract_text()` extracts text from downloaded PDFs (requires the
  `pdftools` package).
* The dataset gains `page_count`, `topics`, and `subject_terms` columns.
  `title`, `published`, and `released` are now complete for all 56,000+
  reports, and page counts cover about 80% of them.
* License changed from MIT to GPL (>= 3).

# gao 0.3.0

* **Breaking:** `gao_links()` now returns a data.frame with full report
  metadata instead of a character vector of URLs.
* Fiscal-year filtering now uses publication dates rather than patterns in
  report IDs, fixing missing years for roughly a third of older reports.

# gao 0.2.0

* New `auto_download()`: load the dataset, filter by year, and download
  reports in one call, with interactive prompts and a confirmation guard
  against accidental mass downloads.
* Faster PDF downloads (one fewer web request per report).

# gao 0.1.0

* Initial release: bundled dataset of ~55,000 GAO report URLs
  (1921--present), `gao_links()` for browsing, and batch download of
  reports as PDF or HTML.
