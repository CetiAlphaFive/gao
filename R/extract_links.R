#' Extract GAO Report Links
#'
#' Scrapes report links from the GAO reports and testimonies listing pages.
#'
#' @param base_url Character. The base URL for GAO reports
#'   (default: `"https://www.gao.gov/reports-testimonies"`).
#' @param last_page Integer. Last page number to scrape. If `NULL`, detected
#'   automatically from the pagination.
#' @param save_to_file Logical. If `TRUE`, saves links to a CSV file.
#' @param output_file Character. File path for the CSV output.
#' @param sleep_timer Numeric. Seconds to pause between page requests.
#'
#' @return A character vector of full GAO report URLs.
#' @import rvest
#' @importFrom utils write.csv
#' @export
#' @examples
#' \dontrun{
#' links <- extract_links(last_page = 5)
#' }
extract_links <- function(base_url = "https://www.gao.gov/reports-testimonies",
                          last_page = NULL,
                          save_to_file = TRUE,
                          sleep_timer = 0.5,
                          output_file = "gao_report_links.csv") {

  if (is.null(last_page)) {
    last_page <- .get_last_page(base_url)
    message("Detected last page: ", last_page)
  } else {
    message("Using manually specified last page: ", last_page)
  }

  # Pages are 0-indexed on GAO's site
  pages <- 0:last_page

  report.links <- character(0)

  for (i in seq_along(pages)) {
    if (pages[i] == 0) {
      url <- base_url
    } else {
      url <- paste0(base_url, "?page=", pages[i])
    }

    page <- tryCatch(.fetch_html(url), error = function(e) {
      message("Failed to fetch page ", pages[i], ": ", e$message)
      NULL
    })

    if (!is.null(page)) {
      hrefs <- rvest::html_attr(rvest::html_nodes(page, "a"), "href")
      product.links <- hrefs[grep("/products/", hrefs)]
      report.links <- c(report.links, product.links)
    }

    if (i < length(pages)) Sys.sleep(sleep_timer)
    if (i %% 50 == 0) message("Scraped ", i, " of ", length(pages), " pages")
  }

  full.links <- paste0("https://www.gao.gov", report.links)

  if (save_to_file) {
    write.csv(data.frame(url = full.links), file = output_file,
              row.names = FALSE)
    message("Saved ", length(full.links), " links to: ", output_file)
  }

  return(full.links)
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
