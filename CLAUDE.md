# CLAUDE.md — GAO / Republican Revolution

## Project Overview

**Title:** Did the Republican Revolution Hamstring Congressional Oversight? Evidence from 55,000 GAO Reports
**Author:** Jack Rametta (solo)
**Status:** Revising (back from review)
**Presented:** MPSA 2024

An R package (`gao`) for automated harvesting and processing of Government Accountability Office reports, plus the accompanying research paper analyzing congressional oversight patterns.

## Key Directories

- `R/` — Package source code (web scraping, PDF/HTML downloading)
- `man/` — R documentation

## Tools & Packages

R package using `rvest`/`xml2` (scraping/RSS parsing), `furrr`/`future` (parallel processing), `httr` (HTTP requests).

### Daily CI pipeline / internal scraping layer (as of 0.6.1)

New-report discovery (`update_links()`) is RSS-based: it fetches
`https://www.gao.gov/rss/reports.xml` via curl-impersonate and parses it
with `xml2` (`.fetch_rss_links()` / `.parse_rss()`), not the paginated HTML
listing page. gao.gov put that listing view (`/reports-testimonies`) behind
an Akamai Bot Manager JS challenge (`bm-verify`) that curl-impersonate --
a TLS-fingerprint spoofer, not a JS engine -- cannot solve; the daily job
was silently ingesting 0 new reports for weeks while exiting green. A
broken/empty RSS feed now makes `update_links()` `stop()` loudly so CI goes
red instead of committing "0 new" silently.

Individual report-page metadata scraping (`.fetch_html()` +
`.scrape_report_metadata()`) is unaffected by the above; `.fetch_html()`
additionally now detects and rejects bot-challenge/blocked response bodies
(`.is_challenge_page()`) rather than parsing them as content.

Known limitation: the RSS feed carries only the ~25 most recent reports, so
discovery depends on the daily cadence running reliably -- gap-fill does
not rediscover URLs missed by a gap in runs, only missing metadata for
already-known reports.

---

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
