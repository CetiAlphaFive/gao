# --- .extract_gao_year() ---

test_that(".extract_gao_year() parses standard GAO URLs", {
  urls <- c(
    "https://www.gao.gov/products/gao-24-106198",
    "https://www.gao.gov/products/gao-01-123",
    "https://www.gao.gov/products/gao-99-456",
    "https://www.gao.gov/products/gao-50-789"
  )
  expect_equal(.extract_gao_year(urls), c(2024L, 2001L, 1999L, 1950L))
})

test_that(".extract_gao_year() returns NA for non-standard URLs", {
  urls <- c(
    "https://www.gao.gov/products/d-12345",
    "https://www.gao.gov/products/some-report",
    "not-a-url"
  )
  expect_true(all(is.na(.extract_gao_year(urls))))
})

test_that(".extract_gao_year() handles empty input", {
  expect_equal(.extract_gao_year(character(0)), integer(0))
})

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
  skip_if(length(gao_links()) == 0, "no bundled links")

  expect_error(
    auto_download(format = "pdf", year = 2024, confirm = TRUE),
    "confirm = FALSE"
  )
})

# --- Integration test with mocked gao_links() ---

test_that("auto_download() downloads PDFs with mocked data", {
  skip_if_not(nchar(Sys.which("curl_firefox147")) > 0)

  skip_on_cran()

  tmp.dir <- file.path(tempdir(), "gao_auto_test")
  on.exit(unlink(tmp.dir, recursive = TRUE))

  mock.links <- c(
    "https://www.gao.gov/products/gao-24-106198",
    "https://www.gao.gov/products/gao-24-106335"
  )

  local_mocked_bindings(gao_links = function() mock.links)

  auto_download(format = "pdf", year = 2024,
                download_dir = tmp.dir, sleep_time = 0,
                confirm = FALSE)

  pdf.files <- list.files(file.path(tmp.dir, "pdf"), pattern = "\\.pdf$")
  expect_true(length(pdf.files) == 2)
})
