# --- .parse_rss() (RSS-based new-report discovery) ---

.mk_rss_fixture <- function() {
  '<?xml version="1.0" encoding="UTF-8"?>
  <rss version="2.0">
    <channel>
      <title>GAO Reports and Testimonies</title>
      <item>
        <title>Defense Spending Oversight</title>
        <link>https://www.gao.gov/products/gao-26-109098?utm_source=rss&amp;utm_medium=feed</link>
        <pubDate>Wed, 15 Jul 2026 07:18:12 -0400</pubDate>
        <guid>https://www.gao.gov/products/gao-26-109098</guid>
      </item>
      <item>
        <title>Veterans Health Care Access</title>
        <link>https://www.gao.gov/products/gao-26-109099</link>
        <pubDate>Tue, 14 Jul 2026 09:00:00 -0400</pubDate>
        <guid>https://www.gao.gov/products/gao-26-109099</guid>
      </item>
    </channel>
  </rss>'
}

test_that(".parse_rss() parses items into a data.frame with url/title/published/report_id", {
  skip_if_not_installed("xml2")
  result <- .parse_rss(.mk_rss_fixture())
  expect_s3_class(result, "data.frame")
  expect_named(result, c("url", "title", "published", "report_id"))
  expect_equal(nrow(result), 2)
})

test_that(".parse_rss() strips query strings when normalizing url (B1)", {
  skip_if_not_installed("xml2")
  result <- .parse_rss(.mk_rss_fixture())
  expect_equal(result$url[1], "https://www.gao.gov/products/gao-26-109098")
  expect_false(grepl("\\?", result$url[1]))
  # A link with no query string is left unchanged
  expect_equal(result$url[2], "https://www.gao.gov/products/gao-26-109099")
})

test_that(".parse_rss() converts pubDate (RFC-822) to ISO dates", {
  skip_if_not_installed("xml2")
  result <- .parse_rss(.mk_rss_fixture())
  expect_equal(result$published, c("2026-07-15", "2026-07-14"))
})

test_that(".parse_rss() captures item titles", {
  skip_if_not_installed("xml2")
  result <- .parse_rss(.mk_rss_fixture())
  expect_equal(result$title, c("Defense Spending Oversight",
                               "Veterans Health Care Access"))
})

test_that(".parse_rss() errors loudly on a feed with 0 items (B2)", {
  skip_if_not_installed("xml2")
  empty.feed <- '<?xml version="1.0"?><rss version="2.0"><channel><title>Empty</title></channel></rss>'
  expect_error(.parse_rss(empty.feed),
               "GAO RSS feed unreachable or returned no items")
})

test_that(".parse_rss() errors loudly on malformed/unparseable XML (B2)", {
  skip_if_not_installed("xml2")
  expect_error(.parse_rss("this is not xml <<<>>>"),
               "GAO RSS feed unreachable or returned no items")
  expect_error(.parse_rss(""),
               "GAO RSS feed unreachable or returned no items")
})

test_that(".parse_rss() errors when items exist but none have a usable link", {
  skip_if_not_installed("xml2")
  no.link.feed <- '<?xml version="1.0"?>
  <rss version="2.0"><channel>
    <item><title>No link here</title><pubDate>Wed, 15 Jul 2026 07:18:12 -0400</pubDate></item>
  </channel></rss>'
  expect_error(.parse_rss(no.link.feed),
               "GAO RSS feed unreachable or returned no items")
})

test_that(".parse_rss() drops individual items missing a link but keeps the rest", {
  skip_if_not_installed("xml2")
  mixed.feed <- '<?xml version="1.0"?>
  <rss version="2.0"><channel>
    <item><title>No link</title><pubDate>Wed, 15 Jul 2026 07:18:12 -0400</pubDate></item>
    <item><title>Has link</title><link>https://www.gao.gov/products/gao-26-1</link>
      <pubDate>Tue, 14 Jul 2026 09:00:00 -0400</pubDate></item>
  </channel></rss>'
  result <- .parse_rss(mixed.feed)
  expect_equal(nrow(result), 1)
  expect_equal(result$url, "https://www.gao.gov/products/gao-26-1")
})

test_that(".parse_rss() returns NA published for an unparseable pubDate", {
  skip_if_not_installed("xml2")
  bad.date.feed <- '<?xml version="1.0"?>
  <rss version="2.0"><channel>
    <item><title>Bad date</title><link>https://www.gao.gov/products/gao-26-2</link>
      <pubDate>not a date</pubDate></item>
  </channel></rss>'
  result <- .parse_rss(bad.date.feed)
  expect_true(is.na(result$published))
})

test_that(".parse_rss() derives report_id from a /products/<id> url, upper-cased", {
  skip_if_not_installed("xml2")
  result <- .parse_rss(.mk_rss_fixture())
  expect_equal(result$report_id, c("GAO-26-109098", "GAO-26-109099"))
})

test_that(".parse_rss() strips the query string before deriving report_id (bm-verify cannot leak in)", {
  skip_if_not_installed("xml2")
  challenge.feed <- '<?xml version="1.0"?>
  <rss version="2.0"><channel>
    <item><title>Challenge suffix</title>
      <link>https://www.gao.gov/products/gao-26-109098?bm-verify=abc123</link>
      <pubDate>Wed, 15 Jul 2026 07:18:12 -0400</pubDate></item>
  </channel></rss>'
  result <- .parse_rss(challenge.feed)
  expect_equal(result$url, "https://www.gao.gov/products/gao-26-109098")
  expect_equal(result$report_id, "GAO-26-109098")
})

test_that(".parse_rss() returns NA report_id for a non-product/edge url", {
  skip_if_not_installed("xml2")
  edge.feed <- '<?xml version="1.0"?>
  <rss version="2.0"><channel>
    <item><title>Not a product page</title>
      <link>https://www.gao.gov/reports-testimonies</link>
      <pubDate>Wed, 15 Jul 2026 07:18:12 -0400</pubDate></item>
  </channel></rss>'
  result <- .parse_rss(edge.feed)
  expect_true(is.na(result$report_id))
})

# --- .fetch_rss_links() (live network smoke test) ---

test_that(".fetch_rss_links() fetches and parses the live GAO RSS feed", {
  skip_if_not(nchar(Sys.which("curl_firefox147")) > 0)
  skip_on_cran()
  result <- .fetch_rss_links()
  expect_s3_class(result, "data.frame")
  expect_named(result, c("url", "title", "published", "report_id"))
  expect_true(nrow(result) > 0)
  expect_true(all(grepl("^https://www\\.gao\\.gov/", result$url)))
})

# --- .parse_rfc822_date() ---

test_that(".parse_rfc822_date() parses RFC-822 pubDate strings locale-independently", {
  expect_equal(.parse_rfc822_date("Wed, 15 Jul 2026 07:18:12 -0400"), "2026-07-15")
  expect_equal(.parse_rfc822_date("Tue, 14 Jul 2026 09:00:00 -0400"), "2026-07-14")
  expect_equal(.parse_rfc822_date("01 Jan 2000 00:00:00 GMT"), "2000-01-01")
})

test_that(".parse_rfc822_date() returns NA on failure", {
  expect_true(is.na(.parse_rfc822_date(NA_character_)))
  expect_true(is.na(.parse_rfc822_date("")))
  expect_true(is.na(.parse_rfc822_date("not a date")))
})

# --- update_links() loud-failure contract ---

test_that("update_links() propagates a loud RSS failure (mocked)", {
  testthat::local_mocked_bindings(
    .fetch_rss_links = function(...) {
      stop("GAO RSS feed unreachable or returned no items -- ",
           "feed URL or format may have changed", call. = FALSE)
    })
  expect_error(update_links(verbose = FALSE),
               "GAO RSS feed unreachable or returned no items")
})

test_that("update_links() adds new RSS rows not already in the bundled data (mocked)", {
  known <- gao_links()
  skip_if(nrow(known) == 0, "No bundled link data available")
  fake.url <- "https://www.gao.gov/products/gao-99-999999-does-not-exist"
  stopifnot(!fake.url %in% known$url)

  testthat::local_mocked_bindings(
    .fetch_rss_links = function(...) {
      data.frame(url = fake.url, title = "Fake Report",
                published = "2026-07-15", stringsAsFactors = FALSE)
    })

  result <- update_links(verbose = FALSE)
  expect_true(fake.url %in% result$url)
  expect_equal(nrow(result), nrow(known) + 1L)
  expect_named(result, names(known))
  expect_equal(result$url, sort(unique(result$url)))
})
