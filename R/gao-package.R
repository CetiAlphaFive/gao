#' @keywords internal
"_PACKAGE"

.onAttach <- function(libname, pkgname) {
  bin <- getOption("gao.curl_bin", "curl_firefox147")
  if (nchar(Sys.which(bin)) == 0) {
    packageStartupMessage(
      "gao: curl-impersonate not found. Install it before using this package.\n",
      "  Arch Linux: pacman -S curl-impersonate\n",
      "  macOS: brew install lexiforest/curl-impersonate/curl-impersonate\n",
      "  See: https://github.com/lexiforest/curl-impersonate"
    )
  }
}
