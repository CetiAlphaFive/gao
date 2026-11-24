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
  vapply(.ascii_name(name), function(nm) {
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

#' Transliterate accented letters to plain ASCII
#'
#' VoteView spells "GONZALEZ" with an accented A; GAO writes "Henry B.
#' Gonzalez". Without this the accent becomes a token break ("gonz lez") and
#' the keys never meet. Marks that some platforms' iconv leaves behind
#' (apostrophe inside a word, caret, tilde, double quote, backtick) are
#' removed so they cannot split a name either.
#'
#' @keywords internal
#' @noRd
.ascii_name <- function(x) {
  x <- as.character(x)
  out <- iconv(enc2utf8(x), "UTF-8", "ASCII//TRANSLIT", sub = "")
  bad <- is.na(out) & !is.na(x)
  out[bad] <- x[bad]
  gsub("[`^~\"]|(?<=[A-Za-z])'(?=[a-z])", "", out, perl = TRUE)
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
  # Vectorized throughout: a per-group R loop over ~90k keys (with by-name
  # list indexing, which is a linear scan) took minutes.
  fill <- function(env, keys, values) {
    names(values) <- keys
    list2env(as.list(values), envir = env)
  }
  # Keys whose (deduplicated) value is unique and non-NA within the key.
  unique_value <- function(keys, values) {
    keep <- !duplicated(paste(keys, values, sep = "\r"))
    k <- keys[keep]
    v <- values[keep]
    id <- match(k, k)                      # first position of each key
    n <- tabulate(id, nbins = length(k))[id]
    sel <- n == 1L & !is.na(v)
    list(keys = k[sel], values = v[sel])
  }

  # Chamber-aware party/caucus (skip rows with NA party / NA caucus).
  ck <- paste(mp$congress, mp$chamber, mp$match_key, sep = "|")
  ok <- !is.na(mp$party)
  fill(party_ch, ck[ok], mp$party[ok])
  okc <- ok & !is.na(mp$caucus)
  fill(caucus_ch, ck[okc], mp$caucus[okc])

  # Chamber-less unambiguous party/caucus/chamber, over the best-ranked keys
  # only (a House member's first-name key beats a senator's middle-name key).
  nk <- paste(mp$congress, mp$match_key, sep = "|")
  rk <- if ("rank" %in% names(mp)) mp$rank else rep(1L, nrow(mp))
  best <- rk == 1L | !(nk %in% nk[rk == 1L])   # ranks are 1 or 2
  for (spec in list(list(party_nc, mp$party), list(caucus_nc, mp$caucus),
                    list(chamber_nc, mp$chamber))) {
    a <- unique_value(nk[best], spec[[2]][best])
    fill(spec[[1]], a$keys, a$values)
  }

  # Majority party per (congress, chamber).
  mj <- .majority_by_congress
  fill(maj, paste(mj$congress, mj$chamber, sep = "|"), mj$majority_party)

  list(party_ch = party_ch, caucus_ch = caucus_ch,
       party_nc = party_nc, caucus_nc = caucus_nc,
       chamber_nc = chamber_nc, maj = maj)
}

#' Requester party / chamber / majority / bipartisan for one report
#'
#' @param members Character scalar: semicolon-delimited requester member string.
#' @param committees Character scalar: semicolon-delimited committee string.
#' @param published Character/Date scalar publication date.
#' @param lookups Optional list from [.build_party_lookups()]. Built on demand if
#'   `NULL` (fine for single calls; pass a shared one for batch use).
#' @return A one-row list: `requester_party` ("R"/"D"/"Other"/"mixed"/NA;
#'   `"Other"` = a lone independent/third-party requester),
#'   `requester_majority_status` ("majority"/"minority"/"mixed"/NA; resolved via
#'   the member's caucus so independents count with the party they caucus with),
#'   `requester_chamber` ("House"/"Senate"/"both"/NA; the union of committee
#'   annotations, member "(House)"/"(Senate)" annotations, and the chamber of
#'   each resolved member), `requester_bipartisan` (logical), and
#'   `requester_party_complete` (logical: `TRUE` when every named member was
#'   resolved, `FALSE` when party/bipartisan/majority were computed from only
#'   some of them, `NA` when no member is named).
#' @keywords internal
#' @noRd
.requester_party_features <- function(members, committees, published,
                                      lookups = NULL) {
  if (is.null(lookups)) lookups <- .build_party_lookups()
  cong <- .congress_for_date(published)

  # --- committee-level chamber from "(Senate)"/"(House)" annotations ---
  comm.ch <- character(0)
  if (!is.na(committees) && nzchar(committees)) {
    if (grepl("Senate", committees)) comm.ch <- c(comm.ch, "Senate")
    if (grepl("House",  committees)) comm.ch <- c(comm.ch, "House")
  }
  # single-chamber committee context, used as each member's candidate chamber
  comm.single <- if (length(comm.ch) == 1L) comm.ch else NA_character_
  chambers <- comm.ch

  collapse_chamber <- function(ch) {
    ch <- unique(ch[!is.na(ch)])
    if (length(ch) == 0L) NA_character_
    else if (length(ch) > 1L) "both"
    else ch
  }

  none <- list(requester_party = NA_character_,
               requester_majority_status = NA_character_,
               requester_chamber = collapse_chamber(chambers),
               requester_bipartisan = NA,
               requester_party_complete = NA)

  if (is.na(cong) || is.na(members) || !nzchar(members)) return(none)

  member.strs <- trimws(strsplit(members, ";")[[1]])

  parties <- character(0)   # display party per resolved member
  in.maj  <- logical(0)     # majority membership per resolved member (NA allowed)
  n.named <- 0L

  # An item that is only a role word ("Chairman", "Ranking Member") is parser
  # residue, not a person; it neither resolves nor counts as unresolved.
  role.only <- "^(the )?(vice )?(chair(man|woman|person)?|ranking (minority )?member|member|co-?chair(man)?)$"

  for (ms in member.strs) {
    if (!nzchar(ms)) next
    nm.part <- trimws(gsub("\\([^)]*\\)", " ", sub(",.*$", "", ms)))
    if (grepl(role.only, tolower(nm.part))) next

    # explicit per-member chamber annotation, e.g. "Jane Doe (House)"
    pm <- regmatches(ms, regexec("\\(\\s*(Senate|House)\\s*\\)", ms,
                                 perl = TRUE))[[1]]
    annot <- if (length(pm) >= 2L) pm[2] else NA_character_
    if (!is.na(annot)) chambers <- c(chambers, annot)
    cand <- if (!is.na(annot)) annot else comm.single

    key <- .normalize_member_name(ms)
    if (is.na(key)) next
    n.named <- n.named + 1L
    # A one-word fragment ("Lloyd", "Daniel") is a mangled name, not a full
    # one; matching it as a surname finds the wrong person (Marilyn Lloyd for
    # a split "Lloyd Bentsen"), so it counts as named but unresolved.
    if (length(strsplit(trimws(gsub("[^A-Za-z]+", " ", nm.part)), " ")[[1]]) < 2L) next

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
        caucus <- if (!is.na(cc)) cc else if (p %in% c("D", "R")) p else NA_character_
        res_chamber <- cand
        got <- TRUE
      }
    }
    if (!got) {
      party <- get0(paste(cong, key, sep = "|"), envir = lookups$party_nc,
                    inherits = FALSE, ifnotfound = NA_character_)
      cc <- get0(paste(cong, key, sep = "|"), envir = lookups$caucus_nc,
                 inherits = FALSE, ifnotfound = NA_character_)
      caucus <- if (!is.na(cc)) cc else if (party %in% c("D", "R")) party else NA_character_
      res_chamber <- get0(paste(cong, key, sep = "|"), envir = lookups$chamber_nc,
                          inherits = FALSE, ifnotfound = NA_character_)
    }

    if (is.na(party)) next   # unresolved: counted in n.named, not in parties

    parties <- c(parties, party)
    chambers <- c(chambers, res_chamber)

    # majority status for this member, keyed on the caucusing party. An
    # independent who caucuses with no one (Amash, Barkley) has no majority
    # status, rather than being counted as minority.
    eff <- caucus
    m <- if (!is.na(res_chamber) && !is.na(eff)) {
      get0(paste(cong, res_chamber, sep = "|"), envir = lookups$maj,
           inherits = FALSE, ifnotfound = NA_character_)
    } else {
      NA_character_
    }
    in.maj <- c(in.maj, if (is.na(m)) NA else (eff == m))
  }

  if (length(parties) == 0L) {
    none$requester_chamber <- collapse_chamber(chambers)
    return(none)
  }

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
       requester_chamber = collapse_chamber(chambers),
       requester_bipartisan = bipartisan,
       requester_party_complete = length(parties) == n.named)
}
