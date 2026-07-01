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
#' Two input conventions, selected by `lastfirst`:
#' * `lastfirst = FALSE` (runtime, default): GAO member strings of the form
#'   `"First M. Last, Role"` or `"First M. Last (Chamber)"`. Everything after the
#'   first comma is a role annotation and is dropped; parentheticals are dropped;
#'   the last whitespace token is the surname.
#' * `lastfirst = TRUE` (crosswalk build): VoteView `bioname` of the form
#'   `"LAST, First Middle"`, where the comma separates surname from given names.
#'
#' Both paths must use this one function so the keys line up.
#' @keywords internal
#' @noRd
.normalize_member_name <- function(name, lastfirst = FALSE) {
  vapply(name, function(nm) {
    if (is.na(nm) || !nzchar(trimws(nm))) return(NA_character_)
    x <- gsub("\\([^)]*\\)", " ", nm)                # drop parenthetical chamber/nickname
    if (lastfirst) {                                 # "LAST, First Middle"
      x <- gsub("[^A-Za-z ,]", " ", x)
      x <- trimws(gsub("\\s+", " ", x))
      parts <- strsplit(x, ",")[[1]]
      last  <- trimws(parts[1])
      first <- trimws(if (length(parts) > 1) parts[2] else "")
    } else {                                         # "First M. Last, Role"
      x <- sub(",.*$", "", x)                        # drop role after first comma
      x <- gsub("[^A-Za-z ]", " ", x)
      x <- trimws(gsub("\\s+", " ", x))
      toks <- strsplit(x, " ")[[1]]
      toks <- toks[nchar(toks) > 0]
      if (length(toks) == 0) return(NA_character_)
      last  <- toks[length(toks)]
      first <- toks[1]
    }
    if (!nzchar(last)) return(NA_character_)
    tolower(trimws(paste(last, substr(first, 1, 1))))
  }, character(1), USE.NAMES = FALSE)
}

#' Build hashed lookups from the bundled crosswalk
#'
#' Returns environments for O(1) party and majority lookups, so the per-report
#' join in [.expand_features()] does not re-subset the 50k-row crosswalk on every
#' row. Built once per `gao_links()` load.
#' @keywords internal
#' @noRd
.build_party_lookups <- function() {
  mp <- .member_party
  party.env <- new.env(hash = TRUE, parent = emptyenv())
  pk <- paste(mp$congress, mp$match_key, sep = "|")
  for (i in seq_len(nrow(mp))) assign(pk[i], mp$party[i], envir = party.env)

  mj <- .majority_by_congress
  maj.env <- new.env(hash = TRUE, parent = emptyenv())
  mk <- paste(mj$congress, mj$chamber, sep = "|")
  for (i in seq_len(nrow(mj))) assign(mk[i], mj$majority_party[i], envir = maj.env)

  list(party = party.env, maj = maj.env)
}

#' Requester party / chamber / majority / bipartisan for one report
#'
#' @param members Character scalar: semicolon-delimited requester member string.
#' @param committees Character scalar: semicolon-delimited committee string
#'   (used only to infer chamber when member names are absent).
#' @param published Character/Date scalar publication date.
#' @param lookups Optional list from [.build_party_lookups()]. Built on demand if
#'   `NULL` (fine for single calls; pass a shared one for batch use).
#' @return A one-row list: `requester_party` ("R"/"D"/"mixed"/NA),
#'   `requester_majority_status` ("majority"/"minority"/"mixed"/NA),
#'   `requester_chamber` ("House"/"Senate"/"both"/NA),
#'   `requester_bipartisan` (logical).
#' @keywords internal
#' @noRd
.requester_party_features <- function(members, committees, published,
                                      lookups = NULL) {
  if (is.null(lookups)) lookups <- .build_party_lookups()
  cong <- .congress_for_date(published)

  # --- chamber from committee annotations "(Senate)"/"(House)" ---
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
  keys <- .normalize_member_name(member.strs)

  parties <- vapply(keys, function(k) {
    if (is.na(k)) return(NA_character_)
    get0(paste(cong, k, sep = "|"), envir = lookups$party,
         inherits = FALSE, ifnotfound = NA_character_)
  }, character(1), USE.NAMES = FALSE)

  parties <- parties[!is.na(parties)]
  if (length(parties) == 0L) return(none)

  uniq <- unique(parties)
  req.party <- if (length(uniq) == 1L) uniq else "mixed"
  bipartisan <- ("R" %in% parties) && ("D" %in% parties)

  # majority status: compare each party to the chamber majority for the Congress
  maj.chamber <- if (!is.na(chamber) && chamber %in% c("House", "Senate")) {
    chamber
  } else {
    "House"
  }
  maj <- get0(paste(cong, maj.chamber, sep = "|"), envir = lookups$maj,
              inherits = FALSE, ifnotfound = NA_character_)

  maj.status <- if (is.na(maj)) {
    NA_character_
  } else {
    in.maj <- parties == maj
    if (all(in.maj)) "majority" else if (!any(in.maj)) "minority" else "mixed"
  }

  list(requester_party = req.party,
       requester_majority_status = maj.status,
       requester_chamber = chamber,
       requester_bipartisan = bipartisan)
}
