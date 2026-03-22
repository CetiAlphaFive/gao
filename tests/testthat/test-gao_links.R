test_that("gao_links() returns a data.frame with correct columns", {
  links <- gao_links()
  expect_s3_class(links, "data.frame")
  base.cols <- c("url", "title", "report_id", "published", "released",
                 "summary", "page_count", "topics", "subject_terms",
                 "has_recommendations", "n_recommendations", "has_matters",
                 "n_matters", "agencies_affected",
                 "requester_type", "requester_committees",
                 "requester_members")
  expected <- c(base.cols, .indicator_colnames())
  expect_named(links, expected)
})
