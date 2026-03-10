#' gao: Harvest Government Accountability Office Reports
#'
#' Tools for harvesting reports published by the U.S. Government
#' Accountability Office (GAO). Ships with a bundled dataset of all GAO
#' report URLs and provides functions for downloading reports as PDF or HTML.
#'
#' This package is not affiliated with or endorsed by the U.S. Government
#' Accountability Office. All data is obtained from public web pages at
#' \url{https://www.gao.gov}.
#'
#' @section System requirements:
#' Requires \href{https://github.com/lexiforest/curl-impersonate}{curl-impersonate}
#' to be installed. GAO.gov uses TLS fingerprint filtering that blocks
#' standard HTTP clients.
#'
#' @keywords internal
"_PACKAGE"

.onAttach <- function(libname, pkgname) {
  tryCatch(.get_curl_bin(), error = function(e) {
    packageStartupMessage(
      "gao: curl-impersonate not found. Install it before using this package.\n",
      "  Arch Linux: pacman -S curl-impersonate\n",
      "  macOS: brew install lexiforest/curl-impersonate/curl-impersonate\n",
      "  See: https://github.com/lexiforest/curl-impersonate"
    )
  })
}
