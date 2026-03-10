#' Download GAO Report HTML Pages
#'
#' Downloads HTML files from a list of GAO report URLs.
#'
#' @param links Character vector. Full URLs of GAO report pages.
#' @param target_directory Character. Directory to save HTML files (default: working directory).
#' @param sleep_time Numeric. Seconds to pause between downloads (default: 1).
#'
#' @return Invisible character vector of downloaded file paths.
#' @export
#' @examples
#' \dontrun{
#' download_htmls(links, target_directory = "gao_htmls")
#' }
download_htmls <- function(links,
                           target_directory = getwd(),
                           sleep_time = 1) {
  if (!is.character(links)) {
    stop("links must be a character vector", call. = FALSE)
  }
  if (!dir.exists(target_directory)) dir.create(target_directory, recursive = TRUE)

  destfiles <- file.path(target_directory, paste0(basename(links), ".html"))
  .download_files(links, destfiles, sleep_time)
}
