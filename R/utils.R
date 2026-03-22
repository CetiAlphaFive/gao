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

  # Requester info from highlights subtitle + report ID
  hl.info <- .parse_highlights_subtitle(page)
  id.type <- .classify_report_type(report.id)
  req.type <- if (!is.na(id.type)) id.type else hl.info$requester_type

  data.frame(
    title = title, report_id = report.id, published = published,
    released = released, summary = summary, topics = topics,
    subject_terms = subject.terms,
    has_recommendations = has.recommendations,
    n_recommendations = as.integer(n.recommendations),
    has_matters = has.matters,
    n_matters = as.integer(n.matters),
    agencies_affected = agencies.affected,
    requester_type = req.type,
    requester_committees = hl.info$requester_committees,
    requester_members = hl.info$requester_members,
    pdf_url = pdf.url,
    stringsAsFactors = FALSE
  )
}

#' Extract Requester Info from All Sources
#'
#' Orchestrates requester parsing by merging report ID classification,
#' highlights subtitle, and (optionally) the addressee block from the
#' report letter text. Used by the backfill script when both product page
#' HTML and report text are available.
#'
#' @param page An xml_document of a GAO product page (or `NULL`).
#' @param report_id Character scalar. The report ID.
#' @param report_text Character scalar. Full text from the report PDF or
#'   HTML (optional; `NULL` to skip addressee block parsing).
#' @return A list with elements `requester_type`, `requester_committees`,
#'   `requester_members`.
#' @keywords internal
#' @noRd
.extract_requester_info <- function(page, report_id, report_text = NULL) {
  # Source 1: ID-based classification (highest priority for type)
  id.type <- .classify_report_type(report_id)

  # Source 2: Highlights subtitle (from product page)
  if (!is.null(page)) {
    hl <- .parse_highlights_subtitle(page)
  } else {
    hl <- list(requester_type = NA_character_,
               requester_committees = NA_character_,
               requester_members = NA_character_)
  }

  # Source 3: Addressee block (from report body text)
  if (!is.null(report_text) && !is.na(report_text) && nzchar(report_text)) {
    ab <- .parse_addressee_block(report_text)
  } else {
    ab <- list(requester_type = NA_character_,
               requester_committees = NA_character_,
               requester_members = NA_character_)
  }

  # Merge with priority: ID type > addressee type > highlights type
  req.type <- id.type
  if (is.na(req.type)) req.type <- ab$requester_type
  if (is.na(req.type)) req.type <- hl$requester_type

  # Committees: addressee block > highlights (richer data)
  req.committees <- ab$requester_committees
  if (is.na(req.committees)) req.committees <- hl$requester_committees

  # Members: addressee block only (highlights rarely has full names)
  req.members <- ab$requester_members
  if (is.na(req.members)) req.members <- hl$requester_members

  list(requester_type = req.type,
       requester_committees = req.committees,
       requester_members = req.members)
}

#' Classify Report Type from Report ID
#'
#' Determines `requester_type` from the report ID format alone. Testimony,
#' legal decisions, and correspondence have distinctive ID patterns.
#'
#' @param report_id Character vector of report IDs (e.g., `"GAO-24-106335"`,
#'   `"B-100063"`, `"T-AFMD-87-1"`).
#' @return Character vector: `"testimony"`, `"legal_decision"`,
#'   `"correspondence"`, or `NA_character_`.
#' @keywords internal
#' @noRd
.classify_report_type <- function(report_id) {
  if (length(report_id) == 0L) return(character(0))
  id <- as.character(report_id)
  type <- rep(NA_character_, length(id))
  # Testimony: T- prefix (legacy, e.g. T-AFMD-87-1) or ends in T (modern, e.g. GAO-24-107436T)
  type[grepl("^T-", id) | grepl("^GAO-\\d{2}-\\d+T$", id)] <- "testimony"
  # Legal decision: B- prefix (e.g. B-422122)
  type[is.na(type) & grepl("^B-", id)] <- "legal_decision"
  # Correspondence: ends in digit(s)+R (excludes BR, TR, PR since those have a letter before R)
  type[is.na(type) & grepl("\\d+R$", id)] <- "correspondence"
  type
}

#' Parse Addressee Text from Highlights Subtitle
#'
#' Parses the addressee portion of a highlights subtitle string (everything
#' after "a report to"). Returns requester type, committee names, and member
#' names.
#'
#' @param text Character scalar. The addressee portion, e.g.
#'   `"the Ranking Member, Committee on Homeland Security and Governmental
#'   Affairs, U.S. Senate"` or `"congressional requesters"`.
#' @return A list with elements `requester_type`, `requester_committees`,
#'   `requester_members` (each `NA_character_` if not identifiable).
#' @keywords internal
#' @noRd
.parse_subtitle_addressee <- function(text) {
  if (is.na(text) || !nzchar(trimws(text))) {
    return(list(requester_type = NA_character_,
                requester_committees = NA_character_,
                requester_members = NA_character_))
  }

  text <- trimws(text)

  # "congressional addressees" → statutory mandate (always mandated by law)
  if (tolower(text) == "congressional addressees") {
    return(list(requester_type = "statutory_mandate",
                requester_committees = NA_character_,
                requester_members = NA_character_))
  }

  # "congressional requesters" → congressional request but no specific committee
  if (tolower(text) == "congressional requesters") {
    return(list(requester_type = "congressional_request",
                requester_committees = NA_character_,
                requester_members = NA_character_))
  }

  # "congressional committees" → could be either; default to congressional_request.
  # The backfill script checks "Why GAO Did This Study" for mandate language to override.
  if (tolower(text) == "congressional committees") {
    return(list(requester_type = "congressional_request",
                requester_committees = NA_character_,
                requester_members = NA_character_))
  }

  # Specific addressee: parse committee and role
  # Patterns like:
  #   "the Ranking Member, Committee on X, U.S. Senate"
  #   "the Committee on X, House of Representatives"
  #   "the Chairman, Committee on X, U.S. Senate"

  # Normalize chamber names for extraction
  chamber.map <- c(
    "U.S. Senate" = "Senate",
    "United States Senate" = "Senate",
    "House of Representatives" = "House"
  )

  # Extract committee names with their chambers
  committees <- character(0)
  members <- character(0)

  # Try to extract committee + chamber pairs
  # Pattern: "Committee on [Name], [Chamber]" or "Subcommittee on [Name], [Chamber]"
  committee.pattern <- "((?:Committee|Subcommittee) on [^,]+),\\s*(U\\.S\\. Senate|United States Senate|House of Representatives)"
  m <- gregexpr(committee.pattern, text, perl = TRUE)
  matches <- regmatches(text, m)[[1]]

  if (length(matches) > 0) {
    for (match in matches) {
      parts <- regmatches(match, regexec(committee.pattern, match, perl = TRUE))[[1]]
      committee.name <- trimws(parts[2])
      chamber <- chamber.map[parts[3]]
      committees <- c(committees, paste0(committee.name, " (", chamber, ")"))
    }
  }

  # Extract role (Chairman, Ranking Member, etc.) if present
  role.pattern <- "the\\s+(Chairman|Chairwoman|Chair|Ranking Member|Vice Chair(?:man|woman)?)"
  role.match <- regmatches(text, regexec(role.pattern, text, perl = TRUE))[[1]]
  if (length(role.match) > 1) {
    members <- role.match[2]  # Just the role, no name in subtitle
  }

  req.type <- "congressional_request"
  req.committees <- if (length(committees) > 0) paste(committees, collapse = "; ") else NA_character_
  req.members <- if (length(members) > 0) paste(members, collapse = "; ") else NA_character_


  list(requester_type = req.type,
       requester_committees = req.committees,
       requester_members = req.members)
}

#' Parse Highlights Subtitle from a GAO Product Page
#'
#' Extracts the "Highlights of GAO-XX-XXXXXX, a report to ..." subtitle from
#' the product page HTML and parses the addressee information.
#'
#' @param page An xml_document of a single GAO product page.
#' @return A list with elements `requester_type`, `requester_committees`,
#'   `requester_members` (each `NA_character_` if not found).
#' @keywords internal
#' @noRd
.parse_highlights_subtitle <- function(page) {
  na.result <- list(requester_type = NA_character_,
                    requester_committees = NA_character_,
                    requester_members = NA_character_)

  # The highlights content lives in the field__item div inside the highlights block
  hl.node <- rvest::html_node(page, "div.js-endpoint-highlights .field__item")
  if (is.na(hl.node)) {
    # Fallback selector
    hl.node <- rvest::html_node(page, ".field--name-product-highlights-custom .field__item")
  }
  if (is.na(hl.node)) return(na.result)

  hl.text <- rvest::html_text(hl.node)
  if (is.na(hl.text) || !nzchar(trimws(hl.text))) return(na.result)

  # Collapse whitespace (newlines, tabs, multiple spaces) into single spaces
  # so the regex can match across line breaks in the HTML text
  hl.text <- gsub("\\s+", " ", hl.text)

  # Find the subtitle: "Highlights of [ID], a [report/letter/testimony] to [addressee]"
  # The subtitle appears before "What GAO Found"
  subtitle.pattern <- "Highlights\\s+of\\s+[A-Z0-9][A-Z0-9-]+,\\s*a\\s+(?:report|letter|testimony)\\s+to\\s+(.+?)(?=\\s*What GAO|\\s*$)"
  m <- regmatches(hl.text, regexec(subtitle.pattern, hl.text, perl = TRUE))[[1]]

  if (length(m) < 2) return(na.result)

  addressee.text <- trimws(m[2])
  # Clean trailing period or whitespace
  addressee.text <- sub("\\.$", "", addressee.text)

  .parse_subtitle_addressee(addressee.text)
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
