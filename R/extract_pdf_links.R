#' Extract PDF links from GAO reports
#'
#' This function extracts and processes the PDF links from GAO report pages. It uses parallel processing to speed up the extraction.
#'
#' @param page_links A vector of report page URLs from which to extract PDF links.
#' @param workers Number of workers to use for parallel processing (default: all cores - 2).
#' @param sleep_time Time (in seconds) to pause between requests to avoid overwhelming the server (default: 1).
#' @return A vector of unique PDF links.
#' @import httr rvest furrr future
#' @export
extract_pdf_links <- function(page_links,
                              workers = parallel::detectCores() - 2,
                              sleep_time = 1) {

  # Set up parallel processing
  future::plan(future::multisession, workers = workers)

  # Function to extract the PDF link from a single report page
  extract_pdf_link <- function(url) {
    Sys.sleep(sleep_time)
    page <- tryCatch(rvest::read_html(url), error = function(e) NULL)

    if (!is.null(page)) {
      pdf_link <- page |>
        rvest::html_nodes("div.field__item a") |>
        rvest::html_attr("href") |>
        grep("\\.pdf$", x = _, value = TRUE)
    } else {
      pdf_link <- NULL
    }

    return(pdf_link)
  }

  # Extract PDF links from each report page using future_map for parallelism
  pdf_links <- furrr::future_map(page_links, extract_pdf_link) |>
    unlist()

  # Filter out any links containing "highlights"
  pdf_links_filtered <- pdf_links[!grepl("highlights", pdf_links)]

  # Return unique PDF links
  return(unique(pdf_links_filtered))
}
