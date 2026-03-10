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

#' Extract Report Links from a Parsed Page
#'
#' @param page An xml_document.
#' @return Character vector of relative report paths (e.g., "/products/gao-24-106198").
#' @keywords internal
#' @noRd
.scrape_page_links <- function(page) {
  hrefs <- rvest::html_attr(rvest::html_nodes(page, "a"), "href")
  hrefs[grep("/products/", hrefs)]
}

#' Extract Fiscal Year from GAO URLs
#'
#' Parses two-digit year codes from GAO report IDs (e.g., `gao-24-106198`).
#' Uses a 50-year pivot: YY >= 50 maps to 19YY, YY < 50 maps to 20YY.
#'
#' @param urls Character vector. GAO report URLs or IDs.
#' @return Integer vector of fiscal years (`NA` for non-matching URLs).
#' @keywords internal
#' @noRd
.extract_gao_year <- function(urls) {
  if (length(urls) == 0L) return(integer(0))
  ids <- basename(urls)
  has.year <- grepl("^[a-z]+-[0-9]{2}-", ids)
  yy <- rep(NA_integer_, length(ids))
  yy[has.year] <- as.integer(sub("^[a-z]+-([0-9]{2})-.*", "\\1", ids[has.year]))
  ifelse(is.na(yy), NA_integer_, ifelse(yy >= 50L, 1900L + yy, 2000L + yy))
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
