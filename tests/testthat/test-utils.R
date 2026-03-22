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
  expect_named(result, c("url", "title", "report_id", "published", "released", "summary", "topics", "subject_terms"))
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
  expect_named(result, c("url", "title", "report_id", "published", "released", "summary", "topics", "subject_terms"))
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

# --- .fiscal_year_from_url() ---

test_that(".fiscal_year_from_url() parses modern GAO URLs", {
  urls <- c(
    "https://www.gao.gov/products/gao-24-106198",
    "/products/gao-20-100",
    "https://www.gao.gov/products/gao-05-1234"
  )
  expect_equal(.fiscal_year_from_url(urls), c(2024L, 2020L, 2005L))
})

test_that(".fiscal_year_from_url() returns NA for legacy URLs", {
  legacy <- c(
    "/products/aimd-98-123",
    "/products/ggd-96-100",
    "https://www.gao.gov/products/t-hehs-00-50"
  )
  expect_true(all(is.na(.fiscal_year_from_url(legacy))))
})

test_that(".fiscal_year_from_url() handles century boundary", {
  expect_equal(.fiscal_year_from_url("/products/gao-00-100"), 2000L)
  expect_equal(.fiscal_year_from_url("/products/gao-49-100"), 2049L)
  expect_equal(.fiscal_year_from_url("/products/gao-50-100"), 1950L)
  expect_equal(.fiscal_year_from_url("/products/gao-99-100"), 1999L)
})

# --- .infer_fiscal_year() ---

test_that(".infer_fiscal_year() prefers published date when available", {
  dates <- c("2024-01-15", "2023-10-01")
  urls <- c("/products/gao-20-100", "/products/gao-20-200")
  result <- .infer_fiscal_year(dates, urls)
  # Should use date-based FY (2024, 2024), not URL-based (2020, 2020)
  expect_equal(result, c(2024L, 2024L))
})

test_that(".infer_fiscal_year() falls back to URL when published is NA", {
  dates <- c(NA_character_, NA_character_, "2024-01-15")
  urls <- c("/products/gao-22-100", "/products/gao-23-200", "/products/gao-20-300")
  result <- .infer_fiscal_year(dates, urls)
  expect_equal(result, c(2022L, 2023L, 2024L))
})

test_that(".infer_fiscal_year() returns NA when both sources are NA", {
  dates <- c(NA_character_)
  urls <- c("/products/aimd-98-100")
  result <- .infer_fiscal_year(dates, urls)
  expect_true(is.na(result))
})

# --- .extract_pdf_url() ---

test_that(".extract_pdf_url() extracts non-highlights PDF link", {
  html <- rvest::read_html('
    <html><body>
      <a href="/assets/gao-24-106335-highlights.pdf">Highlights</a>
      <a href="/assets/gao-24-106335.pdf">Full Report</a>
    </body></html>
  ')
  expect_equal(.extract_pdf_url(html), "/assets/gao-24-106335.pdf")
})

test_that(".extract_pdf_url() works with legacy PDF paths", {
  html <- rvest::read_html('
    <html><body>
      <a href="/assets/b-163058-25.pdf">Full Report</a>
    </body></html>
  ')
  expect_equal(.extract_pdf_url(html), "/assets/b-163058-25.pdf")
})

test_that(".extract_pdf_url() returns NA when no PDFs on page", {
  html <- rvest::read_html("<html><body><a href='/about'>About</a></body></html>")
  expect_true(is.na(.extract_pdf_url(html)))
})

test_that(".extract_pdf_url() returns NA when only highlights PDF exists", {
  html <- rvest::read_html('
    <html><body>
      <a href="/assets/gao-24-100-highlights.pdf">Highlights</a>
    </body></html>
  ')
  expect_true(is.na(.extract_pdf_url(html)))
})

# --- .scrape_report_metadata() ---

test_that(".scrape_report_metadata() extracts metadata from modern page", {
  html <- rvest::read_html('
    <html>
    <head>
      <meta property="og:title" content="U.S. GAO - Defense Spending Report" />
      <meta name="description" content="This report examines defense spending." />
    </head>
    <body>
      <span class="d-block text-small">
        <strong>GAO-24-106335</strong>
        Published: Jan 15, 2024
        Publicly Released: Feb 01, 2024
      </span>
      <div class="views-field-field-topic">
        <div class="field-content"><a href="/topics/defense">Defense</a></div>
        <div class="field-content"><a href="/topics/budget">Budget</a></div>
      </div>
      <div class="views-field-field-subject-term">
        <div class="field-content"><span>Military spending</span></div>
        <div class="field-content"><span>Appropriations</span></div>
      </div>
      <a href="/assets/gao-24-106335.pdf">Full Report PDF</a>
    </body>
    </html>
  ')
  result <- .scrape_report_metadata(html)
  expect_s3_class(result, "data.frame")
  expect_equal(nrow(result), 1)
  expect_equal(result$title, "Defense Spending Report")
  expect_equal(result$report_id, "GAO-24-106335")
  expect_equal(result$published, "2024-01-15")
  expect_equal(result$released, "2024-02-01")
  expect_equal(result$summary, "This report examines defense spending.")
  expect_equal(result$topics, "Defense; Budget")
  expect_equal(result$subject_terms, "Military spending; Appropriations")
  expect_false(result$has_recommendations)
  expect_equal(result$n_recommendations, 0L)
  expect_false(result$has_matters)
  expect_equal(result$n_matters, 0L)
  expect_equal(result$pdf_url, "/assets/gao-24-106335.pdf")
})

test_that(".scrape_report_metadata() handles legacy page without topics", {
  html <- rvest::read_html('
    <html>
    <head>
      <meta property="og:title" content="U.S. GAO - Veterans Benefits" />
      <meta name="description" content="A review of veterans benefits." />
    </head>
    <body>
      <span class="d-block text-small">
        Published: Mar 10, 2001
        Publicly Released: Apr 05, 2001
      </span>
    </body>
    </html>
  ')
  result <- .scrape_report_metadata(html)
  expect_equal(result$title, "Veterans Benefits")
  expect_true(is.na(result$report_id))
  expect_equal(result$published, "2001-03-10")
  expect_equal(result$released, "2001-04-05")
  expect_equal(result$summary, "A review of veterans benefits.")
  expect_true(is.na(result$topics))
  expect_true(is.na(result$subject_terms))
  expect_false(result$has_recommendations)
  expect_equal(result$n_recommendations, 0L)
  expect_true(is.na(result$pdf_url))
})

test_that(".scrape_report_metadata() returns NA/FALSE for missing fields", {
  html <- rvest::read_html("<html><head></head><body></body></html>")
  result <- .scrape_report_metadata(html)
  expect_equal(nrow(result), 1)
  expect_true(is.na(result$title))
  expect_true(is.na(result$report_id))
  expect_true(is.na(result$published))
  expect_true(is.na(result$released))
  expect_true(is.na(result$summary))
  expect_true(is.na(result$topics))
  expect_true(is.na(result$subject_terms))
  expect_false(result$has_recommendations)
  expect_equal(result$n_recommendations, 0L)
  expect_false(result$has_matters)
  expect_equal(result$n_matters, 0L)
  expect_true(is.na(result$agencies_affected))
  expect_true(is.na(result$pdf_url))
})

# --- Recommendation & matter extraction ---

test_that(".scrape_report_metadata() extracts executive recommendations", {
  html <- rvest::read_html('
    <html><head>
      <meta property="og:title" content="U.S. GAO - Test Report" />
      <meta name="description" content="A test report." />
    </head><body>
      <section class="view--recommendations--block-1">
        <div class="view--recommendations--inner">
          <h2>Recommendations for Executive Action</h2>
          <table class="views-table">
            <thead><tr>
              <th class="views-field views-field-name">Agency Affected</th>
              <th class="views-field views-field-field-recommendation">Recommendation</th>
            </tr></thead>
            <tbody>
              <tr>
                <td class="views-field views-field-name">Department of Defense</td>
                <td class="views-field views-field-field-recommendation">Rec 1</td>
              </tr>
              <tr>
                <td class="views-field views-field-name">Department of Defense</td>
                <td class="views-field views-field-field-recommendation">Rec 2</td>
              </tr>
              <tr>
                <td class="views-field views-field-name">Internal Revenue Service</td>
                <td class="views-field views-field-field-recommendation">Rec 3</td>
              </tr>
            </tbody>
          </table>
        </div>
      </section>
    </body></html>
  ')
  result <- .scrape_report_metadata(html)
  expect_true(result$has_recommendations)
  expect_equal(result$n_recommendations, 3L)
  expect_false(result$has_matters)
  expect_equal(result$n_matters, 0L)
  expect_equal(result$agencies_affected, "Department of Defense; Internal Revenue Service")
})

test_that(".scrape_report_metadata() extracts matters for Congress", {
  html <- rvest::read_html('
    <html><head>
      <meta property="og:title" content="U.S. GAO - Matter Report" />
      <meta name="description" content="A matter report." />
    </head><body>
      <section class="view--recommendations--block-3">
        <div class="view--recommendations--inner">
          <h2>Matter for Congressional Consideration</h2>
          <table class="views-table">
            <thead><tr>
              <th class="views-field views-field-field-recommendation">Matter</th>
              <th class="views-field views-field-field-status-code">Status</th>
            </tr></thead>
            <tbody>
              <tr>
                <td class="views-field views-field-field-recommendation">Matter 1</td>
                <td class="views-field views-field-field-status-code">Open</td>
              </tr>
              <tr>
                <td class="views-field views-field-field-recommendation">Matter 2</td>
                <td class="views-field views-field-field-status-code">Closed</td>
              </tr>
            </tbody>
          </table>
        </div>
      </section>
    </body></html>
  ')
  result <- .scrape_report_metadata(html)
  expect_false(result$has_recommendations)
  expect_equal(result$n_recommendations, 0L)
  expect_true(result$has_matters)
  expect_equal(result$n_matters, 2L)
  expect_true(is.na(result$agencies_affected))
})

test_that(".scrape_report_metadata() handles both recommendations and matters", {
  html <- rvest::read_html('
    <html><head>
      <meta property="og:title" content="U.S. GAO - Both Report" />
      <meta name="description" content="A report with both." />
    </head><body>
      <section class="view--recommendations--block-3">
        <div class="view--recommendations--inner">
          <h2>Matter for Congressional Consideration</h2>
          <table class="views-table"><tbody>
            <tr><td class="views-field views-field-field-recommendation">M1</td></tr>
          </tbody></table>
        </div>
      </section>
      <section class="view--recommendations--block-1">
        <div class="view--recommendations--inner">
          <h2>Recommendations for Executive Action</h2>
          <table class="views-table"><tbody>
            <tr>
              <td class="views-field views-field-name">Agency A</td>
              <td class="views-field views-field-field-recommendation">R1</td>
            </tr>
            <tr>
              <td class="views-field views-field-name">Agency B</td>
              <td class="views-field views-field-field-recommendation">R2</td>
            </tr>
          </tbody></table>
        </div>
      </section>
    </body></html>
  ')
  result <- .scrape_report_metadata(html)
  expect_true(result$has_recommendations)
  expect_equal(result$n_recommendations, 2L)
  expect_true(result$has_matters)
  expect_equal(result$n_matters, 1L)
  expect_equal(result$agencies_affected, "Agency A; Agency B")
})

test_that(".scrape_report_metadata() returns new columns in modern page test", {
  # Verify the modern page test still passes and includes new columns
  html <- rvest::read_html("<html><head></head><body></body></html>")
  result <- .scrape_report_metadata(html)
  expect_true("has_recommendations" %in% names(result))
  expect_true("n_recommendations" %in% names(result))
  expect_true("has_matters" %in% names(result))
  expect_true("n_matters" %in% names(result))
  expect_true("agencies_affected" %in% names(result))
  expect_true("pdf_url" %in% names(result))
})
