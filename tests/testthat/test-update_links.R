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
