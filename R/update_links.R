#' Update GAO Report Links
#'
#' Scrapes the most recent GAO report listing pages and appends any new links
#' not already in the bundled dataset. Used by the daily CI workflow; most
#' users should use [gao_links()] to access the bundled dataset.
#'
#' @param verbose Logical. Show progress messages (default: `TRUE`).
#' @param sleep_time Numeric. Seconds between requests (default: 1).
#'
#' @return A data.frame of all known reports (old + new), sorted by url.
#' @keywords internal
#' @noRd
update_links <- function(verbose = TRUE, sleep_time = 1) {
  base.url <- "https://www.gao.gov/reports-testimonies"
  known <- gao_links()
  if (verbose) message("Bundled reports: ", nrow(known))

  new.rows <- list()
  page.num <- 0
  consecutive.known <- 0L
  consecutive.failures <- 0L
  row.idx <- 0L

  repeat {
    url <- if (page.num == 0) base.url else paste0(base.url, "?page=", page.num)

    page <- tryCatch(.fetch_html(url), error = function(e) {
      if (verbose) message("Failed page ", page.num, ": ", e$message)
      NULL
    })

    if (is.null(page)) {
      consecutive.failures <- consecutive.failures + 1L
      if (consecutive.failures >= 3) {
        if (verbose) message("Stopping: 3 consecutive fetch failures")
        break
      }
      page.num <- page.num + 1
      Sys.sleep(sleep_time)
      next
    }

    consecutive.failures <- 0L
    page.data <- .scrape_page_links(page)
    if (nrow(page.data) > 0) {
      page.data$url <- paste0("https://www.gao.gov", page.data$url)
      page.new <- page.data[!page.data$url %in% known$url, , drop = FALSE]
    } else {
      page.new <- page.data
    }

    if (nrow(page.new) == 0) {
      consecutive.known <- consecutive.known + 1L
      if (verbose) message("Page ", page.num, ": no new reports")
    } else {
      consecutive.known <- 0L
      row.idx <- row.idx + 1L
      new.rows[[row.idx]] <- page.new
      if (verbose) message("Page ", page.num, ": +", nrow(page.new), " new reports")
    }

    if (consecutive.known >= 3) break
    page.num <- page.num + 1
    Sys.sleep(sleep_time)
  }

  if (length(new.rows) > 0) {
    new.data <- do.call(rbind, new.rows)
    # Ensure consistent columns in both directions
    for (col in setdiff(names(new.data), names(known))) {
      known[[col]] <- NA_character_
    }
    for (col in setdiff(names(known), names(new.data))) {
      new.data[[col]] <- NA
    }
    combined <- rbind(known, new.data[, names(known), drop = FALSE])
  } else {
    combined <- known
  }

  if (verbose) message("New reports found: ", nrow(combined) - nrow(known))

  combined <- combined[!duplicated(combined$url), , drop = FALSE]
  combined <- combined[order(combined$url), , drop = FALSE]
  rownames(combined) <- NULL
  combined
}

#' Get Bundled GAO Report Data
#'
#' Returns a data.frame of GAO report metadata bundled with the package.
#'
#' @return A data.frame with columns: url, title, report_id, published,
#'   released, summary, page_count (integer, may be `NA` for reports
#'   without a matching PDF in the bundled archive), topics,
#'   subject_terms, has_recommendations (logical), n_recommendations
#'   (integer), has_matters (logical), n_matters (integer),
#'   agencies_affected (character, semicolon-separated), plus 82 integer
#'   indicator columns: 31 `topic_*` columns (one per topic), 50
#'   `agency_*` columns (one per top-50 agency), and `agency_other`
#'   (1 if any non-top-50 agency appears). Indicator columns are
#'   `NA_integer_` where the source field is missing.
#' @export
#' @examples
#' reports <- gao_links()
#' nrow(reports)
#' head(reports)
gao_links <- function() {
  path <- system.file("extdata", "gao_links.rds", package = "gao")
  if (path == "") {
    warning("No bundled link data found. Reinstall the package.",
            call. = FALSE)
    empty <- data.frame(
      url = character(0), title = character(0), report_id = character(0),
      published = character(0), released = character(0), summary = character(0),
      page_count = integer(0), topics = character(0),
      subject_terms = character(0),
      has_recommendations = logical(0), n_recommendations = integer(0),
      has_matters = logical(0), n_matters = integer(0),
      agencies_affected = character(0),
      stringsAsFactors = FALSE
    )
    for (col in .indicator_colnames()) empty[[col]] <- integer(0)
    return(empty)
  }
  readRDS(path)
}
