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
               stringsAsFactors = FALSE)
  })

  do.call(rbind, out)
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
