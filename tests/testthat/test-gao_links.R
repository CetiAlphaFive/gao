test_that("gao_links() returns a data.frame with correct columns", {
  links <- gao_links()
  expect_s3_class(links, "data.frame")
  expect_named(links, c("url", "title", "report_id", "published", "released", "summary", "page_count"))
})
