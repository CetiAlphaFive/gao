#' Extract PDF Links from GAO Report Pages
#'
#' Visits each report page and extracts the PDF download link(s).
#' Highlight PDFs are excluded automatically.
#'
#' @param page_links Character vector. Full URLs of GAO report pages
#'   (e.g., `"https://www.gao.gov/products/gao-24-106198"`).
#' @param sleep_time Numeric. Seconds to pause between requests (default: 1).
#'
#' @return A character vector of unique PDF paths (relative to gao.gov).
#' @export
#' @examples
#' \dontrun{
#' pdf_links <- extract_pdf_links("https://www.gao.gov/products/gao-24-106198")
#' }
extract_pdf_links <- function(page_links, sleep_time = 1) {
  pdf.links <- character(0)

  for (i in seq_along(page_links)) {
    page <- tryCatch(.fetch_html(page_links[i]), error = function(e) {
      message("Failed: ", page_links[i], " - ", e$message)
      NULL
    })

    if (!is.null(page)) {
      pdfs <- rvest::html_attr(rvest::html_nodes(page, "a[href$='.pdf']"), "href")
      pdf.links <- c(pdf.links, pdfs)
    }

    if (i < length(page_links)) Sys.sleep(sleep_time)
    if (i %% 100 == 0) message("Processed ", i, " of ", length(page_links))
  }

  unique(pdf.links[!grepl("highlights", pdf.links)])
}
