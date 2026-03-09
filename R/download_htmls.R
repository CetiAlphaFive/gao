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

  if (!dir.exists(target_directory)) {
    dir.create(target_directory, recursive = TRUE)
  }

  downloaded <- character(0)

  for (i in seq_along(links)) {
    file.name <- paste0(basename(links[i]), ".html")
    destfile <- file.path(target_directory, file.name)

    if (file.exists(destfile)) {
      message("Already exists: ", file.name)
    } else {
      tryCatch({
        .download_file(links[i], destfile)
        message("Downloaded: ", file.name)
      }, error = function(e) {
        message("Failed: ", file.name, " — ", e$message)
      })
    }

    downloaded <- c(downloaded, destfile)
    if (i < length(links)) Sys.sleep(sleep_time)
    if (i %% 100 == 0) message("Downloaded ", i, " of ", length(links))
  }

  invisible(downloaded)
}
