#' Download GAO PDF reports
#'
#' This function downloads PDF files from the provided URLs in parallel, saving them to a specified directory.
#'
#' @param pdf_links A character vector of PDF URLs to download (without the domain prefix).
#' @param front_url The base URL to prepend to each PDF link (default: "https://www.gao.gov").
#' @param download_dir The directory where the PDF files will be saved (default: current working directory).
#' @param workers The number of workers to use for parallel downloading (default: all cores - 1).
#' @param sleep_time Time (in seconds) to pause between downloads to avoid overwhelming the server (default: 1).
#' @return Invisible list of download results. Called for side effect of downloading PDF files.
#' @import furrr future
#' @importFrom utils download.file
#' @export
download_pdfs <- function(pdf_links,
                          front_url = "https://www.gao.gov",
                          download_dir = getwd(),
                          workers = parallel::detectCores() - 1,
                          sleep_time = 1) {

  # Ensure the download directory exists
  if (!dir.exists(download_dir)) {
    dir.create(download_dir, recursive = TRUE)
  }

  # Set up parallel processing with furrr
  future::plan(future::multisession, workers = workers)

  # Define the download function
  download_pdf <- function(url) {
    # Prepend the front_url to the relative PDF path
    full_url <- paste0(front_url, url)
    # Extract the file name from the URL
    file_name <- basename(url)
    # Create the full path for the destination file
    destfile <- file.path(download_dir, file_name)
    # Download the PDF file
    download.file(full_url, destfile = destfile, mode = "wb")
    # Pause to avoid overwhelming the website
    Sys.sleep(sleep_time)
  }

  # Download PDFs in parallel using future_map
  invisible(furrr::future_map(pdf_links, download_pdf))

  # Clear the parallel plan after the download
  future::plan(future::sequential)
}
