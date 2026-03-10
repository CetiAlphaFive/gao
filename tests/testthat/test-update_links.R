test_that("update_links() returns sorted unique character vector", {
  skip_if_not(nchar(Sys.which("curl_firefox147")) > 0)
  skip_on_cran()

  known <- gao_links()
  skip_if(length(known) == 0, "No bundled link data available")

  result <- update_links(verbose = FALSE, sleep_time = 1)

  expect_type(result, "character")
  expect_true(length(result) >= length(known))
  expect_true(all(known %in% result))
  expect_equal(result, sort(unique(result)))
})
