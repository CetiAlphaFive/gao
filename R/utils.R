# Package environment for caching
.gao_env <- new.env(parent = emptyenv())

#' Fetch and Parse a URL
#'
#' Uses curl-impersonate to fetch a URL and returns parsed HTML.
#'
#' @param url Character. URL to fetch.
#' @param retries Integer. Number of retry attempts.
#' @return An xml_document from rvest.
#' @importFrom rvest read_html html_nodes html_attr
#' @keywords internal
#' @noRd
.fetch_html <- function(url, retries = 3) {
  curl.bin <- .get_curl_bin()
  for (attempt in seq_len(retries)) {
    html.text <- system2(curl.bin, args = c("-s", "-L", url), stdout = TRUE,
                          stderr = FALSE)
    if (length(html.text) > 0) {
      combined <- paste(html.text, collapse = "\n")
      if (!grepl("Access Denied", combined, fixed = TRUE)) {
        return(rvest::read_html(combined))
      }
    }
    if (attempt < retries) Sys.sleep(2 * attempt)
  }
  stop("Failed to fetch: ", url)
}

#' Download a File
#'
#' Uses curl-impersonate to download a file. Downloads to a temporary file
#' and renames on success to avoid leaving corrupt files on disk.
#'
#' @param url Character. URL to download.
#' @param destfile Character. Destination file path.
#' @return Invisible integer exit code (0 on success).
#' @keywords internal
#' @noRd
.download_file <- function(url, destfile) {
  curl.bin <- .get_curl_bin()
  tmpfile <- paste0(destfile, ".part")
  on.exit(unlink(tmpfile), add = TRUE)
  exit.code <- system2(curl.bin, args = c("-s", "-L", "-o", tmpfile, url))
  if (exit.code != 0) {
    stop("curl failed with exit code ", exit.code, " for: ", url, call. = FALSE)
  }
  if (!file.exists(tmpfile) || file.size(tmpfile) == 0) {
    stop("download produced empty file for: ", url, call. = FALSE)
  }
  file.rename(tmpfile, destfile)
  invisible(0L)
}

#' Download Files in a Loop
#'
#' Shared logic for [download_pdfs()] and [download_htmls()].
#'
#' @param urls Character vector. Full URLs to download.
#' @param destfiles Character vector. Destination file paths.
#' @param sleep_time Numeric. Seconds between downloads.
#' @return Invisible character vector of destination paths.
#' @keywords internal
#' @noRd
.download_files <- function(urls, destfiles, sleep_time = 1) {
  for (i in seq_along(urls)) {
    if (file.exists(destfiles[i])) {
      message("Already exists: ", basename(destfiles[i]))
    } else {
      tryCatch({
        .download_file(urls[i], destfiles[i])
        message("Downloaded: ", basename(destfiles[i]))
      }, error = function(e) {
        message("Failed: ", basename(destfiles[i]), " - ", e$message)
      })
    }
    if (i < length(urls)) Sys.sleep(sleep_time)
    if (i %% 100 == 0) message("Downloaded ", i, " of ", length(urls))
  }
  invisible(destfiles)
}

#' Extract Report Metadata from a Parsed Listing Page
#'
#' Parses structured metadata from each search result on a GAO listing page.
#'
#' @param page An xml_document.
#' @return A data.frame with columns: url, title, report_id, published,
#'   released, summary. URLs are relative paths (e.g., "/products/gao-24-106198").
#' @importFrom rvest html_nodes html_node html_attr html_text
#' @keywords internal
#' @noRd
.scrape_page_links <- function(page) {
  results <- rvest::html_nodes(page, "div.c-search-result")

  if (length(results) == 0L) {
    return(data.frame(
      url = character(0), title = character(0), report_id = character(0),
      published = character(0), released = character(0), summary = character(0),
      topics = character(0), subject_terms = character(0),
      stringsAsFactors = FALSE
    ))
  }

  out <- lapply(results, function(node) {
    header <- rvest::html_node(node, "h4.c-search-result__header a")
    url <- if (!is.na(header)) rvest::html_attr(header, "href") else NA_character_
    title <- if (!is.na(header)) trimws(rvest::html_text(header)) else NA_character_

    id.node <- rvest::html_node(node, "span.d-block.text-small")
    report.id <- if (!is.na(id.node)) trimws(rvest::html_text(id.node)) else NA_character_

    times <- rvest::html_attr(rvest::html_nodes(node, "time[datetime]"), "datetime")
    published <- if (length(times) >= 1L) substr(times[1], 1, 10) else NA_character_
    released <- if (length(times) >= 2L) substr(times[2], 1, 10) else NA_character_

    summary.node <- rvest::html_node(node, "div.c-search-result__summary, div.c-search-result__body")
    summary <- if (!is.na(summary.node)) trimws(rvest::html_text(summary.node)) else NA_character_

    data.frame(url = url, title = title, report_id = report.id,
               published = published, released = released, summary = summary,
               topics = NA_character_, subject_terms = NA_character_,
               stringsAsFactors = FALSE)
  })

  do.call(rbind, out)
}

#' Extract Metadata from a Single GAO Report Page
#'
#' Parses metadata from the HTML of an individual GAO report page (not a
#' listing page). Returns a 1-row data.frame.
#'
#' @param page An xml_document of a single report page.
#' @return A 1-row data.frame with columns: title, report_id, published,
#'   released, summary, topics, subject_terms, has_recommendations,
#'   n_recommendations, has_matters, n_matters, agencies_affected, pdf_url.
#' @importFrom rvest html_node html_nodes html_attr html_text
#' @keywords internal
#' @noRd
.scrape_report_metadata <- function(page) {
  # Title from og:title meta tag
  og.title <- rvest::html_attr(
    rvest::html_node(page, "meta[property='og:title']"), "content"
  )
  title <- if (!is.na(og.title)) sub("^U\\.S\\. GAO - ", "", og.title) else NA_character_

 # Report ID from span.d-block.text-small > strong
  id.node <- rvest::html_node(page, "span.d-block.text-small strong")
  report.id <- if (!is.na(id.node)) trimws(rvest::html_text(id.node)) else NA_character_
  if (!is.na(report.id) && nchar(report.id) == 0L) report.id <- NA_character_

  # Dates from span.d-block.text-small text
  date.nodes <- rvest::html_nodes(page, "span.d-block.text-small")
  date.text <- paste(rvest::html_text(date.nodes), collapse = " ")

  pub.match <- regmatches(date.text, regexpr("Published:\\s*(\\w+ \\d{1,2}, \\d{4})", date.text))
  published <- if (length(pub.match) == 1L) {
    raw <- sub("Published:\\s*", "", pub.match)
    d <- as.Date(raw, format = "%b %d, %Y")
    if (!is.na(d)) format(d, "%Y-%m-%d") else NA_character_
  } else {
    NA_character_
  }

  rel.match <- regmatches(date.text, regexpr("Publicly Released:\\s*(\\w+ \\d{1,2}, \\d{4})", date.text))
  released <- if (length(rel.match) == 1L) {
    raw <- sub("Publicly Released:\\s*", "", rel.match)
    d <- as.Date(raw, format = "%b %d, %Y")
    if (!is.na(d)) format(d, "%Y-%m-%d") else NA_character_
  } else {
    NA_character_
  }

  # Summary from meta description
  summary <- rvest::html_attr(
    rvest::html_node(page, "meta[name='description']"), "content"
  )
  if (!is.na(summary) && nchar(trimws(summary)) == 0L) summary <- NA_character_

  # Topics (modern pages only)
  topic.nodes <- rvest::html_nodes(page, ".views-field-field-topic .field-content a")
  topics <- if (length(topic.nodes) > 0L) {
    paste(trimws(rvest::html_text(topic.nodes)), collapse = "; ")
  } else {
    NA_character_
  }

  # Subject terms (modern pages only)
  subj.nodes <- rvest::html_nodes(page, ".views-field-field-subject-term .field-content span")
  subject.terms <- if (length(subj.nodes) > 0L) {
    paste(trimws(rvest::html_text(subj.nodes)), collapse = "; ")
  } else {
    NA_character_
  }

  # Recommendations for Executive Action
  rec.section <- rvest::html_node(page, "section.view--recommendations--block-1")
  has.recommendations <- !is.na(rec.section)
  if (has.recommendations) {
    rec.cells <- rvest::html_nodes(rec.section, "td.views-field-field-recommendation")
    n.recommendations <- length(rec.cells)
    agency.nodes <- rvest::html_nodes(rec.section, "td.views-field-name")
    agencies <- unique(sort(trimws(rvest::html_text(agency.nodes))))
    agencies <- agencies[nzchar(agencies)]
    agencies.affected <- if (length(agencies) > 0L) paste(agencies, collapse = "; ") else NA_character_
  } else {
    n.recommendations <- 0L
    agencies.affected <- NA_character_
  }

  # Matter for Congressional Consideration
  matter.section <- rvest::html_node(page, "section.view--recommendations--block-3")
  has.matters <- !is.na(matter.section)
  if (has.matters) {
    matter.cells <- rvest::html_nodes(matter.section, "td.views-field-field-recommendation")
    n.matters <- length(matter.cells)
  } else {
    n.matters <- 0L
  }

  # PDF URL from download link on page
  pdf.url <- .extract_pdf_url(page)

  data.frame(
    title = title, report_id = report.id, published = published,
    released = released, summary = summary, topics = topics,
    subject_terms = subject.terms,
    has_recommendations = has.recommendations,
    n_recommendations = as.integer(n.recommendations),
    has_matters = has.matters,
    n_matters = as.integer(n.matters),
    agencies_affected = agencies.affected,
    pdf_url = pdf.url,
    stringsAsFactors = FALSE
  )
}

#' Extract PDF URL from a GAO Report Page
#'
#' Finds the first non-highlights PDF link on the page. Used to get the real
#' download URL for legacy reports where the constructed URL pattern fails.
#'
#' @param page An xml_document of a single report page.
#' @return Character scalar: the PDF URL, or `NA_character_` if none found.
#' @keywords internal
#' @noRd
.extract_pdf_url <- function(page) {
  pdfs <- rvest::html_attr(rvest::html_nodes(page, "a[href$='.pdf']"), "href")
  if (length(pdfs) == 0L) return(NA_character_)
  pdfs <- unique(pdfs[!grepl("highlights", pdfs, ignore.case = TRUE)])
  if (length(pdfs) == 0L) return(NA_character_)
  pdfs[1L]
}

#' Compute Fiscal Year from Date Strings
#'
#' The U.S. federal fiscal year starts October 1. A date in October--December
#' of calendar year Y falls in fiscal year Y+1.
#'
#' @param dates Character vector in YYYY-MM-DD format.
#' @return Integer vector of fiscal years (`NA` where date is missing or
#'   unparseable).
#' @keywords internal
#' @noRd
.fiscal_year <- function(dates) {
  if (length(dates) == 0L) return(integer(0))
  parsed <- as.Date(dates, format = "%Y-%m-%d")
  yr <- as.integer(format(parsed, "%Y"))
  mo <- as.integer(format(parsed, "%m"))
  ifelse(is.na(yr), NA_integer_, ifelse(mo >= 10L, yr + 1L, yr))
}

#' Extract Fiscal Year from GAO URL
#'
#' Parses the 2-digit year from modern GAO product URLs of the form
#' `/products/gao-YY-*` and converts to a 4-digit fiscal year.
#'
#' @param urls Character vector of GAO product URLs.
#' @return Integer vector of fiscal years (`NA_integer_` for URLs that don't
#'   match the modern pattern).
#' @keywords internal
#' @noRd
.fiscal_year_from_url <- function(urls) {
  m <- regmatches(urls, regexpr("gao-([0-9]{2})-", urls))
  yy <- suppressWarnings(as.integer(sub("gao-([0-9]{2})-", "\\1", m)))
  yy[lengths(regmatches(urls, regexpr("gao-([0-9]{2})-", urls))) == 0L] <- NA_integer_
  # 00-49 -> 2000-2049, 50-99 -> 1950-1999
  ifelse(is.na(yy), NA_integer_, ifelse(yy <= 49L, 2000L + yy, 1900L + yy))
}

#' Infer Fiscal Year from Date or URL
#'
#' Uses the published date when available (via [.fiscal_year()]), falling back
#' to the URL-encoded year (via [.fiscal_year_from_url()]) when `published` is
#' `NA`.
#'
#' @param dates Character vector of dates in YYYY-MM-DD format.
#' @param urls Character vector of GAO product URLs (same length as `dates`).
#' @return Integer vector of fiscal years.
#' @keywords internal
#' @noRd
.infer_fiscal_year <- function(dates, urls) {
  fy.date <- .fiscal_year(dates)
  fy.url <- .fiscal_year_from_url(urls)
  ifelse(is.na(fy.date), fy.url, fy.date)
}

#' Get curl-impersonate Binary
#'
#' Returns the path to the curl-impersonate binary. Users can override with
#' `options(gao.curl_bin = "curl_chrome145")`. Caches the result to avoid
#' repeated `Sys.which()` calls.
#'
#' @return Character. Name or path to curl-impersonate binary.
#' @keywords internal
#' @noRd
.get_curl_bin <- function() {
  bin <- getOption("gao.curl_bin", "curl_firefox147")
  if (!identical(bin, .gao_env$curl_bin)) {
    if (nchar(Sys.which(bin)) == 0) {
      stop(
        "curl-impersonate not found on your system.\n",
        "GAO.gov requires browser-like TLS fingerprints.\n",
        "Install curl-impersonate: https://github.com/lexiforest/curl-impersonate\n",
        "  Arch Linux: pacman -S curl-impersonate\n",
        "  macOS: brew install lexiforest/curl-impersonate/curl-impersonate\n",
        "Set a different binary with: options(gao.curl_bin = \"curl_chrome145\")",
        call. = FALSE
      )
    }
    .gao_env$curl_bin <- bin
  }
  .gao_env$curl_bin
}
