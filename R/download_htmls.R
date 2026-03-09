#' Download GAO Report HTMLs
#'
#' This function downloads HTML files from a list of GAO report URLs, saving them
#' to a specified directory. It runs in parallel using available cores and provides progress updates.
#'
#' @param links A vector of URLs to download.
#' @param target_directory A directory where the HTML files will be saved.
#' @param workers Number of workers to use for parallel processing (default: all cores - 2).
#' @return Invisible list of download results. Called for side effect of downloading HTML files.
#' @import furrr future httr
#' @importFrom stats runif
#' @export
download_htmls <- function(links, target_directory = getwd(), workers = parallel::detectCores() - 2) {
  # Ensure target directory exists
  if (!dir.exists(target_directory)) {
    dir.create(target_directory, recursive = TRUE)
  }

  # Define the download function
  download_url <- function(url) {
    # Extract the file name from the URL and append .html
    file_name <- file.path(target_directory, paste0(basename(url), ".html"))

    # Check if file already exists
    if (!file.exists(file_name)) {
      tryCatch({
        response <- httr::GET(url, httr::user_agent("Mozilla/5.0"))
        # Check for a successful response
        if (response$status_code == 200) {
          write(httr::content(response, "text"), file_name)
          message(paste("Successfully downloaded:", url))
        } else {
          message(paste("Failed to download:", url, "\nStatus:", response$status_code))
        }
        Sys.sleep(runif(1, 0.5, 1.5))
      }, error = function(e) {
        message(paste("Error downloading:", url, "\nReason:", e$message))
      })
    } else {
      message(paste("File already exists for:", url))
    }
  }

  # Run downloads in parallel
  future::plan(future::multisession, workers = workers)
  invisible(furrr::future_map(links, download_url, .progress = TRUE))
}
