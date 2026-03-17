test_that("extract_text() validates inputs", {
  expect_error(extract_text(123), "single directory path")
  expect_error(extract_text(c("a", "b")), "single directory path")
  expect_error(extract_text("/nonexistent/dir"), "Directory not found")
})

test_that("extract_text() returns empty data.frame for empty directory", {
  skip_if_not_installed("pdftools")
  d <- withr::local_tempdir()
  result <- extract_text(d, verbose = FALSE)
  expect_s3_class(result, "data.frame")
  expect_equal(nrow(result), 0)
  expect_named(result, c("file", "text", "pages"))
})

test_that("extract_text() errors without pdftools", {
  # Can only test this if pdftools is actually missing, so skip otherwise

  skip_if(requireNamespace("pdftools", quietly = TRUE),
          "pdftools is installed, cannot test missing-package path")
  expect_error(extract_text(tempdir()), "pdftools")
})

test_that("extract_text() extracts text from a real PDF", {
  skip_if_not_installed("pdftools")
  skip_on_cran()

  ## Create a minimal PDF via pdftools
  d <- withr::local_tempdir()
  pdf.path <- file.path(d, "test.pdf")
  pdf(pdf.path, width = 5, height = 5)
  plot.new()
  text(0.5, 0.5, "hello world")
  dev.off()

  result <- extract_text(d, verbose = FALSE)
  expect_s3_class(result, "data.frame")
  expect_equal(nrow(result), 1)
  expect_equal(result$file, "test.pdf")
  expect_equal(result$pages, 1L)
  expect_true(nchar(result$text) > 0)
})
