test_that("update_links() returns sorted data.frame with correct columns", {
  skip_if_not(nchar(Sys.which("curl_firefox147")) > 0)
  skip_on_cran()

  known <- gao_links()
  skip_if(nrow(known) == 0, "No bundled link data available")

  result <- update_links(verbose = FALSE, sleep_time = 1)

  expect_s3_class(result, "data.frame")
  expect_named(result, c("url", "title", "report_id", "published", "released", "summary"))
  expect_true(nrow(result) >= nrow(known))
  expect_true(all(known$url %in% result$url))
  expect_equal(result$url, sort(unique(result$url)))
})
