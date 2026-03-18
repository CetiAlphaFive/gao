test_that("extract_pdf_links() emits deprecation warning", {
  expect_warning(extract_pdf_links(character(0)), "deprecated")
})

test_that("extract_pdf_links() validates page_links", {
  expect_warning(
    expect_error(extract_pdf_links(42), "character vector"),
    "deprecated"
  )
})

test_that("extract_pdf_links() still returns .pdf paths", {
  skip_if_not(nchar(Sys.which("curl_firefox147")) > 0)
  skip_on_cran()

  pdf.links <- suppressWarnings(
    extract_pdf_links(
      "https://www.gao.gov/products/gao-26-107787",
      sleep_time = 0
    )
  )

  expect_type(pdf.links, "character")
  expect_true(length(pdf.links) > 0)
  expect_true(all(grepl("\\.pdf$", pdf.links)))
  expect_false(any(grepl("highlights", pdf.links)))
})
