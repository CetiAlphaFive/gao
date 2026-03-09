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

test_that(".scrape_page_links() extracts product links", {
  html <- rvest::read_html('<a href="/products/gao-24-100">report</a>
                             <a href="/about">about</a>
                             <a href="/products/gao-24-200">report2</a>')
  links <- .scrape_page_links(html)
  expect_equal(links, c("/products/gao-24-100", "/products/gao-24-200"))
})
