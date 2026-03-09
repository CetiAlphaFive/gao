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
#' \dontrun{
#' download_pdfs(pdf_links, download_dir = "gao_pdfs")
#' }
download_pdfs <- function(pdf_links,
                          download_dir = getwd(),
                          sleep_time = 1) {

  if (!dir.exists(download_dir)) {
    dir.create(download_dir, recursive = TRUE)
  }

  downloaded <- character(0)

  for (i in seq_along(pdf_links)) {
    # Handle both relative and absolute URLs
    if (grepl("^https?://", pdf_links[i])) {
      full.url <- pdf_links[i]
    } else {
      full.url <- paste0("https://www.gao.gov", pdf_links[i])
    }

    file.name <- basename(pdf_links[i])
    destfile <- file.path(download_dir, file.name)

    if (file.exists(destfile)) {
      message("Already exists: ", file.name)
    } else {
      result <- tryCatch({
        .download_file(full.url, destfile)
        message("Downloaded: ", file.name)
        0L
      }, error = function(e) {
        message("Failed: ", file.name, " — ", e$message)
        1L
      })
    }

    downloaded <- c(downloaded, destfile)
    if (i < length(pdf_links)) Sys.sleep(sleep_time)
    if (i %% 100 == 0) message("Downloaded ", i, " of ", length(pdf_links))
  }

  invisible(downloaded)
}
