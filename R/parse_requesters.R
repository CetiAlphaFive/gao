#' Parse Addressee Block from Report Letter Text
#'
#' Extracts committee names and member names from the structured addressee
#' block at the opening of a GAO report letter. Works with plain text from
#' PDF extraction or pre-processed HTML report text.
#'
#' @param text Character scalar. Report text where lines are separated by
#'   newlines. Can come from PDF extraction (via `pdftools::pdf_text()`) or
#'   from HTML report text after `<br>` to `\n` conversion.
#' @return A list with elements:
#'   \describe{
#'     \item{requester_type}{`"congressional_request"` if addressees found,
#'       `"cg_initiated"` if Comptroller General language detected, or
#'       `NA_character_`.}
#'     \item{requester_committees}{Semicolon-delimited committee names with
#'       chamber, e.g. `"Committee on Armed Services (Senate); Committee on
#'       Armed Services (House)"`, or `NA_character_`.}
#'     \item{requester_members}{Semicolon-delimited member names with roles,
#'       e.g. `"Roger F. Wicker, Chairman; Jack Reed, Ranking Member"`, or
#'       `NA_character_`.}
#'   }
#' @keywords internal
#' @noRd
.parse_addressee_block <- function(text) {
  na.result <- list(requester_type = NA_character_,
                    requester_committees = NA_character_,
                    requester_members = NA_character_)

  if (is.na(text) || !nzchar(trimws(text))) return(na.result)

  # Normalize whitespace: collapse multiple spaces/tabs but preserve newlines
  text <- gsub("\r\n", "\n", text)
  text <- gsub("\r", "\n", text)
  # PDF text often has extra spaces — collapse runs of spaces
  text <- gsub("[ \t]+", " ", text)
  # Normalize multiple blank lines to single
  text <- gsub("\n{3,}", "\n\n", text)

  # Search first ~15000 characters. Legacy reports (1970s-1990s) have the
  # letter on page 3 (cover + TOC + letter), so with 5 pages of text we
  # need a generous limit.
  search.text <- substr(text, 1, min(nchar(text), 15000L))

  # Pattern for addressee with committee role:
  # The Honorable [Name]
  # [Role]
  # [Committee on ...]
  # [Chamber]
  role.pattern <- paste0(
    "The Honorable\\s+([^\n]+?)\\s*\n\\s*",
    "(Chairman|Chairwoman|Chair|Ranking Member|Vice Chair(?:man|woman)?)\\s*\n\\s*",
    "((?:Committee|Subcommittee) on [^\n]+?)\\s*\n\\s*",
    "(United States Senate|U\\.?\\s?S\\.? Senate|House of Representatives)"
  )

  role.matches <- gregexpr(role.pattern, search.text, perl = TRUE)
  role.all <- regmatches(search.text, role.matches)[[1]]

  committees <- character(0)
  members <- character(0)

  map.chamber <- function(x) {
    x <- trimws(x)
    ifelse(grepl("Senate", x, ignore.case = TRUE), "Senate",
           ifelse(grepl("House", x, ignore.case = TRUE), "House", x))
  }

  if (length(role.all) > 0) {
    for (match.str in role.all) {
      parts <- regmatches(match.str, regexec(role.pattern, match.str, perl = TRUE))[[1]]
      name <- trimws(parts[2])
      role <- trimws(parts[3])
      committee <- trimws(parts[4])
      chamber <- map.chamber(parts[5])

      committees <- c(committees, paste0(committee, " (", chamber, ")"))
      members <- c(members, paste0(name, ", ", role))
    }
  }

  # 1990s format: role and committee on the SAME line.
  # E.g.: "Chairman, Subcommittee on Transportation\n and Related Agencies\n
  #         Committee on Appropriations\n House of Representatives"
  inline.role.pattern <- paste0(
    "The Honorable\\s+([^\n]+?)\\s*\n\\s*",
    "(Chairman|Chairwoman|Chair|Ranking (?:Minority )?Member|Vice Chair(?:man|woman)?)",
    ",?\\s+((?:Sub)?[Cc]ommittee\\s+on\\s+[^\n]+?)",
    "\\s*\n",
    "(?:\\s*and\\s+[^\n]+?\\s*\n)?",             # optional continuation ("and Related Agencies")
    "(?:\\s*(Committee\\s+on\\s+[^\n]+?)\\s*\n)?", # optional parent committee
    "\\s*(United States Senate|U\\.?\\s?S\\.? Senate|House of Representatives)"
  )

  inline.matches <- gregexpr(inline.role.pattern, search.text, perl = TRUE)
  inline.all <- regmatches(search.text, inline.matches)[[1]]

  if (length(inline.all) > 0) {
    for (match.str in inline.all) {
      parts <- regmatches(match.str, regexec(inline.role.pattern, match.str, perl = TRUE))[[1]]
      name <- trimws(parts[2])
      role <- trimws(parts[3])
      sub.committee <- trimws(parts[4])
      parent.committee <- trimws(parts[5])
      chamber <- map.chamber(parts[6])

      # Use parent committee if present, otherwise the subcommittee
      comm <- if (nzchar(parent.committee)) parent.committee else sub.committee
      committees <- c(committees, paste0(comm, " (", chamber, ")"))
      members <- c(members, paste0(name, ", ", role))
    }
  }

  # GAO HTML reports often group multiple members per committee block.
  # Pattern: members listed first, committee + chamber at end of block.
  # Try to catch members not matched by the per-member role pattern above
  # by looking for the grouped structure:
  #   The Honorable [Name1] \n [Role1] \n The Honorable [Name2] \n [Role2] \n
  #   Committee on [X] \n [Chamber]
  group.pattern <- paste0(
    "((?:The Honorable\\s+[^\n]+\\s*\n\\s*",
    "(?:Chairman|Chairwoman|Chair|Ranking Member|Vice Chair(?:man|woman)?)\\s*\n\\s*)+)",
    "((?:Committee|Subcommittee) on [^\n]+?)\\s*\n\\s*",
    "(United States Senate|U\\.?\\s?S\\.? Senate|House of Representatives)"
  )

  group.matches <- gregexpr(group.pattern, search.text, perl = TRUE)
  group.all <- regmatches(search.text, group.matches)[[1]]

  if (length(group.all) > 0) {
    for (match.str in group.all) {
      parts <- regmatches(match.str, regexec(group.pattern, match.str, perl = TRUE))[[1]]
      members.block <- parts[2]
      committee <- trimws(parts[3])
      chamber <- map.chamber(parts[4])

      committees <- c(committees, paste0(committee, " (", chamber, ")"))

      # Extract individual members from the block
      member.pattern <- "The Honorable\\s+([^\n]+?)\\s*\n\\s*(Chairman|Chairwoman|Chair|Ranking Member|Vice Chair(?:man|woman)?)"
      mm <- gregexpr(member.pattern, members.block, perl = TRUE)
      mm.all <- regmatches(members.block, mm)[[1]]
      for (m in mm.all) {
        mp <- regmatches(m, regexec(member.pattern, m, perl = TRUE))[[1]]
        members <- c(members, paste0(trimws(mp[2]), ", ", trimws(mp[3])))
      }
    }
  }

  # Pattern for addressee WITHOUT committee role (individual member):
  # The Honorable [Name]
  # [Chamber]
  indiv.pattern <- paste0(
    "The Honorable\\s+([^\n]+?)\\s*\n\\s*",
    "(United States Senate|U\\.?\\s?S\\.? Senate|House of Representatives)"
  )

  indiv.matches <- gregexpr(indiv.pattern, search.text, perl = TRUE)
  indiv.all <- regmatches(search.text, indiv.matches)[[1]]

  if (length(indiv.all) > 0) {
    for (match.str in indiv.all) {
      # Skip if already captured as part of a role match
      already <- FALSE
      for (rm in c(role.all, group.all)) {
        if (grepl(match.str, rm, fixed = TRUE)) { already <- TRUE; break }
      }
      if (already) next
      parts <- regmatches(match.str, regexec(indiv.pattern, match.str, perl = TRUE))[[1]]
      name <- trimws(parts[2])
      chamber <- map.chamber(parts[3])
      members <- c(members, paste0(name, " (", chamber, ")"))
    }
  }

  # Deduplicate
  committees <- unique(committees)
  members <- unique(members)

  # If no structured addressees found, check text signals
  if (length(committees) == 0 && length(members) == 0) {
    # Congressional Requesters (generic, no specific committee)
    if (grepl("Congressional Requesters", search.text, ignore.case = TRUE)) {
      return(list(requester_type = "congressional_request",
                  requester_committees = NA_character_,
                  requester_members = NA_character_))
    }

    # Report "To The Congress" = CG-initiated (GAO convention)
    if (grepl("Report\\s+To\\s+The\\s+Congress", search.text, ignore.case = TRUE, perl = TRUE)) {
      return(list(requester_type = "cg_initiated",
                  requester_committees = NA_character_,
                  requester_members = NA_character_))
    }

    # Comptroller General initiation
    cg.patterns <- c(
      "under the Comptroller General",
      "BY THE.{0,5}COMPTROLLER GENERAL",
      "Comptroller General.{0,20}authority",
      "Comptroller General.{0,20}initiated",
      "Comptroller General of the United States"
    )
    for (pat in cg.patterns) {
      if (grepl(pat, search.text, ignore.case = TRUE, perl = TRUE)) {
        return(list(requester_type = "cg_initiated",
                    requester_committees = NA_character_,
                    requester_members = NA_character_))
      }
    }

    # Testimony fallback (if ID-based classification missed it)
    if (grepl("(?:Testimony|Statement)\\s+(?:Before|of)", search.text,
              ignore.case = TRUE, perl = TRUE)) {
      return(list(requester_type = "testimony",
                  requester_committees = NA_character_,
                  requester_members = NA_character_))
    }

    return(na.result)
  }

  list(
    requester_type = "congressional_request",
    requester_committees = if (length(committees) > 0) paste(committees, collapse = "; ") else NA_character_,
    requester_members = if (length(members) > 0) paste(members, collapse = "; ") else NA_character_
  )
}

#' Parse Cover-Page Subtitle from PDF Text
#'
#' Extracts the "Report to..." or "Letter to..." subtitle from the cover
#' page of a GAO report PDF and parses the addressee using
#' `.parse_subtitle_addressee()`. Complements `.parse_addressee_block()`
#' which looks for "The Honorable" patterns in the letter body.
#'
#' @param text Character scalar. First 1-2 pages of PDF text.
#' @return A list with elements `requester_type`, `requester_committees`,
#'   `requester_members`.
#' @keywords internal
#' @noRd
.parse_pdf_cover_subtitle <- function(text) {
  na.result <- list(requester_type = NA_character_,
                    requester_committees = NA_character_,
                    requester_members = NA_character_)

  if (is.null(text) || is.na(text) || !nzchar(text)) return(na.result)

  # Collapse whitespace so the regex works across line breaks
  clean <- gsub("\\s+", " ", text)

  # Match "Report/Letter to [addressee]" terminated by date, report ID,
  # or uppercase title words common in legacy GAO PDFs
  terminators <- paste0(
    "(?:",
    "January|February|March|April|May|June|July|August|September|",
    "October|November|December|",
    "\\d{4}|GAO-|GAO/|",
    "OF THE UNITED STATES|",
    "[A-Z][A-Z]+\\s+[A-Z][A-Z]+\\s+[A-Z][A-Z]+",  # 3+ uppercase words (title)
    ")"
  )
  pattern <- paste0(
    "(?:Report|Letter)\\s+[Tt]o\\s+(?:[Tt]he\\s+)?(.+?)\\s+", terminators
  )
  m <- regmatches(clean, regexec(pattern, clean, perl = TRUE))[[1]]

  if (length(m) >= 2) {
    addressee <- trimws(m[2])
    # "Congress" alone (no specific committee) = CG-initiated
    if (grepl("^Congress$", addressee, ignore.case = TRUE)) {
      return(list(requester_type = "cg_initiated",
                  requester_committees = NA_character_,
                  requester_members = NA_character_))
    }
    result <- .parse_subtitle_addressee(addressee)
    if (!is.na(result$requester_type)) return(result)
  }

  na.result
}

#' Parse Requester Info from GAO HTML Report
#'
#' Extracts the "H-Requesters" subtitle and addressee block from the
#' HTML version of a GAO report (hosted at `files.gao.gov/reports/[ID]/`).
#' This is different from the product page at `gao.gov/products/[id]`.
#'
#' @param page An xml_document of the HTML report.
#' @return A list with elements `requester_type`, `requester_committees`,
#'   `requester_members`.
#' @importFrom rvest html_node html_nodes html_text
#' @keywords internal
#' @noRd
.parse_report_html <- function(page) {
  na.result <- list(requester_type = NA_character_,
                    requester_committees = NA_character_,
                    requester_members = NA_character_)

  # 1. Extract subtitle from the highlights section
  # The subtitle appears in different CSS classes across reports:
  #   - p.H-Requesters: "A report to the Ranking Member, Committee on X, U.S. Senate."
  #   - p.H-GrayColumnText-8: "Highlights of GAO-XX-XXXXXX, a report to congressional committees"
  # Use plain <p> selector and filter by text to avoid selectr crashes with some class names
  all.p <- rvest::html_nodes(page, "p")
  all.p.text <- rvest::html_text(all.p)

  hl.info <- na.result

  # Look for the highlights subtitle: "Highlights of GAO-XX-XXXXXX, a report to ..."
  # Only consider <p> nodes whose text starts with "Highlights of" to avoid garbled matches
  for (i in seq_along(all.p.text)) {
    txt <- gsub("\\s+", " ", trimws(all.p.text[i]))
    if (!grepl("^Highlights of ", txt)) next
    m <- regmatches(txt, regexec(
      "(?:report|letter|testimony)\\s+to\\s+(.+?)\\s*\\.?\\s*$",
      txt, perl = TRUE
    ))[[1]]
    if (length(m) >= 2) {
      candidate <- .parse_subtitle_addressee(trimws(m[2]))
      if (!is.na(candidate$requester_type)) {
        hl.info <- candidate
        break
      }
    }
  }

  # Also check H-Requesters text: "A report to ..." (without "Highlights of" prefix)
  if (is.na(hl.info$requester_type)) {
    for (i in seq_along(all.p.text)) {
      txt <- gsub("\\s+", " ", trimws(all.p.text[i]))
      if (!grepl("^A\\s+(?:report|letter|testimony)\\s+to", txt, perl = TRUE)) next
      m <- regmatches(txt, regexec(
        "(?:report|letter|testimony)\\s+to\\s+(.+?)\\s*\\.?\\s*$",
        txt, perl = TRUE
      ))[[1]]
      if (length(m) >= 2) {
        candidate <- .parse_subtitle_addressee(trimws(m[2]))
        if (!is.na(candidate$requester_type)) {
          hl.info <- candidate
          break
        }
      }
    }
  }

  # 2. Extract addressee block from letter body
  # Find <p> nodes containing "The Honorable" — use text filtering to avoid
  # CSS class selector crashes with certain class names (e.g., MsoBodyText)
  honorable.idx <- grep("The Honorable", all.p.text, fixed = TRUE)
  honorable.blocks <- character(0)

  for (idx in honorable.idx) {
    txt <- all.p.text[idx]
    # html_text() on nodes with <br> tags preserves newlines
    lines <- trimws(strsplit(txt, "\n")[[1]])
    lines <- lines[nzchar(lines)]
    honorable.blocks <- c(honorable.blocks, paste(lines, collapse = "\n"))
  }

  ab.result <- na.result
  if (length(honorable.blocks) > 0) {
    combined.text <- paste(honorable.blocks, collapse = "\n\n")
    ab.result <- .parse_addressee_block(combined.text)
  }

  # 3. Check "Why GAO Did This Study" for mandate language
  # If the section references a law requiring the study, override to statutory_mandate.
  # The header may be in <h3> or <p>, and content in various <p> classes, so search
  # the full page text rather than just <p> nodes.
  mandate.override <- FALSE
  full.text <- rvest::html_text(page)
  # Find the LAST "Why GAO Did This Study" (first may be a TOC link)
  why.positions <- gregexpr("Why GAO Did This Study", full.text, fixed = TRUE)[[1]]
  why.match <- if (why.positions[1] > 0) why.positions[length(why.positions)] else -1L
  if (why.match > 0) {
    why.text <- substr(full.text, why.match, min(nchar(full.text), why.match + 2000L))
    mandate.patterns <- c(
      "Act.{0,60}requires",
      "requires\\s+(?:GAO|the Comptroller|us)\\s+to",
      "required\\s+(?:by|under)",
      "mandated\\s+by",
      "pursuant\\s+to",
      "Public Law.{0,20}requires",
      "statute\\s+requires"
    )
    for (pat in mandate.patterns) {
      if (grepl(pat, why.text, ignore.case = TRUE, perl = TRUE)) {
        mandate.override <- TRUE
        break
      }
    }
  }

  # Merge: subtitle wins for requester_type (GAO's official classification),
  # addressee block wins for committees/members (richer data)
  req.type <- hl.info$requester_type
  if (is.na(req.type)) req.type <- ab.result$requester_type
  # Mandate language in "Why GAO Did This Study" overrides to statutory_mandate
  if (mandate.override) req.type <- "statutory_mandate"

  req.committees <- ab.result$requester_committees
  if (is.na(req.committees)) req.committees <- hl.info$requester_committees

  req.members <- ab.result$requester_members
  if (is.na(req.members)) req.members <- hl.info$requester_members

  list(requester_type = req.type,
       requester_committees = req.committees,
       requester_members = req.members)
}
