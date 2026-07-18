# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Title:** Did the Republican Revolution Hamstring Congressional Oversight? Evidence from 55,000 GAO Reports
**Author:** Jack Rametta (solo)
**Status:** Revising (back from review). Presented MPSA 2024.

This repo is the R package `gao`: a complete library of GAO report metadata (55,000+ reports, 1921–present, refreshed daily via CI) with download tools. It supports the accompanying research paper on congressional oversight (paper lives outside this repo).

## Commands

```bash
# Full test suite (network tests auto-skip without curl_firefox147 on PATH)
Rscript -e 'devtools::test()'

# Single test file (filter matches test-<name>.R)
Rscript -e 'devtools::test(filter = "rss")'

# R CMD check (CRAN-facing)
Rscript -e 'devtools::check()'

# Regenerate man/ + NAMESPACE after changing roxygen comments
Rscript -e 'devtools::document()'

# README.md is generated — edit README.Rmd, then:
Rscript -e 'devtools::build_readme()'
```

- Tests use testthat edition 3. Network-dependent tests gate on `skip_if_not(nchar(Sys.which("curl_firefox147")) > 0)` + `skip_on_cran()`; pure parsers are tested offline with inline fixtures. Mocking via `local_mocked_bindings()`.
- `docs/` is pkgdown output (built by CI) — never hand-edit.

## Architecture

### Data flow (the core design)

The bundled dataset `inst/extdata/gao_links.rds` stores only **14 core columns** (xz-compressed, ~3.7 MB). Everything else is derived at load time:

1. `gao_links()` (R/update_links.R) resolves data in order: in-memory cache (`.gao_env$links`) → user cache from `gao_update_data()` (`tools::R_user_dir("gao", "data")`) → bundled RDS.
2. It then expands ~80 one-hot indicator columns via `.expand_indicators()` (R/indicators.R: fixed topic/agency level sets, exact per-item matching) and derived covariates via `.expand_features()` (R/features.R: issuing division/product type from report-ID prefixes, temporal features, scope counts) plus requester party/chamber/majority (R/requester_party.R), resolved against the VoteView crosswalk in `R/sysdata.rda`.
3. Result is memoized in `.gao_env`.

`R/sysdata.rda` (member/majority crosswalk) is rebuilt **manually** via `data-raw/build_member_crosswalk.R` when a new Congress seats (every 2 years) — deliberately not part of the daily CI job.

### Scraping layer (as of 0.6.1)

New-report discovery (`update_links()`) is **RSS-based**: fetches `https://www.gao.gov/rss/reports.xml` via curl-impersonate, parses with `xml2` (`.fetch_rss_links()` / `.parse_rss()`), NOT the paginated HTML listing page. gao.gov put that listing view (`/reports-testimonies`) behind an Akamai Bot Manager JS challenge (`bm-verify`) that curl-impersonate — a TLS-fingerprint spoofer, not a JS engine — cannot solve; the daily job was silently ingesting 0 new reports for weeks while exiting green. A broken/empty RSS feed now makes `update_links()` `stop()` loudly so CI goes red instead of committing "0 new" silently. `.parse_rss()` is a pure function (no network) precisely so it is unit-testable with inline XML.

Individual report-page metadata scraping (`.fetch_html()` + `.scrape_report_metadata()`) is unaffected; `.fetch_html()` detects and rejects bot-challenge/blocked response bodies (`.is_challenge_page()`) rather than parsing them as content. `extract_links()` (HTML listing pagination) still exists but is blocked by the bot wall — do not build new features on it.

**Known limitation:** the RSS feed carries only the ~25 most recent reports, so discovery depends on the daily cadence running reliably — gap-fill does not rediscover URLs missed by a gap in runs, only missing metadata for already-known reports.

curl-impersonate binary resolution: `.get_curl_bin()` in R/utils.R, default `curl_firefox147`, overridable with `options(gao.curl_bin = ...)`.

### Daily CI (`.github/workflows/update-links.yml`)

Three phases: (1) RSS discovery + per-report metadata/page-count scrape for new reports; (2) gap-fill up to 5000/day of already-known reports, gated on `is.na(topics)` **only** — `topics = ""` is the self-clearing sentinel a successful scrape always writes; do NOT gate on `requester_type` (legitimately `NA` forever for statutory mandates, and gating on it made the batch never converge); (3) save the 14 core columns, commit, upload RDS to the pinned GitHub Release `data-latest` (which `gao_update_data()` fetches with base R, no curl-impersonate).

### Dependency philosophy

Zero hard dependencies (`Depends: R >= 4.1.0` only; everything else in Suggests). Browsing the bundled dataset must work with nothing installed. Suggests-only packages are guarded at runtime by `.require_rvest()` / `.require_xml2()` / `skip_if_not_installed()` — follow this pattern for any new dependency.

## Conventions

- Internal helpers are dot-prefixed (`.parse_rss`), documented with roxygen but `@keywords internal @noRd`. Only 5 exports (`gao_links`, `auto_download`, `extract_text`, `gao_update_data`, `extract_pdf_links`).
- Local variables use dot-separated names (`n.new`, `cache.dir`).
- R source must be ASCII-only (CRAN requirement) — use `\uXXXX` escapes if needed.
- `data-raw/` holds one-off backfill/build scripts; not part of the package build.
- Scrapers must fail loudly (`stop()`) on empty/unexpected results rather than returning empty data — silent-green CI failures are the failure mode this package has been burned by.

## Chief of Staff Integration

The canonical project tracker lives at `~/Dropbox/chief_of_staff/CHIEF_OF_STAFF.md`.

### "update COS" command

When Jack says **"update COS"** at the end of a session:

1. Write a brief status update (2-4 lines max) summarizing:
   - What was accomplished this session
   - What changed (status shifts, blockers added/removed)
   - What the next action is
2. Append it to the `## Raw Updates` section at the bottom of `~/Dropbox/chief_of_staff/CHIEF_OF_STAFF.md` using this format:

```
[YYYY-MM-DD] GAO — Accomplished: [what]. Changed: [what]. Next: [what].
```

3. Confirm to Jack that the update was appended.

**Do not** read, parse, or reorganize the rest of the state file. Just append. The CoS agent handles integration.
