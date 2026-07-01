# Builds internal crosswalk data shipped as R/sysdata.rda.
# Run manually: Rscript data-raw/build_member_crosswalk.R
# Source: VoteView (Lewis et al.), public-domain member ideology file.
# Rebuild when a new Congress seats (every 2 years); VoteView lags a few months.

url <- "https://voteview.com/static/data/out/members/HSall_members.csv"
raw <- read.csv(url, stringsAsFactors = FALSE)

# Keep House and Senate voting members; drop President rows.
raw <- raw[raw$chamber %in% c("House", "Senate"), ]

party_label <- function(code) {
  ifelse(code == 100, "D", ifelse(code == 200, "R", "Other"))
}

# Same normalizer the runtime join uses, so keys line up. bioname is already in
# "LAST, First Middle" form — feed it straight through (its comma branch).
source("R/requester_party.R", local = TRUE)

member <- data.frame(
  congress  = as.integer(raw$congress),
  chamber   = ifelse(raw$chamber == "House", "House", "Senate"),
  match_key = .normalize_member_name(raw$bioname, lastfirst = TRUE),
  party     = party_label(raw$party_code),
  icpsr     = as.integer(raw$icpsr),
  stringsAsFactors = FALSE
)
# The redesigned .normalize_member_name reduces multi-word surnames to their
# last token (e.g. "VAN HOLLEN" -> "hollen c"), so keys match runtime strings.
member <- member[!is.na(member$match_key), ]

# Caucus overrides for independents (ICPSR -> caucus). Members who caucus with a
# major party but are coded "Other" (party_code != 100/200). D/R members caucus
# with their own party; unmapped independents get NA caucus.
ind_caucus <- c(`29147` = "D", `41300` = "D", `94240` = "D", `10802` = "D",
                `91300` = "D", `90915` = "D", `14823` = "D", `14039` = "D",
                `13100` = "R")
member$caucus <- ifelse(member$party %in% c("D", "R"), member$party,
                        unname(ind_caucus[as.character(member$icpsr)]))

# Drop within-(congress, chamber, match_key) collisions across parties: ambiguous
# keys get NA party (and NA caucus) so the runtime returns "unknown" rather than
# guessing.
key <- paste(member$congress, member$chamber, member$match_key, sep = "|")
n.parties <- tapply(member$party, key, function(p) length(unique(p)))
collide <- n.parties[key] > 1
member$party[collide]  <- NA_character_
member$caucus[collide] <- NA_character_
.member_party <- unique(
  member[, c("congress", "chamber", "match_key", "party", "caucus")])
rownames(.member_party) <- NULL

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
