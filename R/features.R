# Derived report-level covariates, computed on the fly by gao_links().
# All functions here are deterministic transforms of columns the scraper
# already produces (report_id, published, released, topics, subject_terms,
# requester_members, requester_committees) — no network access.

# GAO issuing division / office codes (used in report IDs ~1970s-2000, before
# the agency dropped division codes for the flat "GAO-YY-NNNN" scheme).
.gao_division_map <- c(
  NSIAD = "National Security & International Affairs",
  RCED  = "Resources, Community & Economic Development",
  GGD   = "General Government",
  HEHS  = "Health, Education & Human Services",
  HRD   = "Human Resources",
  AIMD  = "Accounting & Information Management",
  AFMD  = "Accounting & Financial Management",
  IMTEC = "Information Management & Technology",
  PEMD  = "Program Evaluation & Methodology",
  OGC   = "Office of General Counsel",
  OSI   = "Office of Special Investigations",
  OCG   = "Office of the Comptroller General",
  AA    = "Accounting & Auditing (legacy)",
  FGMSD = "Financial & General Management Studies (legacy)",
  PLRD  = "Procurement, Logistics & Readiness (legacy)",
  IPE   = "Institute for Program Evaluation (legacy)",
  CED   = "Community & Economic Development (legacy)",
  ID    = "International Division (legacy)",
  FPCD  = "Federal Personnel & Compensation (legacy)",
  GAO   = "Post-2000 (division code dropped)"
)

#' Alpha division/office prefix from a report ID
#' @keywords internal
#' @noRd
.gao_prefix <- function(report_id) {
  id <- toupper(trimws(as.character(report_id)))
  id <- sub("^T-", "", id)          # testimony carries the division after "T-"
  id <- sub("^B-.*$", "B", id)      # legal decisions collapse to bare "B"
  pre <- sub("^([A-Z]+).*$", "\\1", id)
  pre[grepl("^[0-9]", id)] <- NA_character_   # pure-numeric legacy IDs: unknown
  pre[!nzchar(pre)] <- NA_character_
  pre
}

#' Issuing GAO division/office for each report
#' @keywords internal
#' @noRd
.gao_issuing_division <- function(report_id) {
  pre <- .gao_prefix(report_id)
  div <- unname(.gao_division_map[pre])
  div[!is.na(pre) & pre == "B"]           <- "Legal decision (Comptroller General)"
  div[is.na(div) & !is.na(pre)]           <- "Other/uncommon office"
  div[is.na(pre)]                         <- NA_character_
  div
}

#' Product type: report / testimony / correspondence / legal_decision / legal_other
#'
#' Testimony is `T-` prefixed (legacy) or ends in digit-then-`T` (modern
#' `GAO-YY-NNNNT`); the digit guard avoids matching a trailing `T` that follows
#' a letter. Mirrors the ID conventions in [.classify_report_type()].
#' @keywords internal
#' @noRd
.gao_product_type <- function(report_id) {
  id <- toupper(trimws(as.character(report_id)))
  pt <- rep("report", length(id))
  pt[grepl("^T-", id) | grepl("[0-9]T$", id)] <- "testimony"
  pt[grepl("^B-", id)]                         <- "legal_decision"
  pt[grepl("[0-9]R$", id)]                     <- "correspondence"
  pt[grepl("^OGC", id) & pt == "report"]       <- "legal_other"
  pt[is.na(id) | !nzchar(id)]                  <- NA_character_
  pt
}

#' Count semicolon-delimited items (0 for NA/empty)
#' @keywords internal
#' @noRd
.count_delimited <- function(x) {
  ifelse(is.na(x) | !nzchar(x), 0L, lengths(strsplit(x, ";")))
}

#' Add all derived covariate columns to a report data.frame
#'
#' Deterministic functions of columns the scraper already produces. Called by
#' [gao_links()]. Guarded there so it runs once per load. Adds report-composition
#' features (issuing division, product type), neutral temporal features, scope
#' counts, and requester party covariates (via the bundled crosswalk).
#' @keywords internal
#' @noRd
.expand_features <- function(df) {
  pub <- as.Date(df$published)
  rel <- as.Date(df$released)
  mo  <- as.integer(format(pub, "%m"))
  yr  <- as.integer(format(pub, "%Y"))

  df$issuing_division <- .gao_issuing_division(df$report_id)
  df$product_type     <- .gao_product_type(df$report_id)

  df$pub_month       <- mo
  df$pub_dow         <- as.integer(format(pub, "%u"))                # 1=Mon..7=Sun
  df$pub_fiscal_year <- ifelse(is.na(mo), NA_integer_,
                               ifelse(mo >= 10L, yr + 1L, yr))
  df$fiscal_quarter  <- ((mo + 2L) %% 12L) %/% 3L + 1L              # FY starts Oct
  df$election_year   <- ifelse(is.na(yr), NA_integer_,
                               as.integer(yr %% 2L == 0L))
  df$release_lag_days <- as.integer(rel - pub)

  df$n_topics        <- .count_delimited(df$topics)
  df$n_subject_terms <- .count_delimited(df$subject_terms)

  # --- requester party/chamber/majority (uses bundled crosswalk) ---
  # Fill plain vectors, then assign to df once (avoids copying 56k-row columns
  # on every loop iteration).
  n <- nrow(df)
  party <- rep(NA_character_, n)
  maj   <- rep(NA_character_, n)
  cham  <- rep(NA_character_, n)
  bip   <- rep(NA, n)

  has.req <- all(c("requester_members", "requester_committees") %in% names(df))
  if (has.req && n > 0) {
    comm <- df$requester_committees
    # chamber from committee annotations, vectorized over all rows (cheap)
    has.sen <- !is.na(comm) & grepl("Senate", comm)
    has.hou <- !is.na(comm) & grepl("House",  comm)
    cham[has.sen & has.hou]  <- "both"
    cham[has.sen & !has.hou] <- "Senate"
    cham[has.hou & !has.sen] <- "House"

    # party/majority/bipartisan only for the (few) rows that name members
    mem <- df$requester_members
    pub <- df$published
    mrows <- which(!is.na(mem) & nzchar(mem))
    if (length(mrows) > 0L) {
      lk <- .build_party_lookups()   # built once, shared
      for (i in mrows) {
        r <- .requester_party_features(mem[i], comm[i], pub[i], lk)
        party[i] <- r$requester_party
        maj[i]   <- r$requester_majority_status
        cham[i]  <- r$requester_chamber
        bip[i]   <- r$requester_bipartisan
      }
    }
  }

  df$requester_party           <- party
  df$requester_majority_status <- maj
  df$requester_chamber         <- cham
  df$requester_bipartisan      <- bip

  df
}
