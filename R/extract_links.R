#' Extract GAO Report Links
#'
#' Scrapes report links and metadata from the GAO reports and testimonies
#' listing pages.
#'
#' When `cache_dir` is set, raw HTML pages are saved to disk and
#' already-downloaded pages are skipped on subsequent runs. This makes
#' large scrapes resumable.
#'
#' @param base_url Character. The base URL for GAO reports
#'   (default: `"https://www.gao.gov/reports-testimonies"`).
#' @param last_page Integer. Last page number to scrape. If `NULL`, detected
#'   automatically from the pagination.
#' @param verbose Logical. If `TRUE`, shows a progress bar (default: `TRUE`).
#' @param save_to_file Logical. If `TRUE`, saves data to an RDS file
#'   (default: `FALSE`).
#' @param output_file Character. File path for the output.
#' @param sleep_time Numeric. Seconds to pause between page requests.
#' @param cache_dir Character or `NULL`. Directory to cache raw HTML listing
#'   pages. If `NULL` (default), pages are fetched into memory only. If set,
#'   pages are saved as `page_0.html`, `page_1.html`, etc., and
#'   already-downloaded pages are skipped.
#'
#' @return A data.frame with columns: url, title, report_id, published,
#'   released, summary.
#' @importFrom utils txtProgressBar setTxtProgressBar
#' @export
#' @examples
#' \dontrun{
#' links <- extract_links(last_page = 5)
#'
#' # Resumable: caches HTML to disk
#' links <- extract_links(cache_dir = "data-raw/gao_pages")
#' }
extract_links <- function(base_url = "https://www.gao.gov/reports-testimonies",
                          last_page = NULL,
                          verbose = TRUE,
                          save_to_file = FALSE,
                          sleep_time = 1,
                          output_file = "gao_report_links.rds",
                          cache_dir = NULL) {

  if (!is.null(last_page)) {
    if (!is.numeric(last_page) || length(last_page) != 1 || last_page < 0) {
      stop("last_page must be a single non-negative integer", call. = FALSE)
    }
    last_page <- as.integer(last_page)
  }

  use.cache <- !is.null(cache_dir)
  if (use.cache && !dir.exists(cache_dir)) dir.create(cache_dir, recursive = TRUE)

  if (is.null(last_page)) {
    last_page <- .get_last_page(base_url)
    if (verbose) message("Detected last page: ", last_page)
  } else {
    if (verbose) message("Using manually specified last page: ", last_page)
  }

  pages <- 0:last_page
  n.pages <- length(pages)

  # ── Step 1: fetch (or read from cache) ──────────────────────────────────────
  if (use.cache) {
    # Download missing pages
    todo <- vapply(pages, function(pg) {
      f <- file.path(cache_dir, paste0("page_", pg, ".html"))
      !file.exists(f) || file.size(f) < 500
    }, logical(1))
    n.todo <- sum(todo)
    if (verbose) message("Cached: ", n.pages - n.todo, ", to download: ", n.todo)

    if (n.todo > 0) {
      if (verbose) pb <- txtProgressBar(min = 0, max = n.todo, style = 3)
      j <- 0L
      for (i in which(todo)) {
        pg <- pages[i]
        url <- if (pg == 0) base_url else paste0(base_url, "?page=", pg)
        dest <- file.path(cache_dir, paste0("page_", pg, ".html"))
        tryCatch({
          html.text <- .fetch_html_raw(url)
          writeLines(html.text, dest)
        }, error = function(e) {
          if (verbose) message("\nFailed page ", pg, ": ", e$message)
        })
        j <- j + 1L
        if (verbose) setTxtProgressBar(pb, j)
        if (j < n.todo) Sys.sleep(sleep_time)
      }
      if (verbose) close(pb)
    }

    # Parse all cached pages
    if (verbose) message("Parsing cached pages...")
    html.files <- list.files(cache_dir, pattern = "\\.html$", full.names = TRUE)
    html.files <- html.files[file.size(html.files) > 500]
    report.links <- vector("list", length(html.files))
    for (i in seq_along(html.files)) {
      report.links[[i]] <- tryCatch(
        .scrape_page_links(rvest::read_html(html.files[i])),
        error = function(e) NULL
      )
    }
  } else {
    # In-memory mode (small scrapes)
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
  }

  # ── Step 2: combine ────────────────────────────────────────────────────────
  all.data <- do.call(rbind, report.links)
  if (is.null(all.data) || nrow(all.data) == 0) {
    if (verbose) message("Found 0 report links")
    all.data <- data.frame(
      url = character(0), title = character(0), report_id = character(0),
      published = character(0), released = character(0), summary = character(0),
      topics = character(0), subject_terms = character(0),
      stringsAsFactors = FALSE
    )
  } else {
    all.data$url <- paste0("https://www.gao.gov", all.data$url)
    all.data <- all.data[!duplicated(all.data$url), , drop = FALSE]
    all.data <- all.data[order(all.data$url), , drop = FALSE]
    rownames(all.data) <- NULL
    if (verbose) message("Found ", nrow(all.data), " report links")
  }

  if (save_to_file) {
    saveRDS(all.data, output_file)
    if (verbose) message("Saved to: ", output_file)
  }

  all.data
}

#' Fetch Raw HTML Text
#'
#' Like [.fetch_html()] but returns the raw HTML as a character vector
#' (one element per line) instead of a parsed document. Used for caching
#' pages to disk.
#'
#' @param url Character. URL to fetch.
#' @param retries Integer. Number of retry attempts.
#' @return Character vector of HTML lines.
#' @keywords internal
#' @noRd
.fetch_html_raw <- function(url, retries = 3) {
  curl.bin <- .get_curl_bin()
  for (attempt in seq_len(retries)) {
    html.text <- system2(curl.bin, args = c("-s", "-L", url), stdout = TRUE,
                          stderr = FALSE)
    if (length(html.text) > 0) {
      combined <- paste(html.text, collapse = "\n")
      if (!grepl("Access Denied", combined, fixed = TRUE)) {
        return(html.text)
      }
    }
    if (attempt < retries) Sys.sleep(2 * attempt)
  }
  stop("Failed to fetch: ", url)
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
