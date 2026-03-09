#' Fetch and Parse a URL
#'
#' Uses curl-impersonate to fetch a URL and returns parsed HTML.
#'
#' @param url Character. URL to fetch.
#' @return An xml_document from rvest.
#' @keywords internal
#' @noRd
.fetch_html <- function(url) {
  curl.bin <- .get_curl_bin()
  html.text <- system2(curl.bin, args = c("-s", "-L", url), stdout = TRUE,
                        stderr = FALSE)
  if (length(html.text) == 0) {
    stop("Failed to fetch: ", url)
  }
  rvest::read_html(paste(html.text, collapse = "\n"))
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
