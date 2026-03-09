#' Extract GAO Report Links
#'
#' This function scrapes all report links from the Government Accountability Office (GAO) reports and testimonies webpage.
#' It can use multicore processing to speed up scraping.
#'
#' @param base_url Character. The base URL for GAO reports (defaults to 'https://www.gao.gov/reports-testimonies').
#' @param use_multicore Logical. If TRUE, uses multicore processing (defaults to TRUE).
#' @param workers Integer. Number of workers for multicore processing. Only used if use_multicore = TRUE (defaults to 2).
#' @param last_page Integer. Optional. Specify the last page manually. If not provided, it will be dynamically detected.
#' @param save_to_file Logical. If TRUE, saves the scraped links to a CSV file (defaults to TRUE).
#' @param output_file Character. The file path to save the links if `save_to_file = TRUE` (defaults to 'gao_report_links.csv').
#' @param sleep_timer Numeric. The number of seconds to sleep between requests (defaults to .5).
#'
#' @return A character vector of GAO report links.
#' @import rvest furrr future
#' @importFrom utils write.csv
#' @export
#' @examples
#' \dontrun{
#' links <- extract_links(use_multicore = TRUE, workers = 10)
#' }
extract_links <- function(base_url = "https://www.gao.gov/reports-testimonies",
                          use_multicore = TRUE,
                          workers = NULL,
                          last_page = NULL,
                          save_to_file = TRUE,
                          sleep_timer = .5,
                          output_file = "gao_report_links.csv") {

  # Fetch the last page dynamically only if not manually specified
  if (is.null(last_page)) {
    last_page <- .get_last_page(base_url)
    message("Detected last page: ", last_page)
  } else {
    message("Using manually specified last page: ", last_page)
  }

  # Function to fetch links from each GAO page
  fetch_page_links <- function(page_number) {
    Sys.sleep(sleep_timer)
    url <- paste0(base_url, "?page=", page_number)
    page <- rvest::read_html(url)

    # Extract links to reports
    page_links <- rvest::html_nodes(page, "a") |>
      rvest::html_attr("href")

    # Filter links containing '/products/'
    page_links <- page_links[grep("/products/", page_links)]

    return(page_links)
  }

  # Use multicore or single-core processing
  if (use_multicore) {
    if (is.null(workers)) {
      workers <- 2
    }
    message("Using multicore processing with ", workers, " workers...")
    future::plan(future::multisession, workers = workers)
    pdf_links <- furrr::future_map(1:last_page, fetch_page_links, .progress = TRUE) |> unlist()
  } else {
    message("Using single-core processing...")
    pdf_links <- unlist(lapply(1:last_page, fetch_page_links))
  }

  # Append the base URL to each link
  full_links <- paste0("https://www.gao.gov", pdf_links)

  # Optionally save the links to a CSV file
  if (save_to_file) {
    write.csv(full_links, file = output_file, row.names = FALSE)
    message("GAO report links saved to: ", output_file)
  }

  # Return the list of full links
  return(full_links)
}

#' Get the Last Page of GAO Reports
#'
#' This helper function dynamically detects the last page of GAO reports.
#'
#' @param base_url Character. The base URL for GAO reports.
#' @return An integer representing the last page number.
#' @keywords internal
#' @noRd
.get_last_page <- function(base_url = "https://www.gao.gov/reports-testimonies") {
  # Read the HTML of the base page
  page <- rvest::read_html(base_url)

  # Extract the URL from the "Last" button using the appropriate selector
  last_page_url <- rvest::html_nodes(page, "a.usa-pagination__link.usa-pagination__next-page[aria-label='Last page']") |>
    rvest::html_attr("href")

  # Check if last_page_url was extracted correctly
  if (length(last_page_url) == 0) {
    stop("Could not find the last page. Check the selector.")
  }

  # Extract the page number from the URL
  last_page <- gsub(".*page=([0-9]+)$", "\\1", last_page_url) |>
    as.numeric() + 1

  # Return the last page number
  return(last_page)
}
