#' Update GAO Report Links
#'
#' Scrapes the most recent GAO report listing pages and appends any new links
#' not already in the bundled dataset. Stops automatically when it reaches
#' reports that are already known.
#'
#' @param verbose Logical. Show progress messages (default: `TRUE`).
#' @param sleep_time Numeric. Seconds between requests (default: 1).
#'
#' @return A character vector of all known report URLs (old + new), sorted.
#' @export
#' @examples
#' \dontrun{
#' all_links <- update_links()
#' }
update_links <- function(verbose = TRUE, sleep_time = 1) {
  base.url <- "https://www.gao.gov/reports-testimonies"
  known <- gao_links()
  if (verbose) message("Bundled links: ", length(known))

  new.links <- character(0)
  page.num <- 0
  consecutive.known <- 0L

  repeat {
    url <- if (page.num == 0) base.url else paste0(base.url, "?page=", page.num)

    page <- tryCatch(.fetch_html(url), error = function(e) {
      if (verbose) message("Failed page ", page.num, ": ", e$message)
      NULL
    })

    if (is.null(page)) {
      consecutive.known <- consecutive.known + 1L
      if (consecutive.known >= 3) break
      page.num <- page.num + 1
      Sys.sleep(sleep_time)
      next
    }

    full.urls <- paste0("https://www.gao.gov", .scrape_page_links(page))
    page.new <- setdiff(full.urls, known)

    if (length(page.new) == 0) {
      consecutive.known <- consecutive.known + 1L
      if (verbose) message("Page ", page.num, ": no new links")
    } else {
      consecutive.known <- 0L
      new.links <- c(new.links, page.new)
      if (verbose) message("Page ", page.num, ": +", length(page.new), " new links")
    }

    if (consecutive.known >= 3) break
    page.num <- page.num + 1
    Sys.sleep(sleep_time)
  }

  if (verbose) message("New links found: ", length(new.links))
  sort(unique(c(known, new.links)))
}

#' Get Bundled GAO Report Links
#'
#' Returns the character vector of GAO report URLs bundled with the package.
#'
#' @return A character vector of GAO report URLs.
#' @export
#' @examples
#' links <- gao_links()
#' length(links)
gao_links <- function() {
  path <- system.file("extdata", "gao_links.csv", package = "gao")
  if (path == "") {
    warning("No bundled link data found. Run extract_links() to build it.",
            call. = FALSE)
    return(character(0))
  }
  readLines(path)
}
