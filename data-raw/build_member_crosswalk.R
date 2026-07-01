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
  stringsAsFactors = FALSE
)
member <- member[!is.na(member$match_key), ]

# Drop within-(congress, chamber, match_key) collisions across parties: ambiguous
# keys get NA party so the runtime returns "unknown" rather than guessing.
key <- paste(member$congress, member$chamber, member$match_key, sep = "|")
n.parties <- tapply(member$party, key, function(p) length(unique(p)))
member$party[n.parties[key] > 1] <- NA_character_
.member_party <- unique(member[, c("congress", "chamber", "match_key", "party")])
rownames(.member_party) <- NULL

# --- .majority_by_congress: majority party per (congress, chamber) ---
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

usethis::use_data(.member_party, .majority_by_congress,
                  internal = TRUE, overwrite = TRUE, compress = "xz")
cat("Wrote R/sysdata.rda:",
    nrow(.member_party), "member rows,",
    nrow(.majority_by_congress), "majority rows\n")
