test_that(".get_curl_bin() finds curl-impersonate", {
  skip_if_not(nchar(Sys.which("curl_firefox147")) > 0,
              "curl-impersonate not installed")
  expect_type(.get_curl_bin(), "character")
})

test_that(".get_curl_bin() respects options", {
  skip_if_not(nchar(Sys.which("curl_firefox147")) > 0)
  withr::local_options(gao.curl_bin = "curl_firefox147")
  expect_equal(.get_curl_bin(), "curl_firefox147")
})

test_that(".get_curl_bin() errors on missing binary", {
  withr::local_options(gao.curl_bin = "nonexistent_binary_xyz")
  expect_error(.get_curl_bin(), "curl-impersonate not found")
})

test_that(".fetch_html() returns an xml_document", {
  skip_if_not(nchar(Sys.which("curl_firefox147")) > 0)
  skip_on_cran()
  page <- .fetch_html("https://www.gao.gov/reports-testimonies")
  expect_s3_class(page, "xml_document")
})

test_that(".scrape_page_links() extracts metadata from search results", {
  html <- rvest::read_html('
    <div class="c-search-result">
      <h4 class="c-search-result__header">
        <a href="/products/gao-24-100">Defense Report</a>
      </h4>
      <span class="d-block text-small">GAO-24-100</span>
      <time datetime="2024-01-15T00:00:00Z">Jan 15, 2024</time>
      <time datetime="2024-02-01T00:00:00Z">Feb 1, 2024</time>
      <div class="c-search-result__summary">A summary of the report.</div>
    </div>
    <div class="c-search-result">
      <h4 class="c-search-result__header">
        <a href="/products/gao-24-200">Health Report</a>
      </h4>
      <span class="d-block text-small">GAO-24-200</span>
      <time datetime="2024-03-10T00:00:00Z">Mar 10, 2024</time>
      <time datetime="2024-04-01T00:00:00Z">Apr 1, 2024</time>
      <div class="c-search-result__body">Another summary.</div>
    </div>
  ')
  result <- .scrape_page_links(html)
  expect_s3_class(result, "data.frame")
  expect_equal(nrow(result), 2)
  expect_named(result, c("url", "title", "report_id", "published", "released", "summary"))
  expect_equal(result$url, c("/products/gao-24-100", "/products/gao-24-200"))
  expect_equal(result$title, c("Defense Report", "Health Report"))
  expect_equal(result$report_id, c("GAO-24-100", "GAO-24-200"))
  expect_equal(result$published, c("2024-01-15", "2024-03-10"))
  expect_equal(result$released, c("2024-02-01", "2024-04-01"))
  expect_equal(result$summary, c("A summary of the report.", "Another summary."))
})

test_that(".scrape_page_links() returns empty data.frame for no results", {
  html <- rvest::read_html("<html><body><p>No results</p></body></html>")
  result <- .scrape_page_links(html)
  expect_s3_class(result, "data.frame")
  expect_equal(nrow(result), 0)
  expect_named(result, c("url", "title", "report_id", "published", "released", "summary"))
})

test_that(".fiscal_year() computes federal fiscal year", {
  # Standard: Jan-Sep stay in same calendar year
  expect_equal(.fiscal_year("2024-01-15"), 2024L)
  expect_equal(.fiscal_year("2024-09-30"), 2024L)
  # Oct-Dec bump to next fiscal year
  expect_equal(.fiscal_year("2023-10-01"), 2024L)
  expect_equal(.fiscal_year("2023-12-31"), 2024L)
})

test_that(".fiscal_year() handles NA and empty input", {
  expect_equal(.fiscal_year(character(0)), integer(0))
  expect_true(is.na(.fiscal_year(NA_character_)))
  expect_true(is.na(.fiscal_year("not-a-date")))
})

test_that(".fiscal_year() vectorizes", {
  dates <- c("2024-01-15", "2023-10-01", NA, "2000-06-15")
  result <- .fiscal_year(dates)
  expect_equal(result, c(2024L, 2024L, NA_integer_, 2000L))
})
