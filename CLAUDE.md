# CLAUDE.md — GAO / Republican Revolution

## Project Overview

**Title:** Did the Republican Revolution Hamstring Congressional
Oversight? Evidence from 55,000 GAO Reports **Author:** Jack Rametta
(solo) **Status:** Revising (back from review) **Presented:** MPSA 2024

An R package (`gao`) for automated harvesting and processing of
Government Accountability Office reports, plus the accompanying research
paper analyzing congressional oversight patterns.

## Key Directories

- `R/` — Package source code (web scraping, PDF/HTML downloading)
- `man/` — R documentation

## Tools & Packages

R package using `rvest` (scraping), `furrr`/`future` (parallel
processing), `httr` (HTTP requests).

------------------------------------------------------------------------

## Chief of Staff Integration

The canonical project tracker lives at
`~/Dropbox/chief_of_staff/CHIEF_OF_STAFF.md`.

### “update COS” command

When Jack says **“update COS”** at the end of a session:

1.  Write a brief status update (2-4 lines max) summarizing:
    - What was accomplished this session
    - What changed (status shifts, blockers added/removed)
    - What the next action is
2.  Append it to the `## Raw Updates` section at the bottom of
    `~/Dropbox/chief_of_staff/CHIEF_OF_STAFF.md` using this format:

&nbsp;

    [YYYY-MM-DD] GAO — Accomplished: [what]. Changed: [what]. Next: [what].

3.  Confirm to Jack that the update was appended.

**Do not** read, parse, or reorganize the rest of the state file. Just
append. The CoS agent handles integration.
