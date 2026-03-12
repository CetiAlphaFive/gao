test_that("extract_links() returns data.frame from 1 page", {
  skip_if_not(nchar(Sys.which("curl_firefox147")) > 0)
  skip_on_cran()

  result <- extract_links(last_page = 0, verbose = FALSE, save_to_file = FALSE)

  expect_s3_class(result, "data.frame")
  expect_true(nrow(result) > 0)
  expect_named(result, c("url", "title", "report_id", "published", "released", "summary"))
  expect_true(all(grepl("^https://www.gao.gov/products/", result$url)))
})

test_that(".get_last_page() returns a positive integer", {
  skip_if_not(nchar(Sys.which("curl_firefox147")) > 0)
  skip_on_cran()

  last.page <- .get_last_page()
  expect_type(last.page, "integer")
  expect_true(last.page > 100)
})

test_that("extract_links() validates last_page", {
  expect_error(extract_links(last_page = -5, verbose = FALSE), "non-negative")
  expect_error(extract_links(last_page = "abc", verbose = FALSE), "non-negative")
  expect_error(extract_links(last_page = c(1, 2), verbose = FALSE), "non-negative")
})

test_that("extract_links() save_to_file works", {
  skip_if_not(nchar(Sys.which("curl_firefox147")) > 0)
  skip_on_cran()

  tmp <- tempfile(fileext = ".rds")
  on.exit(unlink(tmp))

  result <- extract_links(last_page = 0, verbose = FALSE,
                           save_to_file = TRUE, output_file = tmp)
  expect_true(file.exists(tmp))
  loaded <- readRDS(tmp)
  expect_s3_class(loaded, "data.frame")
})
