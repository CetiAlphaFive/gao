# Requester party / chamber / majority covariates, resolved against the bundled
# VoteView crosswalk (.member_party, .majority_by_congress in R/sysdata.rda).

#' Congress number active on a given date
#'
#' The Nth Congress convenes Jan 3 of the odd year `1789 + 2*(N-1)`.
#' @param date A Date (or coercible vector).
#' @keywords internal
#' @noRd
.congress_for_date <- function(date) {
  date <- as.Date(date)
  yr <- as.integer(format(date, "%Y"))
  cong <- (yr - 1789L) %/% 2L + 1L
  # In an odd year before Jan 3, the previous Congress still sits.
  before.swear <- !is.na(yr) & (yr %% 2L == 1L) &
    (date < as.Date(paste0(yr, "-01-03")))
  cong[before.swear] <- cong[before.swear] - 1L
  as.integer(cong)
}

#' Normalize a member name to a "lastname firstinitial" match key
#'
#' Produces `tolower(paste(last_surname_token, first_initial))` identically for
#' both input conventions, so build-time and runtime keys line up. Multi-word
#' surnames collapse to their last whitespace token (e.g. "Van Hollen" ->
#' "hollen", "de la Garza" -> "garza") and trailing generational suffixes
#' (Jr, Sr, II, III, IV, ...) are stripped before the surname token is taken.
#'
#' Two input conventions, selected by `lastfirst`:
#' * `lastfirst = FALSE` (runtime, default): GAO member strings of the form
#'   `"First M. Last, Role"` or `"First M. Last (Chamber)"`. Everything after the
#'   first comma is a role annotation and is dropped; parentheticals are dropped.
#' * `lastfirst = TRUE` (crosswalk build): VoteView `bioname` of the form
#'   `"LAST, First Middle"`, where the comma separates surname from given names.
#'
#' @keywords internal
#' @noRd
.normalize_member_name <- function(name, lastfirst = FALSE) {
  suffix.re <- "^(JR|SR|II|III|IV|2ND|3RD|4TH)$"
  vapply(name, function(nm) {
    if (is.na(nm) || !nzchar(trimws(nm))) return(NA_character_)
    x <- gsub("\\([^)]*\\)", " ", nm)                # drop parenthetical chamber/nickname
    if (lastfirst) {                                 # "LAST, First Middle"
      x <- gsub("[^A-Za-z ,]", " ", x)
      parts <- strsplit(x, ",")[[1]]
      surname_str <- trimws(parts[1])
      first <- trimws(if (length(parts) > 1) parts[2] else "")
    } else {                                         # "First M. Last, Role"
      x <- sub(",.*$", "", x)                        # drop role after first comma
      x <- gsub("[^A-Za-z ]", " ", x)
      toks <- strsplit(x, "\\s+")[[1]]
      toks <- toks[nzchar(toks)]
      if (length(toks) == 0L) return(NA_character_)
      first <- toks[1]
      surname_str <- paste(toks[-1], collapse = " ")
      if (surname_str == "") surname_str <- toks[1]  # single-token name
    }
    # Reduce the surname to its last token, stripping trailing suffixes.
    stoks <- strsplit(trimws(surname_str), "\\s+")[[1]]
    stoks <- stoks[nzchar(stoks)]
    while (length(stoks) > 0L &&
           grepl(suffix.re, stoks[length(stoks)], ignore.case = TRUE)) {
      stoks <- stoks[-length(stoks)]
    }
    last <- if (length(stoks) > 0L) stoks[length(stoks)] else NA_character_
    if (is.na(last) || !nzchar(last)) return(NA_character_)
    tolower(trimws(paste(last, substr(first, 1, 1))))
  }, character(1), USE.NAMES = FALSE)
}

#' Build hashed lookups from the bundled crosswalk
#'
#' Returns environments for O(1) party / caucus / chamber / majority lookups, so
#' the per-report join in [.expand_features()] does not re-subset the 50k-row
#' crosswalk on every row. Built once per `gao_links()` load.
#'
#' The lookups are chamber-aware so House/Senate namesakes (e.g. Mark vs. Mike
#' Kelly) do not collide. Chamber-less fallbacks are populated only when a
#' `congress|match_key` maps unambiguously to a single non-`NA` value.
#'
#' Returns a list with elements `party_ch`, `caucus_ch` (keyed
#' `"congress|chamber|match_key"`), `party_nc`, `caucus_nc`, `chamber_nc`
#' (keyed `"congress|match_key"`), and `maj` (keyed `"congress|chamber"`).
#' @keywords internal
#' @noRd
.build_party_lookups <- function() {
  mp <- .member_party
  new_env <- function() new.env(hash = TRUE, parent = emptyenv())

  party_ch   <- new_env()
  caucus_ch  <- new_env()
  party_nc   <- new_env()
  caucus_nc  <- new_env()
  chamber_nc <- new_env()
  maj        <- new_env()

  # Chamber-aware party/caucus (skip rows with NA party / NA caucus).
  ck <- paste(mp$congress, mp$chamber, mp$match_key, sep = "|")
  for (i in which(!is.na(mp$party))) {
    assign(ck[i], mp$party[i], envir = party_ch)
    if (!is.na(mp$caucus[i])) assign(ck[i], mp$caucus[i], envir = caucus_ch)
  }

  # Chamber-less unambiguous party/caucus/chamber.
  nk <- paste(mp$congress, mp$match_key, sep = "|")
  groups <- split(seq_len(nrow(mp)), nk)
  for (g in names(groups)) {
    idx <- groups[[g]]
    up <- unique(mp$party[idx])
    if (length(up) == 1L && !is.na(up)) assign(g, up, envir = party_nc)
    uc <- unique(mp$caucus[idx])
    if (length(uc) == 1L && !is.na(uc)) assign(g, uc, envir = caucus_nc)
    uch <- unique(mp$chamber[idx])
    if (length(uch) == 1L) assign(g, uch, envir = chamber_nc)
  }

  # Majority party per (congress, chamber).
  mj <- .majority_by_congress
  mk <- paste(mj$congress, mj$chamber, sep = "|")
  for (i in seq_len(nrow(mj))) assign(mk[i], mj$majority_party[i], envir = maj)

  list(party_ch = party_ch, caucus_ch = caucus_ch,
       party_nc = party_nc, caucus_nc = caucus_nc,
       chamber_nc = chamber_nc, maj = maj)
}

#' Requester party / chamber / majority / bipartisan for one report
#'
#' @param members Character scalar: semicolon-delimited requester member string.
#' @param committees Character scalar: semicolon-delimited committee string
#'   (used only to infer chamber when member names are absent).
#' @param published Character/Date scalar publication date.
#' @param lookups Optional list from [.build_party_lookups()]. Built on demand if
#'   `NULL` (fine for single calls; pass a shared one for batch use).
#' @return A one-row list: `requester_party` ("R"/"D"/"Other"/"mixed"/NA;
#'   `"Other"` = a lone independent/third-party requester),
#'   `requester_majority_status` ("majority"/"minority"/"mixed"/NA; resolved via
#'   the member's caucus so independents count with the party they caucus with),
#'   `requester_chamber` ("House"/"Senate"/"both"/NA),
#'   `requester_bipartisan` (logical).
#' @keywords internal
#' @noRd
.requester_party_features <- function(members, committees, published,
                                      lookups = NULL) {
  if (is.null(lookups)) lookups <- .build_party_lookups()
  cong <- .congress_for_date(published)

  # --- report-level chamber from committee annotations "(Senate)"/"(House)" ---
  chamber <- NA_character_
  if (!is.na(committees) && nzchar(committees)) {
    has.sen <- grepl("Senate", committees)
    has.hou <- grepl("House",  committees)
    chamber <- if (has.sen && has.hou) "both"
               else if (has.sen) "Senate"
               else if (has.hou) "House" else NA_character_
  }

  none <- list(requester_party = NA_character_,
               requester_majority_status = NA_character_,
               requester_chamber = chamber,
               requester_bipartisan = NA)

  if (is.na(cong) || is.na(members) || !nzchar(members)) return(none)

  member.strs <- trimws(strsplit(members, ";")[[1]])

  parties <- character(0)   # display party per resolved member
  in.maj  <- logical(0)     # majority membership per resolved member (NA allowed)

  for (ms in member.strs) {
    if (!nzchar(ms)) next

    # per-member candidate chamber: parenthetical annotation, else the report
    # chamber when it is a single chamber.
    cand <- NA_character_
    pm <- regmatches(ms, regexec("\\(\\s*(Senate|House)\\s*\\)", ms,
                                 perl = TRUE))[[1]]
    if (length(pm) >= 2L) {
      cand <- pm[2]
    } else if (!is.na(chamber) && chamber %in% c("House", "Senate")) {
      cand <- chamber
    }

    key <- .normalize_member_name(ms)
    if (is.na(key)) next

    party <- NA_character_
    caucus <- NA_character_
    res_chamber <- NA_character_
    got <- FALSE

    if (!is.na(cand)) {
      p <- get0(paste(cong, cand, key, sep = "|"), envir = lookups$party_ch,
                inherits = FALSE, ifnotfound = NA_character_)
      if (!is.na(p)) {
        party  <- p
        cc <- get0(paste(cong, cand, key, sep = "|"), envir = lookups$caucus_ch,
                   inherits = FALSE, ifnotfound = NA_character_)
        caucus <- if (!is.na(cc)) cc else p
        res_chamber <- cand
        got <- TRUE
      }
    }
    if (!got) {
      party <- get0(paste(cong, key, sep = "|"), envir = lookups$party_nc,
                    inherits = FALSE, ifnotfound = NA_character_)
      cc <- get0(paste(cong, key, sep = "|"), envir = lookups$caucus_nc,
                 inherits = FALSE, ifnotfound = NA_character_)
      caucus <- if (!is.na(cc)) cc else if (!is.na(party)) party else NA_character_
      res_chamber <- get0(paste(cong, key, sep = "|"), envir = lookups$chamber_nc,
                          inherits = FALSE, ifnotfound = NA_character_)
    }

    if (is.na(party)) next   # unresolved member contributes nothing

    parties <- c(parties, party)

    # majority status for this member, keyed on the effective (caucusing) party.
    eff <- if (!is.na(caucus)) caucus else party
    m <- if (!is.na(res_chamber)) {
      get0(paste(cong, res_chamber, sep = "|"), envir = lookups$maj,
           inherits = FALSE, ifnotfound = NA_character_)
    } else {
      NA_character_
    }
    in.maj <- c(in.maj, if (is.na(m)) NA else (eff == m))
  }

  if (length(parties) == 0L) return(none)

  uniq <- unique(parties)
  req.party <- if (length(uniq) == 1L) uniq else "mixed"
  bipartisan <- ("R" %in% parties) && ("D" %in% parties)

  in.maj <- in.maj[!is.na(in.maj)]
  maj.status <- if (length(in.maj) == 0L) {
    NA_character_
  } else if (all(in.maj)) {
    "majority"
  } else if (!any(in.maj)) {
    "minority"
  } else {
    "mixed"
  }

  list(requester_party = req.party,
       requester_majority_status = maj.status,
       requester_chamber = chamber,
       requester_bipartisan = bipartisan)
}
