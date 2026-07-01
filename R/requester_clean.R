#' Clean parsed requester committee/member strings
#'
#' Defensive post-parse cleanup for known noise patterns produced by the upstream
#' HTML/PDF parsers: an injected "GAO" token inside committee names, "RELEASED"
#' bleed from "Publicly Released" date text, and OCR mid-word capitalization.
#' Applied on the return paths of the requester parsers and by the one-time
#' historical cleanup in `data-raw/clean_requester_fields.R`.
#'
#' This is a safety net, not a substitute for fixing the source regexes; the root
#' cause of each pattern should be traced in the parser layer.
#'
#' @param x Character vector of semicolon-delimited requester strings.
#' @return Cleaned character vector, same length; `NA` in -> `NA` out.
#' @keywords internal
#' @noRd
.clean_requester_string <- function(x) {
  clean1 <- function(s) {
    if (is.na(s)) return(NA_character_)
    if (!nzchar(s)) return(s)
    items <- trimws(strsplit(s, ";")[[1]])
    items <- vapply(items, function(it) {
      # 1. injected "GAO" right after "Committee on"/"Subcommittee on"
      it <- sub("((?:Sub)?Committee on) GAO ", "\\1 ", it, perl = TRUE)
      # 2. drop "RELEASED"/"RESTRICTED"/OCR "PESTRICTUD" (+ "Publicly ") bleed
      it <- gsub("\\s*(?:Publicly )?(?:RELEASED|RESTRICTED|PESTRICTUD)\\b", "",
                 it, perl = TRUE)
      # 3. drop a dash-delimited "- Not to be released ..." distribution stamp
      it <- sub("\\s+[-\u2013\u2014]\\s+[Nn]ot to be released.*$", "", it)
      # 4. fix OCR mid-word caps like "LUgar" -> "Lugar" (upper, upper, lower-run)
      it <- gsub("\\b([A-Z])([A-Z])([a-z]+)", "\\1\\L\\2\\3", it, perl = TRUE)
      trimws(gsub("\\s+", " ", it))
    }, character(1), USE.NAMES = FALSE)
    items <- items[nzchar(items)]
    if (length(items) == 0L) return(NA_character_)
    paste(items, collapse = "; ")
  }
  vapply(x, clean1, character(1), USE.NAMES = FALSE)
}
