#' gao: A Complete Library of GAO Reports and Metadata
#'
#' A complete library of reports and metadata from the U.S. Government
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
  packageStartupMessage(
    "Please cite the gao package in your work:\n",
    "  Rametta, J. T. (",
    format(Sys.Date(), "%Y"),
    "). gao: A Complete Library of GAO Reports and Metadata.\n",
    "  https://cetialphafive.github.io/gao/"
  )

  tryCatch(.get_curl_bin(), error = function(e) {
    packageStartupMessage(
      "\ngao: curl-impersonate not found.\n",
      "  Downloading reports requires curl-impersonate.\n",
      "  Browsing metadata (gao_links(), auto_download(format = \"metadata\"))\n",
      "  works without it.\n",
      "  Arch Linux: pacman -S curl-impersonate\n",
      "  macOS: brew install lexiforest/curl-impersonate/curl-impersonate\n",
      "  See: https://github.com/lexiforest/curl-impersonate"
    )
  })
}
