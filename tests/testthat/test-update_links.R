.mk_base_row <- function() {
  data.frame(
    url = "u", title = "t", report_id = "GGD-95-1",
    published = "1995-06-01", released = "1995-06-05",
    summary = "s", page_count = 1L,
    topics = "Government Operations", subject_terms = "x",
    has_recommendations = FALSE, n_recommendations = 0L,
    has_matters = FALSE, n_matters = 0L,
    agencies_affected = "Department of Defense",
    stringsAsFactors = FALSE
  )
}

test_that(".ensure_expanded() adds the full derived schema and stamps version (C4)", {
  out <- .ensure_expanded(.mk_base_row())
  expect_true(all(.indicator_colnames() %in% names(out)))
  expect_true(all(c("issuing_division", "product_type", "requester_party",
                    "n_topics") %in% names(out)))
  expect_identical(attr(out, "gao_schema_version"), .gao_schema_version())
  expect_equal(out$n_topics, 1L)
})

test_that(".ensure_expanded() recomputes stale derived columns (C4)", {
  once <- .ensure_expanded(.mk_base_row())
  # Corrupt a derived column and mark the frame with an older schema version.
  once$product_type <- "BOGUS"
  attr(once, "gao_schema_version") <- 1L
  redo <- .ensure_expanded(once)
  expect_equal(redo$product_type, "report")   # recomputed, not "BOGUS"
  expect_identical(attr(redo, "gao_schema_version"), .gao_schema_version())
  expect_equal(sum(names(redo) == "product_type"), 1L)  # no duplicate columns
})

test_that("the empty fallback frame carries the full derived schema (C5)", {
  # Mirror the schema gao_links() builds when no bundled data is found.
  empty <- data.frame(
    url = character(0), title = character(0), report_id = character(0),
    published = character(0), released = character(0), summary = character(0),
    page_count = integer(0), topics = character(0),
    subject_terms = character(0),
    has_recommendations = logical(0), n_recommendations = integer(0),
    has_matters = logical(0), n_matters = integer(0),
    agencies_affected = character(0),
    requester_type = character(0), requester_committees = character(0),
    requester_members = character(0),
    stringsAsFactors = FALSE
  )
  empty <- .expand_indicators(empty)
  empty <- .expand_features(empty)
  base.cols <- c("url", "title", "report_id", "published", "released",
                 "summary", "page_count", "topics", "subject_terms",
                 "has_recommendations", "n_recommendations", "has_matters",
                 "n_matters", "agencies_affected",
                 "requester_type", "requester_committees", "requester_members")
  feature.cols <- c("issuing_division", "product_type", "pub_month", "pub_dow",
                    "pub_fiscal_year", "fiscal_quarter", "election_year",
                    "release_lag_days", "n_topics", "n_subject_terms",
                    "requester_party", "requester_majority_status",
                    "requester_chamber", "requester_bipartisan")
  expect_equal(nrow(empty), 0L)
  expect_named(empty, c(base.cols, .indicator_colnames(), feature.cols))
})

test_that("gao_update_data() rejects an RDS missing required base columns (C4)", {
  skip_if_not_installed("withr")
  withr::local_envvar(R_USER_DATA_DIR = withr::local_tempdir())
  testthat::local_mocked_bindings(
    download.file = function(url, destfile, ...) {
      saveRDS(data.frame(x = 1), destfile)
      0L
    }, .package = "utils")
  expect_error(gao_update_data(quiet = TRUE), "missing required columns")
})

test_that("update_links() returns sorted data.frame with correct columns", {
  skip_if_not(nchar(Sys.which("curl_firefox147")) > 0)
  skip_on_cran()

  known <- gao_links()
  skip_if(nrow(known) == 0, "No bundled link data available")

  result <- update_links(verbose = FALSE, sleep_time = 1)

  expect_s3_class(result, "data.frame")
  base.cols <- c("url", "title", "report_id", "published", "released",
                 "summary", "page_count", "topics", "subject_terms",
                 "has_recommendations", "n_recommendations", "has_matters",
                 "n_matters", "agencies_affected",
                 "requester_type", "requester_committees",
                 "requester_members")
  expected <- c(base.cols, .indicator_colnames())
  expect_named(result, expected)
  expect_true(nrow(result) >= nrow(known))
  expect_true(all(known$url %in% result$url))
  expect_equal(result$url, sort(unique(result$url)))
})
