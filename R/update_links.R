#' Parse GAO RSS Feed XML into a data.frame
#'
#' Pure parsing step (no network I/O) so it is unit-testable with an inline
#' XML fixture. Extracts `link`/`title`/`pubDate` from each `<item>`,
#' normalizes the link by stripping any query string, and converts
#' `pubDate` to an ISO date. Errors loudly on unparseable XML or a feed with
#' no usable items, rather than returning an empty/partial result silently
#' -- this is what makes a broken feed fail CI instead of committing
#' "0 new" every day.
#'
#' @param xml_text Character scalar. Raw RSS XML.
#' @return A data.frame with columns `url` (normalized, query string
#'   stripped), `title`, `published` (ISO `"YYYY-MM-DD"`, `NA` if
#'   `<pubDate>` is missing or unparseable), `report_id` (derived from the
#'   url's `/products/<id>` tail, upper-cased, e.g. `"GAO-26-109098"`; `NA`
#'   if the url does not match that pattern -- a fallback so `report_id` is
#'   populated even if the later per-page metadata scrape fails).
#' @keywords internal
#' @noRd
.parse_rss <- function(xml_text) {
  .require_xml2()
  .rss_error <- function() {
    stop("GAO RSS feed unreachable or returned no items -- ",
         "feed URL or format may have changed", call. = FALSE)
  }

  doc <- tryCatch(xml2::read_xml(xml_text), error = function(e) NULL)
  if (is.null(doc)) .rss_error()

  items <- xml2::xml_find_all(doc, ".//item")
  if (length(items) == 0L) .rss_error()

  link    <- trimws(xml2::xml_text(xml2::xml_find_first(items, "link")))
  title   <- trimws(xml2::xml_text(xml2::xml_find_first(items, "title")))
  pub.raw <- xml2::xml_text(xml2::xml_find_first(items, "pubDate"))

  # Query-string stripping happens first so a tracking/challenge suffix
  # (e.g. "?bm-verify=...") can never leak into the report_id derived below.
  url <- sub("\\?.*$", "", link)
  published <- vapply(pub.raw, .parse_rfc822_date, character(1), USE.NAMES = FALSE)

  # report_id fallback: derive from the url's "/products/<id>" tail rather
  # than blindly upper-casing the whole url, so non-product urls (or urls
  # that don't match this shape) correctly yield NA instead of garbage.
  report_id <- vapply(seq_along(url), function(i) {
    m <- regmatches(url[i], regexpr("(?<=/products/)[^/]+$", url[i], perl = TRUE))
    if (length(m) == 1L && nzchar(m)) toupper(m) else NA_character_
  }, character(1))

  # nzchar(NA) is TRUE by default (NA treated as nonzero-length), so an item
  # with no <link> node (url = NA, from xml2's "missing" placeholder) must be
  # excluded explicitly rather than relying on nzchar() alone.
  keep <- !is.na(url) & nzchar(url)
  out <- data.frame(url = url[keep], title = title[keep],
                     published = published[keep],
                     report_id = report_id[keep], stringsAsFactors = FALSE)
  if (nrow(out) == 0L) .rss_error()
  out
}

#' Fetch and Parse the GAO RSS Feed
#'
#' Fetches the GAO "reports and testimonies" RSS feed via curl-impersonate
#' (same mechanism as [.fetch_html()]) and parses it with [.parse_rss()].
#' New-report discovery uses this feed instead of the paginated HTML
#' listing page, which is now behind an Akamai Bot Manager JS challenge
#' (`bm-verify`) that curl-impersonate -- a TLS-fingerprint spoofer, not a
#' JS engine -- cannot solve.
#'
#' @param url Character. RSS feed URL.
#' @param retries Integer. Number of retry attempts.
#' @return A data.frame; see [.parse_rss()].
#' @keywords internal
#' @noRd
.fetch_rss_links <- function(url = "https://www.gao.gov/rss/reports.xml",
                             retries = 3) {
  .require_xml2()
  curl.bin <- .get_curl_bin()
  for (attempt in seq_len(retries)) {
    rss.text <- suppressWarnings(
      system2(curl.bin, args = c("-s", "-S", "-f", "-L", url),
              stdout = TRUE, stderr = FALSE))
    status <- attr(rss.text, "status")
    ok <- (is.null(status) || identical(as.integer(status), 0L)) &&
      length(rss.text) > 0L
    if (ok) {
      return(.parse_rss(paste(rss.text, collapse = "\n")))
    }
    if (attempt < retries) Sys.sleep(2 * attempt)
  }
  stop("GAO RSS feed unreachable or returned no items -- ",
       "feed URL or format may have changed", call. = FALSE)
}

#' Update GAO Report Links
#'
#' Fetches the GAO RSS feed and appends any new links not already in the
#' bundled dataset. Used by the daily CI workflow; most users should use
#' [gao_links()] to access the bundled dataset.
#'
#' New-report discovery is RSS-based ([.fetch_rss_links()]), not the
#' paginated HTML listing: gao.gov now gates that page behind a JS bot
#' challenge that curl-impersonate cannot solve, while individual report
#' pages and the RSS feed remain reachable. The RSS feed carries only the
#' ~25 most recent items, so this function can only discover reports still
#' within that window -- it depends on the daily cadence running reliably;
#' it does not retroactively rediscover URLs missed by a gap in runs (see
#' NEWS.md).
#'
#' @param verbose Logical. Show progress messages (default: `TRUE`).
#' @param sleep_time Numeric. Unused; retained for call-site compatibility
#'   with the daily CI workflow (default: 1).
#'
#' @return A data.frame of all known reports (old + new), sorted by url.
#' @keywords internal
#' @noRd
update_links <- function(verbose = TRUE, sleep_time = 1) {
  .gao_env$links <- NULL
  known <- gao_links()
  if (verbose) message("Bundled reports: ", nrow(known))

  # LOUD FAILURE: .fetch_rss_links()/.parse_rss() stop() on a fetch failure,
  # an empty feed, or a feed with 0 parseable items, so a broken feed makes
  # this (and the CI job that calls it) fail rather than silently reporting
  # "0 new" forever.
  rss <- .fetch_rss_links()
  if (verbose) message("RSS feed items: ", nrow(rss))

  new.data <- rss[!rss$url %in% known$url, , drop = FALSE]

  if (nrow(new.data) > 0) {
    # Ensure consistent columns in both directions
    for (col in setdiff(names(new.data), names(known))) {
      known[[col]] <- NA_character_
    }
    for (col in setdiff(names(known), names(new.data))) {
      new.data[[col]] <- NA
    }
    combined <- rbind(known, new.data[, names(known), drop = FALSE])
  } else {
    combined <- known
  }

  if (verbose) message("New reports found: ", nrow(combined) - nrow(known))

  # Derived covariates (indicators + features) are intentionally recomputed
  # on-the-fly by gao_links()/.ensure_expanded() and are not persisted here.
  combined <- combined[!duplicated(combined$url), , drop = FALSE]
  combined <- combined[order(combined$url), , drop = FALSE]
  rownames(combined) <- NULL
  combined
}

#' Ensure a report frame carries current derived columns
#'
#' Idempotent, version-gated expansion: returns `d` unchanged if it already has
#' the derived columns AND its stamped schema version matches
#' [.gao_schema_version()]. Otherwise drops any stale derived columns and
#' recomputes them from the base columns via [.expand_indicators()] and
#' [.expand_features()].
#'
#' @param d A data.frame of report metadata (base columns required).
#' @return `d` with a current, fully-derived column set.
#' @keywords internal
#' @noRd
.ensure_expanded <- function(d) {
  derived_present <- "agency_other" %in% names(d) &&
    "issuing_division" %in% names(d)
  current <- identical(attr(d, "gao_schema_version"), .gao_schema_version())
  if (derived_present && current) return(d)

  # Drop any stale derived columns, then recompute from the base columns.
  drop <- c(.indicator_colnames(),
            "issuing_division", "product_type", "pub_month", "pub_dow",
            "pub_fiscal_year", "fiscal_quarter", "election_year",
            "release_lag_days", "n_topics", "n_subject_terms",
            "requester_party", "requester_majority_status",
            "requester_chamber", "requester_bipartisan")
  d <- d[, setdiff(names(d), drop), drop = FALSE]
  if (!"requester_type" %in% names(d)) {
    d$requester_type <- NA_character_
    d$requester_committees <- NA_character_
    d$requester_members <- NA_character_
  }
  d <- .expand_indicators(d)
  d <- .expand_features(d)   # stamps gao_schema_version
  d
}

#' Get GAO Report Data
#'
#' Returns the full GAO report dataset as a data.frame: one row per report,
#' with metadata from gao.gov plus ready-made indicator and covariate
#' columns for analysis. The newest data available locally is used: the
#' cache written by [gao_update_data()] if present, otherwise the dataset
#' bundled with the package. The result is kept in memory, so repeated
#' calls are fast.
#'
#' @return A data.frame with one row per GAO report and three groups of
#'   columns:
#'
#'   **Core metadata:** `url`, `title`, `report_id`, `published`,
#'   `released`, `summary`, `page_count` (`NA` when no PDF is available),
#'   `topics`, `subject_terms`, `agencies_affected` (semicolon-separated),
#'   `has_recommendations` / `n_recommendations`, `has_matters` /
#'   `n_matters`, `requester_type` (`"congressional_request"`,
#'   `"statutory_mandate"`, `"cg_initiated"`, `"testimony"`,
#'   `"correspondence"`, or `"legal_decision"`), `requester_committees`,
#'   and `requester_members` (semicolon-separated).
#'
#'   **Indicator columns** (0/1): 31 `topic_*` columns, 50 `agency_*`
#'   columns for the most frequently reviewed agencies, plus
#'   `agency_other`. Matching is exact per semicolon-delimited item;
#'   indicators are `NA` where the source field is missing.
#'
#'   **Derived covariates:** `issuing_division` (the GAO unit decoded from
#'   the report ID; `NA` for old numeric IDs), `product_type` (`"report"`,
#'   `"testimony"`, `"correspondence"`, `"legal_decision"`, or
#'   `"legal_other"`), `pub_month`, `pub_dow` (1 = Monday),
#'   `pub_fiscal_year` and `fiscal_quarter` (federal fiscal year, which
#'   starts in October), `election_year`, `release_lag_days`, `n_topics`,
#'   `n_subject_terms`, and requester party covariates `requester_party`
#'   (`"R"`, `"D"`, `"Other"`, `"mixed"`, or `NA`),
#'   `requester_majority_status`, `requester_chamber`, and
#'   `requester_bipartisan`. Party covariates are resolved by matching
#'   requester names against congressional membership data from
#'   [Voteview](https://voteview.com/) for the Congress active at
#'   publication; they are populated only for reports that name individual
#'   members of Congress as requesters.
#' @export
#' @examples
#' reports <- gao_links()
#' nrow(reports)
#' head(reports)
gao_links <- function() {
  if (!is.null(.gao_env$links)) return(.gao_env$links)

  # Check user-local cache first (from gao_update_data())
  cache.dir <- tools::R_user_dir("gao", "data")
  cache.path <- file.path(cache.dir, "gao_links.rds")

  if (file.exists(cache.path)) {
    path <- cache.path
  } else {
    path <- system.file("extdata", "gao_links.rds", package = "gao")
  }

  if (path == "") {
    warning("No bundled link data found. Reinstall the package.",
            call. = FALSE)
    empty <- data.frame(
      url = character(0), title = character(0), report_id = character(0),
      published = character(0), released = character(0), summary = character(0),
      page_count = integer(0), topics = character(0),
      subject_terms = character(0),
      has_recommendations = logical(0), n_recommendations = integer(0),
      has_matters = logical(0), n_matters = integer(0),
      agencies_affected = character(0),
      requester_type = character(0),
      requester_committees = character(0),
      requester_members = character(0),
      stringsAsFactors = FALSE
    )
    # Give the fallback the full derived schema so it matches a normal return.
    # Both expanders handle 0-row frames.
    empty <- .expand_indicators(empty)
    empty <- .expand_features(empty)
    return(empty)
  }

  d <- readRDS(path)
  # Add requester columns and derived covariates (indicators, division, product
  # type, temporal, requester party) on the fly, version-gated so a frame that
  # is already fully derived at the current schema is returned unchanged.
  d <- .ensure_expanded(d)
  .gao_env$links <- d
  d
}

#' Download Updated GAO Report Data
#'
#' Downloads the latest `gao_links.rds` from the package's GitHub
#' Releases and caches it locally. Subsequent calls to [gao_links()]
#' will use the updated data. Uses base R [download.file()] -- no
#' `curl-impersonate` needed.
#'
#' @param quiet Logical. Suppress progress messages (default: `FALSE`).
#' @return Invisible path to the cached RDS file.
#' @export
#' @examples
#' \dontrun{
#' gao_update_data()
#' gao_links()  # now returns the latest data
#' }
gao_update_data <- function(quiet = FALSE) {
  release.url <- "https://github.com/CetiAlphaFive/gao/releases/download/data-latest/gao_links.rds"
  cache.dir <- tools::R_user_dir("gao", "data")
  if (!dir.exists(cache.dir)) dir.create(cache.dir, recursive = TRUE)
  cache.path <- file.path(cache.dir, "gao_links.rds")

  if (!quiet) message("Downloading latest GAO data...")
  tmp <- tempfile(fileext = ".rds")
  on.exit(unlink(tmp), add = TRUE)

  status <- utils::download.file(release.url, tmp, mode = "wb",
                                 quiet = quiet)
  if (status != 0L) stop("Download failed (status ", status, ")", call. = FALSE)

  # Validate the download is a readable RDS with the required base columns.
  obj <- tryCatch(readRDS(tmp), error = function(e) {
    stop("Downloaded file is not a valid RDS: ", e$message, call. = FALSE)
  })
  if (!all(c("url", "report_id", "published") %in% names(obj))) {
    stop("Downloaded file is missing required columns", call. = FALSE)
  }

  file.copy(tmp, cache.path, overwrite = TRUE)
  .gao_env$links <- NULL
  if (!quiet) message("Updated data cached at ", cache.path)
  invisible(cache.path)
}
