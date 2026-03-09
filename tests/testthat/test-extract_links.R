test_that("extract_links() returns report URLs from 1 page", {
  skip_if_not(nchar(Sys.which("curl_firefox147")) > 0)
  skip_on_cran()

  links <- extract_links(last_page = 0, verbose = FALSE, save_to_file = FALSE)

  expect_type(links, "character")
  expect_true(length(links) > 0)
  expect_true(all(grepl("^https://www.gao.gov/products/", links)))
})

test_that(".get_last_page() returns a positive integer", {
  skip_if_not(nchar(Sys.which("curl_firefox147")) > 0)
  skip_on_cran()

  last.page <- .get_last_page()
  expect_type(last.page, "integer")
  expect_true(last.page > 100)
})

test_that("extract_links() save_to_file works", {
  skip_if_not(nchar(Sys.which("curl_firefox147")) > 0)
  skip_on_cran()

  tmp <- tempfile(fileext = ".csv")
  on.exit(unlink(tmp))

  links <- extract_links(last_page = 0, verbose = FALSE,
                         save_to_file = TRUE, output_file = tmp)
  expect_true(file.exists(tmp))
})
