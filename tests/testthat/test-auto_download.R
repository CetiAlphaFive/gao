# --- auto_download() input validation ---

test_that("auto_download() rejects bad format", {
  expect_error(auto_download(format = "txt"), "must be")
})

test_that("auto_download() rejects bad year", {
  expect_error(auto_download(format = "pdf", year = "abc"), "numeric vector")
  expect_error(auto_download(format = "pdf", year = 99), "between 1921")
  expect_error(auto_download(format = "pdf", year = 2050), "between 1921")
})

test_that("auto_download() rejects bad download_dir", {
  expect_error(auto_download(format = "pdf", download_dir = 42), "character string")
})

test_that("auto_download() rejects bad sleep_time", {
  expect_error(auto_download(format = "pdf", sleep_time = -1), "non-negative")
  expect_error(auto_download(format = "pdf", sleep_time = "a"), "non-negative")
})

test_that("auto_download() rejects bad confirm", {
  expect_error(auto_download(format = "pdf", confirm = NA), "TRUE or FALSE")
  expect_error(auto_download(format = "pdf", confirm = "yes"), "TRUE or FALSE")
})

test_that("auto_download() errors with confirm = TRUE non-interactively", {
  skip_if(interactive(), "only runs non-interactively")

  # Need bundled data for this to reach the confirm check
  skip_if(nrow(gao_links()) == 0, "no bundled links")

  expect_error(
    auto_download(format = "pdf", confirm = TRUE),
    "confirm = FALSE"
  )
})

# --- Integration test with mocked gao_links() ---

test_that("auto_download() includes URL-only rows when year matches", {
  mock.links <- data.frame(
    url = c("https://www.gao.gov/products/gao-24-106198",
            "https://www.gao.gov/products/gao-24-200000",
            "https://www.gao.gov/products/gao-23-300000"),
    title = c("Report A", "Report B", "Report C"),
    report_id = c("GAO-24-106198", "GAO-24-200000", "GAO-23-300000"),
    published = c("2024-01-15", NA_character_, NA_character_),
    released = c("2024-02-01", NA_character_, NA_character_),
    summary = c("Summary A", "Summary B", "Summary C"),
    stringsAsFactors = FALSE
  )

  local_mocked_bindings(gao_links = function() mock.links)

  # Capture the filtering logic without actually downloading
  # by using a year that won't trigger confirm in non-interactive
  # Report A: FY2024 from date, Report B: FY2024 from URL, Report C: FY2023 from URL
  expect_error(
    auto_download(format = "pdf", year = 2024, confirm = TRUE),
    "confirm = FALSE"
  )

  # Verify the inferred years directly
  fy <- .infer_fiscal_year(mock.links$published, mock.links$url)
  expect_equal(fy, c(2024L, 2024L, 2023L))
  expect_equal(sum(fy == 2024L, na.rm = TRUE), 2L)
})

test_that("auto_download() downloads PDFs with mocked data", {
  skip_if_not(nchar(Sys.which("curl_firefox147")) > 0)

  skip_on_cran()

  tmp.dir <- file.path(tempdir(), "gao_auto_test")
  on.exit(unlink(tmp.dir, recursive = TRUE))

  mock.links <- data.frame(
    url = c("https://www.gao.gov/products/gao-24-106198",
            "https://www.gao.gov/products/gao-24-106335"),
    title = c("Report A", "Report B"),
    report_id = c("GAO-24-106198", "GAO-24-106335"),
    published = c("2024-01-15", "2024-02-01"),
    released = c("2024-02-01", "2024-03-01"),
    summary = c("Summary A", "Summary B"),
    stringsAsFactors = FALSE
  )

  local_mocked_bindings(gao_links = function() mock.links)

  auto_download(format = "pdf", year = 2024,
                download_dir = tmp.dir, sleep_time = 0,
                confirm = FALSE)

  pdf.files <- list.files(file.path(tmp.dir, "pdf"), pattern = "\\.pdf$")
  expect_true(length(pdf.files) == 2)
})
