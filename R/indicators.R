# Internal constants and helpers for one-hot indicator columns
# Topics: 31 unique values (alphabetical)
# Agencies: top 50 by frequency (excludes literal "Other")

.topic_levels <- c(
  "Agriculture and Food",
  "Auditing and Financial Management",
  "Budget and Spending",
  "Business Regulation and Consumer Protection",
  "Economic Development",
  "Education",
  "Employment",
  "Energy",
  "Equal Opportunity",
  "Financial Markets and Institutions",
  "GAO Mission and Operations",
  "Government Operations",
  "Health Care",
  "Homeland Security",
  "Housing",
  "Human Capital",
  "Information Management",
  "Information Security",
  "Information Technology",
  "International Affairs",
  "Justice and Law Enforcement",
  "National Defense",
  "Natural Resources and Environment",
  "Retirement Security",
  "Science and Technology",
  "Space",
  "Tax Policy and Administration",
  "Telecommunications",
  "Transportation",
  "Veterans",
  "Worker and Family Assistance"
)

.agency_levels <- c(
  "Board of Governors",
  "Centers for Medicare & Medicaid Services",
  "Department of Agriculture",
  "Department of Commerce",
  "Department of Defense",
  "Department of Education",
  "Department of Energy",
  "Department of Health and Human Services",
  "Department of Homeland Security",
  "Department of Housing and Urban Development",
  "Department of Justice",
  "Department of Labor",
  "Department of State",
  "Department of the Air Force",
  "Department of the Army",
  "Department of the Interior",
  "Department of the Navy",
  "Department of the Treasury",
  "Department of Transportation",
  "Department of Veterans Affairs",
  "Directorate of Border and Transportation Security",
  "Environmental Protection Agency",
  "Federal Aviation Administration",
  "Federal Communications Commission",
  "Federal Deposit Insurance Corporation",
  "Federal Emergency Management Agency",
  "Federal Energy Regulatory Commission",
  "Federal Reserve System",
  "Food and Drug Administration",
  "General Services Administration",
  "Health Care Financing Administration",
  "Internal Revenue Service",
  "National Aeronautics and Space Administration",
  "National Nuclear Security Administration",
  "National Science Foundation",
  "Nuclear Regulatory Commission",
  "Office of Federal Procurement Policy",
  "Office of Management and Budget",
  "Office of Personnel Management",
  "Office of the Comptroller of the Currency",
  "Resolution Trust Corporation",
  "Small Business Administration",
  "Social Security Administration",
  "Transportation Security Administration",
  "U.S. Agency for International Development",
  "United States Coast Guard",
  "United States Customs and Border Protection",
  "United States Postal Service",
  "United States Securities and Exchange Commission",
  "Veterans Administration"
)

#' Clean a name into a column-safe suffix
#'
#' @param name Character scalar.
#' @return Character scalar: lowercase, non-alphanumeric replaced with `_`,
#'   leading/trailing underscores stripped.
#' @keywords internal
#' @noRd
.clean_colname <- function(name) {
  out <- tolower(name)
  out <- gsub("[^a-z0-9]+", "_", out)
  out <- sub("^_+", "", out)
  out <- sub("_+$", "", out)
  out
}

#' Make a topic indicator column name
#'
#' @param name Character scalar. Raw topic name.
#' @return Character scalar like `"topic_national_defense"`.
#' @keywords internal
#' @noRd
.make_topic_colname <- function(name) {
  paste0("topic_", .clean_colname(name))
}

#' Make an agency indicator column name
#'
#' @param name Character scalar. Raw agency name.
#' @return Character scalar like `"agency_department_of_defense"`.
#' @keywords internal
#' @noRd
.make_agency_colname <- function(name) {
  paste0("agency_", .clean_colname(name))
}

#' Expand One-Hot Indicator Columns for Topics and Agencies
#'
#' Adds 82 integer indicator columns (31 topics, 50 agencies, 1 agency_other)
#' to a data.frame that has `topics` and `agencies_affected` columns. Matching
#' is exact per semicolon-delimited item: an indicator is `1` only when the
#' level appears as a whole entry in the source field (so a GAO sub-office
#' string does not flip its parent department's flag). Indicator columns are
#' `NA_integer_` for a row where the source field is missing (`NA`) OR empty
#' (blank / whitespace only).
#'
#' @param df A data.frame with at least `topics` (character) and
#'   `agencies_affected` (character, semicolon-separated) columns.
#' @return The input data.frame with 82 additional integer columns appended.
#' @keywords internal
#' @noRd
.expand_indicators <- function(df) {
  n <- nrow(df)

  # Treat NA or empty (after trimming) source fields as missing.
  topics.na   <- is.na(df$topics) | !nzchar(trimws(df$topics))
  agencies.na <- is.na(df$agencies_affected) |
    !nzchar(trimws(df$agencies_affected))

  # Precompute the per-row token sets once (O(n) splits, not O(n * levels)).
  topic.sets <- lapply(seq_len(n), function(i) {
    if (topics.na[i]) NA
    else trimws(strsplit(df$topics[i], ";", fixed = TRUE)[[1]])
  })
  agency.sets <- lapply(seq_len(n), function(i) {
    if (agencies.na[i]) NA
    else trimws(strsplit(df$agencies_affected[i], ";", fixed = TRUE)[[1]])
  })

  # --- Topics: 31 columns (exact set membership) ---
  for (topic in .topic_levels) {
    col <- .make_topic_colname(topic)
    df[[col]] <- vapply(seq_len(n), function(i) {
      if (topics.na[i]) NA_integer_ else as.integer(topic %in% topic.sets[[i]])
    }, integer(1))
  }

  # --- Agencies: 50 named columns (exact set membership) ---
  for (agency in .agency_levels) {
    col <- .make_agency_colname(agency)
    df[[col]] <- vapply(seq_len(n), function(i) {
      if (agencies.na[i]) NA_integer_ else as.integer(agency %in% agency.sets[[i]])
    }, integer(1))
  }

  # agency_other: 1 if any agency in the row's set is NOT in .agency_levels.
  other <- rep(NA_integer_, n)
  has.agencies <- which(!agencies.na)
  if (length(has.agencies) > 0) {
    other[has.agencies] <- vapply(has.agencies, function(i) {
      if (any(!agency.sets[[i]] %in% .agency_levels)) 1L else 0L
    }, integer(1))
  }
  df$agency_other <- other

  df
}

#' Column names for all indicator columns
#'
#' Returns the 82 indicator column names in order: topics, agencies, agency_other.
#'
#' @return Character vector of length 82.
#' @keywords internal
#' @noRd
.indicator_colnames <- function() {
  c(vapply(.topic_levels, .make_topic_colname, character(1), USE.NAMES = FALSE),
    vapply(.agency_levels, .make_agency_colname, character(1), USE.NAMES = FALSE),
    "agency_other")
}

#' Derived-column schema version
#'
#' Bumped whenever the semantics of any on-the-fly derived column change, so
#' [.ensure_expanded()] can detect and recompute a frame carrying stale
#' derived columns. Stamped onto fully-expanded frames by [.expand_features()].
#'
#' @return A length-1 integer.
#' @keywords internal
#' @noRd
.gao_schema_version <- function() 2L
