#' Download GAO Reports in One Step
#'
#' Convenience wrapper that loads the bundled report links, optionally filters
#' by fiscal year, and downloads reports as PDF, HTML, or both. In interactive
#' sessions, prompts for format and year range when not supplied.
#'
#' PDF URLs are constructed directly from report IDs (e.g.,
#' `/products/gao-24-106198` becomes `/assets/gao-24-106198.pdf`) rather than
#' scraping each report page, so no extra HTTP requests are needed for
#' link extraction.
#'
#' @param format Character. `"pdf"`, `"html"`, or `"both"`. `NULL` (default)
#'   prompts interactively; in non-interactive sessions defaults to `"pdf"`.
#' @param year Integer vector of 4-digit fiscal years, e.g. `2024` or
#'   `2020:2024`. `NULL` (default) prompts interactively; in non-interactive
#'   sessions uses all available years.
#' @param download_dir Character. Base directory for downloads. `pdf/` and/or
#'   `html/` subdirectories are created beneath it.
#' @param sleep_time Numeric. Seconds to pause between downloads.
#' @param confirm Logical. If `TRUE` (default), prompts for confirmation before
#'   downloading. In non-interactive sessions, `confirm = TRUE` raises an error
#'   to prevent accidental mass downloads — set `confirm = FALSE` explicitly.
#'
#' @return Invisible character vector of downloaded file paths.
#' @export
#' @importFrom utils menu
#' @examples
#' \dontrun{
#' # Interactive: walks through prompts
#' auto_download()
#'
#' # Non-interactive: download 2024 PDFs
#' auto_download(format = "pdf", year = 2024, confirm = FALSE)
#' }
auto_download <- function(format = NULL,
                          year = NULL,
                          download_dir = "gao_reports",
                          sleep_time = 1,
                          confirm = TRUE) {
  # --- Validate fixed args ---
  if (!is.null(format)) {
    format <- tolower(format)
    if (!format %in% c("pdf", "html", "both")) {
      stop("format must be \"pdf\", \"html\", or \"both\"", call. = FALSE)
    }
  }
  if (!is.null(year)) {
    if (!is.numeric(year) || any(is.na(year))) {
      stop("year must be a numeric vector of 4-digit years", call. = FALSE)
    }
    if (any(year < 1921 | year > 2049 | year != as.integer(year))) {
      stop("year values must be integers between 1921 and 2049", call. = FALSE)
    }
    year <- as.integer(year)
  }
  if (!is.character(download_dir) || length(download_dir) != 1) {
    stop("download_dir must be a single character string", call. = FALSE)
  }
  if (!is.numeric(sleep_time) || length(sleep_time) != 1 || sleep_time < 0) {
    stop("sleep_time must be a single non-negative number", call. = FALSE)
  }
  if (!is.logical(confirm) || length(confirm) != 1 || is.na(confirm)) {
    stop("confirm must be TRUE or FALSE", call. = FALSE)
  }

  # --- Load bundled data ---
  all.data <- gao_links()
  if (nrow(all.data) == 0) {
    stop("No bundled links found. Run update_links() first.", call. = FALSE)
  }

  all.years <- .fiscal_year(all.data$published)

  # --- Interactive prompts ---
  is.interactive <- interactive()

  if (is.null(format)) {
    if (is.interactive) {
      choice <- utils::menu(c("PDF only", "HTML only", "Both"),
                            title = "Select download format:")
      if (choice == 0) {
        message("Cancelled.")
        return(invisible(character(0)))
      }
      format <- c("pdf", "html", "both")[choice]
    } else {
      format <- "pdf"
    }
  }

  if (is.null(year)) {
    if (is.interactive) {
      yr.range <- range(all.years, na.rm = TRUE)
      cat("Available years:", yr.range[1], "-", yr.range[2], "\n")
      yr.input <- readline("Enter year(s) (e.g. 2024, 2020-2024, or 'all'): ")
      yr.input <- trimws(yr.input)
      if (yr.input == "" || tolower(yr.input) == "all") {
        year <- NULL
      } else if (grepl("^[0-9]{4}-[0-9]{4}$", yr.input)) {
        bounds <- as.integer(strsplit(yr.input, "-")[[1]])
        year <- seq.int(bounds[1], bounds[2])
      } else if (grepl("^[0-9]{4}$", yr.input)) {
        year <- as.integer(yr.input)
      } else {
        stop("Could not parse year input: ", yr.input, call. = FALSE)
      }
    }
    # non-interactive NULL year means all years — no filtering needed
  }

  # --- Filter links ---
  if (!is.null(year)) {
    keep <- !is.na(all.years) & all.years %in% year
    filtered.links <- all.data$url[keep]
  } else {
    filtered.links <- all.data$url
  }

  if (length(filtered.links) == 0) {
    message("No reports matched the specified year(s).")
    return(invisible(character(0)))
  }

  # --- Summary ---
  do.pdf <- format %in% c("pdf", "both")
  do.html <- format %in% c("html", "both")

  pdf.dir <- file.path(download_dir, "pdf")
  html.dir <- file.path(download_dir, "html")

  n <- length(filtered.links)
  parts <- character(0)
  if (do.pdf)  parts <- c(parts, paste0(n, " PDFs -> ", pdf.dir, "/"))
  if (do.html) parts <- c(parts, paste0(n, " HTMLs -> ", html.dir, "/"))
  message("Ready to download: ", paste(parts, collapse = ", "))

  # --- Confirm ---
  if (confirm) {
    if (!is.interactive) {
      stop("Non-interactive session: set confirm = FALSE to proceed.",
           call. = FALSE)
    }
    ans <- readline("Proceed? (y/n): ")
    if (!tolower(trimws(ans)) %in% c("y", "yes")) {
      message("Cancelled.")
      return(invisible(character(0)))
    }
  }

  # --- Download ---
  result <- character(0)

  if (do.pdf) {
    pdf.urls <- paste0(sub("/products/", "/assets/", filtered.links), ".pdf")
    result <- c(result, download_pdfs(pdf.urls,
                                      download_dir = pdf.dir,
                                      sleep_time = sleep_time))
  }

  if (do.html) {
    result <- c(result, download_htmls(filtered.links,
                                       target_directory = html.dir,
                                       sleep_time = sleep_time))
  }

  invisible(result)
}
