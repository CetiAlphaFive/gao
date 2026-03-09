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
#' Uses curl-impersonate to download a file.
#'
#' @param url Character. URL to download.
#' @param destfile Character. Destination file path.
#' @return Exit code from system2 (invisible).
#' @keywords internal
#' @noRd
.download_file <- function(url, destfile) {
  curl.bin <- .get_curl_bin()
  invisible(system2(curl.bin, args = c("-s", "-L", "-o", destfile, url)))
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

#' Get curl-impersonate Binary
#'
#' Returns the path to the curl-impersonate binary. Users can override with
#' `options(gao.curl_bin = "curl_chrome145")`.
#'
#' @return Character. Name or path to curl-impersonate binary.
#' @keywords internal
#' @noRd
.get_curl_bin <- function() {
  bin <- getOption("gao.curl_bin", "curl_firefox147")
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
  bin
}
