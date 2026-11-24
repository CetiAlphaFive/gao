# Builds internal crosswalk data shipped as R/sysdata.rda.
# Run manually: Rscript data-raw/build_member_crosswalk.R
# Source: VoteView (Lewis et al.), public-domain member ideology file.
# Rebuild when a new Congress seats (every 2 years); VoteView lags a few months.

url <- "https://voteview.com/static/data/out/members/HSall_members.csv"
# Optional local copy: GAO_VOTEVIEW_CSV=/path/to/HSall_members.csv
src <- Sys.getenv("GAO_VOTEVIEW_CSV", url)
raw <- read.csv(src, stringsAsFactors = FALSE, encoding = "UTF-8")

# Keep House and Senate voting members; drop President rows.
raw <- raw[raw$chamber %in% c("House", "Senate"), ]

party_label <- function(code) {
  ifelse(code == 100, "D", ifelse(code == 200, "R", "Other"))
}

# Same normalizer the runtime join uses, so keys line up. bioname is already in
# "LAST, First Middle (Nick)" form -- feed it straight through (its comma
# branch).
source("R/requester_party.R", local = TRUE)

# Person identity: bioguide_id is stable across a party switch (VoteView issues
# a NEW icpsr to a switcher, e.g. Jeffords 14240 -> 94240), so it is what tells
# a same-person switch apart from two namesakes. Fall back to icpsr if missing.
person <- ifelse(!is.na(raw$bioguide_id) & nzchar(raw$bioguide_id),
                 raw$bioguide_id, paste0("icpsr", raw$icpsr))

# Formal given name -> initial of a common nickname that starts with a
# different letter (Bill Bradley = "BRADLEY, William Warren").
nick_initial <- c(william = "b", robert = "b", richard = "d", edward = "t",
                  anthony = "t", eugene = "g", gerald = "j", margaret = "p",
                  elizabeth = "b", harold = "h", henry = "h")

# All match keys for one bioname, with a rank: 1 = how a member is normally
# addressed (first given name, its nickname, a parenthetical "(Bob)"),
# 2 = a middle name ("THURMOND, James Strom" -> Strom Thurmond).
name_keys <- function(bioname) {
  base <- .normalize_member_name(bioname, lastfirst = TRUE)
  if (is.na(base)) return(NULL)
  surname <- sub(" [a-z]$", "", base)
  nm <- .ascii_name(bioname)
  nick <- regmatches(nm, regexpr("(?<=\\()[^)]*(?=\\))", nm, perl = TRUE))
  given <- sub("^[^,]*,", "", gsub("\\([^)]*\\)", " ", nm))
  given <- tolower(gsub("[^A-Za-z ]", " ", given))
  toks <- strsplit(trimws(given), "\\s+")[[1]]
  toks <- toks[nzchar(toks) &
               !grepl("^(jr|sr|ii|iii|iv|2nd|3rd|4th)$", toks)]
  r1 <- c(substr(toks[1], 1, 1),
          if (length(nick)) substr(tolower(trimws(nick)), 1, 1),
          unname(nick_initial[toks[1]]))
  r2 <- substr(toks[-1], 1, 1)
  r1 <- unique(r1[!is.na(r1) & nzchar(r1)])
  r2 <- setdiff(unique(r2[nzchar(r2)]), r1)
  if (length(r1) == 0L) return(NULL)
  data.frame(match_key = paste(surname, c(r1, r2)),
             rank = c(rep(1L, length(r1)), rep(2L, length(r2))),
             stringsAsFactors = FALSE)
}

member <- data.frame(
  congress = as.integer(raw$congress),
  chamber  = ifelse(raw$chamber == "House", "House", "Senate"),
  person   = person,
  party    = party_label(raw$party_code),
  icpsr    = as.integer(raw$icpsr),
  bioname  = raw$bioname,
  stringsAsFactors = FALSE
)

# Caucus overrides for independents (ICPSR -> caucus). Members who caucus with a
# major party but are coded "Other" (party_code != 100/200). D/R members caucus
# with their own party; unmapped independents get NA caucus.
ind_caucus <- c(`29147` = "D", `41300` = "D", `94240` = "D", `10802` = "D",
                `91300` = "D", `90915` = "D", `14823` = "D", `14039` = "D",
                `13100` = "R",
                `99767` = "R",  # Goode (VA), independent caucusing R, 106th-107th
                `20964` = "D")  # Pierluisi (PR), New Progressive caucusing D
member$caucus <- ifelse(member$party %in% c("D", "R"), member$party,
                        unname(ind_caucus[as.character(member$icpsr)]))

# Mid-Congress party switchers appear twice in one (congress, chamber). Keep
# the affiliation they ENDED the Congress with: the one that differs from their
# party in the previous Congress, else the one they carry into the next. The
# crosswalk has no dates, so reports from before the switch get the new party.
pc <- paste(member$person, member$congress)
dup <- pc %in% pc[duplicated(paste(pc, member$chamber))]
for (k in unique(pc[dup])) {
  rows <- which(pc == k)
  p <- member$person[rows[1]]; cg <- member$congress[rows[1]]
  prev <- unique(member$party[member$person == p & member$congress == cg - 1L])
  nxt  <- unique(member$party[member$person == p & member$congress == cg + 1L])
  opts <- member$party[rows]
  keep <- if (length(prev) == 1L && prev %in% opts && length(unique(opts)) > 1L) {
    rows[opts != prev][1]
  } else if (length(nxt) == 1L && nxt %in% opts) {
    rows[opts == nxt][1]
  } else {
    rows[1]
  }
  member <- member[-setdiff(rows, keep), ]
  pc <- paste(member$person, member$congress)
}

keys <- lapply(member$bioname, name_keys)
nk <- vapply(keys, function(k) if (is.null(k)) 0L else nrow(k), integer(1))
long <- member[rep(seq_len(nrow(member)), nk),
               c("congress", "chamber", "person", "party", "caucus")]
long <- cbind(long, do.call(rbind, keys[nk > 0]))

# Per (congress, chamber, match_key): keep the best-ranked candidates, so a
# member's first-name key beats a colleague's middle-name key (Denny Smith
# vs "SMITH, Robert Denny"-style namesakes). If the best-ranked candidates are
# more than one PERSON (Adam vs Adrian Smith; Jerry "(Jerry)" vs John Lewis)
# the key is ambiguous -> NA party, so the runtime returns "unknown" rather
# than guessing. (Treating ANY-rank overlap as ambiguous was tested and only
# lost correct matches.)
grp <- paste(long$congress, long$chamber, long$match_key, sep = "|")
best <- ave(long$rank, grp, FUN = min)
long <- long[long$rank == best, ]
grp <- paste(long$congress, long$chamber, long$match_key, sep = "|")
n.people <- ave(as.integer(factor(long$person)), grp,
                FUN = function(x) length(unique(x)))
# Namesakes who share party AND caucus (John and Jean Ashbrook, both R) leave
# the person unknown but the party certain, so only conflicting ones go NA.
n.aff <- ave(as.integer(factor(paste(long$party, long$caucus))), grp,
             FUN = function(x) length(unique(x)))
long$person[n.people > 1] <- NA_character_
long$party[n.aff > 1]     <- NA_character_
long$caucus[n.aff > 1]    <- NA_character_
.member_party <- unique(
  long[, c("congress", "chamber", "match_key", "rank", "person",
           "party", "caucus")])
rownames(.member_party) <- NULL
stopifnot(!anyDuplicated(paste(.member_party$congress, .member_party$chamber,
                               .member_party$match_key)))

# --- .majority_by_congress: majority party per (congress, chamber) ---
# Seed from VoteView seat counts (used for the House at all congresses and the
# Senate before the 80th). VoteView person-counts are unreliable for close
# Senate margins (independents, mid-term deaths), so the Senate is overridden
# below from an authoritative table.
seats <- as.data.frame(table(
  congress = as.integer(raw$congress),
  chamber  = ifelse(raw$chamber == "House", "House", "Senate"),
  party    = party_label(raw$party_code)
), stringsAsFactors = FALSE)
seats$congress <- as.integer(seats$congress)
seats <- seats[seats$party %in% c("D", "R") & seats$Freq > 0, ]

.majority_by_congress <- do.call(rbind, by(
  seats, list(seats$congress, seats$chamber),
  function(g) data.frame(
    congress = g$congress[1], chamber = g$chamber[1],
    majority_party = g$party[which.max(g$Freq)],
    stringsAsFactors = FALSE)))
rownames(.majority_by_congress) <- NULL

# Authoritative Senate majority party, 80th-119th Congress (Congress -> party).
# Encodes the actual organizing majority (e.g. 107th D after the 2001 Jeffords
# switch; 110th/117th D on the VP tie-break). Per-congress granularity cannot
# represent mid-term flips.
senate_majority <- c(
  `80` = "R", `81` = "D", `82` = "D", `83` = "R", `84` = "D", `85` = "D",
  `86` = "D", `87` = "D", `88` = "D", `89` = "D", `90` = "D", `91` = "D",
  `92` = "D", `93` = "D", `94` = "D", `95` = "D", `96` = "D", `97` = "R",
  `98` = "R", `99` = "R", `100` = "D", `101` = "D", `102` = "D", `103` = "D",
  `104` = "R", `105` = "R", `106` = "R", `107` = "D", `108` = "R", `109` = "R",
  `110` = "D", `111` = "D", `112` = "D", `113` = "D", `114` = "R", `115` = "R",
  `116` = "R", `117` = "D", `118` = "D", `119` = "R")

for (cg in names(senate_majority)) {
  cgi <- as.integer(cg)
  pty <- senate_majority[[cg]]
  row <- .majority_by_congress$congress == cgi &
    .majority_by_congress$chamber == "Senate"
  if (any(row)) {
    .majority_by_congress$majority_party[row] <- pty
  } else {
    .majority_by_congress <- rbind(
      .majority_by_congress,
      data.frame(congress = cgi, chamber = "Senate", majority_party = pty,
                 stringsAsFactors = FALSE))
  }
}
.majority_by_congress <- .majority_by_congress[
  order(.majority_by_congress$chamber, .majority_by_congress$congress), ]
rownames(.majority_by_congress) <- NULL

usethis::use_data(.member_party, .majority_by_congress,
                  internal = TRUE, overwrite = TRUE, compress = "xz")
cat("Wrote R/sysdata.rda:",
    nrow(.member_party), "member rows,",
    nrow(.majority_by_congress), "majority rows\n")
