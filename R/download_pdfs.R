#' Download GAO PDF Reports
#'
#' Downloads PDF files from extracted PDF links.
#'
#' @param pdf_links Character vector. PDF paths as returned by
#'   [extract_pdf_links()] (relative paths like `"/assets/gao-24-106198.pdf"`
#'   or full URLs).
#' @param download_dir Character. Directory to save PDFs (default: working directory).
#' @param sleep_time Numeric. Seconds to pause between downloads (default: 1).
#'
#' @return Invisible character vector of downloaded file paths.
#' @export
#' @examples
#' \donttest{
#' download_pdfs("/assets/gao-24-106198.pdf", download_dir = tempdir())
#' }
download_pdfs <- function(pdf_links,
                          download_dir = getwd(),
                          sleep_time = 1) {
  if (!is.character(pdf_links)) {
    stop("pdf_links must be a character vector", call. = FALSE)
  }
  if (!dir.exists(download_dir)) dir.create(download_dir, recursive = TRUE)

  # Resolve full URLs
  urls <- ifelse(grepl("^https?://", pdf_links),
                 pdf_links,
                 paste0("https://www.gao.gov", pdf_links))
  destfiles <- file.path(download_dir, basename(pdf_links))

  .download_files(urls, destfiles, sleep_time)
}
