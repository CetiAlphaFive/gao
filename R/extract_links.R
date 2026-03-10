#' Extract GAO Report Links
#'
#' Scrapes report links from the GAO reports and testimonies listing pages.
#'
#' @param base_url Character. The base URL for GAO reports
#'   (default: `"https://www.gao.gov/reports-testimonies"`).
#' @param last_page Integer. Last page number to scrape. If `NULL`, detected
#'   automatically from the pagination.
#' @param verbose Logical. If `TRUE`, shows a progress bar (default: `TRUE`).
#' @param save_to_file Logical. If `TRUE`, saves links to a text file
#'   (default: `FALSE`).
#' @param output_file Character. File path for the output.
#' @param sleep_time Numeric. Seconds to pause between page requests.
#'
#' @return A character vector of full GAO report URLs.
#' @importFrom utils txtProgressBar setTxtProgressBar
#' @export
#' @examples
#' \dontrun{
#' links <- extract_links(last_page = 5)
#' }
extract_links <- function(base_url = "https://www.gao.gov/reports-testimonies",
                          last_page = NULL,
                          verbose = TRUE,
                          save_to_file = FALSE,
                          sleep_time = 1,
                          output_file = "gao_report_links.txt") {

  if (!is.null(last_page)) {
    if (!is.numeric(last_page) || length(last_page) != 1 || last_page < 0) {
      stop("last_page must be a single non-negative integer", call. = FALSE)
    }
    last_page <- as.integer(last_page)
  }

  if (is.null(last_page)) {
    last_page <- .get_last_page(base_url)
    if (verbose) message("Detected last page: ", last_page)
  } else {
    if (verbose) message("Using manually specified last page: ", last_page)
  }

  pages <- 0:last_page
  n.pages <- length(pages)
  if (verbose) pb <- txtProgressBar(min = 0, max = n.pages, style = 3)

  report.links <- vector("list", n.pages)
  for (i in seq_along(pages)) {
    url <- if (pages[i] == 0) base_url else paste0(base_url, "?page=", pages[i])

    page <- tryCatch(.fetch_html(url), error = function(e) {
      if (verbose) message("\nFailed page ", pages[i], ": ", e$message)
      NULL
    })

    if (!is.null(page)) {
      report.links[[i]] <- .scrape_page_links(page)
    }

    if (verbose) setTxtProgressBar(pb, i)
    if (i < n.pages) Sys.sleep(sleep_time)
  }
  if (verbose) close(pb)

  full.links <- paste0("https://www.gao.gov", unlist(report.links))
  if (verbose) message("Found ", length(full.links), " report links")

  if (save_to_file) {
    writeLines(full.links, output_file)
    if (verbose) message("Saved to: ", output_file)
  }

  full.links
}

#' Get the Last Page of GAO Reports
#'
#' Dynamically detects the last page number from the pagination.
#'
#' @param base_url Character. The base URL for GAO reports.
#' @return An integer representing the last page number (0-indexed).
#' @keywords internal
#' @noRd
.get_last_page <- function(base_url = "https://www.gao.gov/reports-testimonies") {
  page <- .fetch_html(base_url)

  last.url <- rvest::html_attr(
    rvest::html_nodes(page, "a.usa-pagination__link.usa-pagination__next-page[aria-label='Last page']"),
    "href"
  )

  if (length(last.url) == 0) {
    stop("Could not detect last page. The GAO website structure may have changed.",
         call. = FALSE)
  }

  as.integer(gsub(".*page=([0-9]+)$", "\\1", last.url))
}
