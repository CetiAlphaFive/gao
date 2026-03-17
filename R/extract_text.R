#' Extract Text from GAO PDF Reports
#'
#' Reads PDF files from a local directory and extracts their text content using
#' [pdftools::pdf_text()]. Designed to work with PDFs downloaded via
#' [download_pdfs()] or [auto_download()].
#'
#' @param pdf_dir Character. Path to a directory containing PDF files.
#' @param pattern Character. Regex pattern to filter filenames
#'   (default: `"\\.pdf$"`).
#' @param verbose Logical. Show progress messages (default: `TRUE`).
#'
#' @return A data.frame with columns:
#'   \describe{
#'     \item{file}{Character. The PDF filename (without directory path).}
#'     \item{text}{Character. The extracted text, with pages collapsed into a
#'       single string separated by newlines.}
#'     \item{pages}{Integer. The number of pages in the PDF.}
#'   }
#'
#' @details
#' Requires the \pkg{pdftools} package. Install it with
#' `install.packages("pdftools")` if not already available.
#'
#' Files that fail to parse (e.g., scanned/image-only PDFs) are included in
#' the result with `NA` text and `NA` pages along with a warning.
#'
#' @export
#' @examples
#' \dontrun{
#' # After downloading PDFs
#' auto_download(format = "pdf", year = 2024, download_dir = "gao_reports")
#' texts <- extract_text("gao_reports/pdf")
#' head(texts$file)
#' nchar(texts$text[1])
#' }
extract_text <- function(pdf_dir, pattern = "\\.pdf$", verbose = TRUE) {
  if (!requireNamespace("pdftools", quietly = TRUE)) {
    stop("Package 'pdftools' is required. Install it with: ",
         "install.packages(\"pdftools\")", call. = FALSE)
  }
  if (!is.character(pdf_dir) || length(pdf_dir) != 1) {
    stop("pdf_dir must be a single directory path", call. = FALSE)
  }
  if (!dir.exists(pdf_dir)) {
    stop("Directory not found: ", pdf_dir, call. = FALSE)
  }

  files <- list.files(pdf_dir, pattern = pattern, full.names = FALSE)
  if (length(files) == 0) {
    if (verbose) message("No PDF files found in ", pdf_dir)
    return(data.frame(file = character(0), text = character(0),
                      pages = integer(0), stringsAsFactors = FALSE))
  }

  if (verbose) message("Extracting text from ", length(files), " PDFs...")

  texts <- character(length(files))
  pages <- integer(length(files))

  for (i in seq_along(files)) {
    path <- file.path(pdf_dir, files[i])
    result <- tryCatch({
      raw <- pdftools::pdf_text(path)
      list(text = paste(raw, collapse = "\n"), pages = length(raw))
    }, error = function(e) {
      warning("Failed to extract text from ", files[i], ": ", e$message,
              call. = FALSE)
      list(text = NA_character_, pages = NA_integer_)
    })
    texts[i] <- result$text
    pages[i] <- result$pages

    if (verbose && length(files) >= 10 && i %% 100 == 0) {
      message("  ", i, " / ", length(files))
    }
  }

  if (verbose) message("Done.")

  data.frame(file = files, text = texts, pages = pages,
             stringsAsFactors = FALSE)
}
