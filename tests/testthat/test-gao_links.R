test_that("gao_links() returns character vector", {
  links <- gao_links()
  expect_type(links, "character")
})
