test_that("download_pdfs() downloads a PDF", {
  skip_if_not(nchar(Sys.which("curl_firefox147")) > 0)
  skip_on_cran()

  tmp.dir <- file.path(tempdir(), "gao_test_pdfs")
  on.exit(unlink(tmp.dir, recursive = TRUE))

  result <- download_pdfs("/assets/gao-24-106198.pdf",
                          download_dir = tmp.dir, sleep_time = 0)

  files <- list.files(tmp.dir, pattern = "\\.pdf$")
  expect_true(length(files) == 1)
  expect_true(file.size(file.path(tmp.dir, files[1])) > 1000)
})

test_that("download_pdfs() skips existing files", {
  skip_if_not(nchar(Sys.which("curl_firefox147")) > 0)
  skip_on_cran()

  tmp.dir <- file.path(tempdir(), "gao_test_skip")
  dir.create(tmp.dir, recursive = TRUE, showWarnings = FALSE)
  on.exit(unlink(tmp.dir, recursive = TRUE))

  # Create a dummy file
  writeLines("exists", file.path(tmp.dir, "gao-24-106198.pdf"))

  expect_message(
    download_pdfs("/assets/gao-24-106198.pdf",
                  download_dir = tmp.dir, sleep_time = 0),
    "Already exists"
  )
})

test_that("download_htmls() downloads an HTML file", {
  skip_if_not(nchar(Sys.which("curl_firefox147")) > 0)
  skip_on_cran()

  tmp.dir <- file.path(tempdir(), "gao_test_htmls")
  on.exit(unlink(tmp.dir, recursive = TRUE))

  result <- download_htmls("https://www.gao.gov/products/gao-24-106198",
                           target_directory = tmp.dir, sleep_time = 0)

  files <- list.files(tmp.dir, pattern = "\\.html$")
  expect_true(length(files) == 1)
  expect_true(file.size(file.path(tmp.dir, files[1])) > 1000)
})
