test_that("issuing division decodes known GAO division prefixes", {
  expect_equal(.gao_issuing_division("NSIAD-94-100"),
               "National Security & International Affairs")
  expect_equal(.gao_issuing_division("T-RCED-95-12"),   # testimony carries division
               "Resources, Community & Economic Development")
  expect_equal(.gao_issuing_division("B-271985"),
               "Legal decision (Comptroller General)")
  expect_equal(.gao_issuing_division("GAO-24-106198"),
               "Post-2000 (division code dropped)")
  expect_equal(.gao_issuing_division("087528"), NA_character_)  # pure-numeric legacy
  expect_equal(.gao_issuing_division("ZZZ-99-1"), "Other/uncommon office")
})

test_that("product type classifies the four channels plus reports", {
  expect_equal(.gao_product_type("NSIAD-94-100"),   "report")
  expect_equal(.gao_product_type("T-HEHS-95-12"),   "testimony")
  expect_equal(.gao_product_type("GAO-24-107436T"), "testimony")
  expect_equal(.gao_product_type("B-271985"),       "legal_decision")
  expect_equal(.gao_product_type("GGD-95-12R"),     "correspondence")
  expect_equal(.gao_product_type("OGC-95-1"),       "legal_other")
  expect_equal(.gao_product_type(NA_character_),    NA_character_)
})

test_that("temporal + scope features derive from dates and delimited fields", {
  d <- data.frame(
    report_id     = c("NSIAD-94-100", "T-HEHS-95-12"),
    published     = c("1994-11-15", "1995-02-01"),
    released      = c("1994-11-20", "1995-02-01"),
    topics        = c("National Defense; Space", ""),
    subject_terms = c("a; b; c", NA_character_),
    stringsAsFactors = FALSE
  )
  out <- .expand_features(d)
  expect_equal(out$pub_month,        c(11L, 2L))
  expect_equal(out$pub_fiscal_year,  c(1995L, 1995L))   # Nov 1994 -> FY1995
  expect_equal(out$fiscal_quarter,   c(1L, 2L))         # Nov -> FY Q1, Feb -> Q2
  expect_equal(out$election_year,    c(1L, 0L))         # 1994 even, 1995 odd
  expect_equal(out$release_lag_days, c(5L, 0L))
  expect_equal(out$n_topics,         c(2L, 0L))
  expect_equal(out$n_subject_terms,  c(3L, 0L))
  expect_true(all(c("issuing_division", "product_type") %in% names(out)))
})

test_that(".expand_features is idempotent and preserves row count", {
  d <- data.frame(report_id = "GGD-95-1", published = "1995-06-01",
                  released = "1995-06-01", topics = "Government Operations",
                  subject_terms = "x", stringsAsFactors = FALSE)
  once <- .expand_features(d)
  twice <- .expand_features(once)
  expect_equal(nrow(twice), 1L)
  expect_equal(twice$issuing_division, "General Government")
})

test_that(".expand_features attaches requester party columns", {
  d <- data.frame(
    report_id = "NSIAD-95-1", published = "1995-06-01", released = "1995-06-01",
    topics = "National Defense", subject_terms = "x",
    requester_members = "Richard G. Lugar, Chairman",
    requester_committees = "Committee on Armed Services (Senate)",
    stringsAsFactors = FALSE)
  out <- .expand_features(d)
  expect_true(all(c("requester_party", "requester_majority_status",
                    "requester_chamber", "requester_bipartisan") %in% names(out)))
  expect_equal(out$requester_party, "R")
  expect_equal(out$requester_majority_status, "majority")
})
