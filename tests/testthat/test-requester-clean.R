test_that("cleaner strips injected 'GAO' token from committee names", {
  expect_equal(.clean_requester_string("Committee on GAO the Judiciary (Senate)"),
               "Committee on the Judiciary (Senate)")
  expect_equal(.clean_requester_string("Committee on Appropriations (House)"),
               "Committee on Appropriations (House)")  # unchanged
})

test_that("cleaner strips RELEASED noise and fixes OCR mid-word caps", {
  expect_equal(.clean_requester_string("Richard G. LUgar RELEASED (Senate)"),
               "Richard G. Lugar (Senate)")
  expect_equal(.clean_requester_string("Edward Kennedy, Chairman"),
               "Edward Kennedy, Chairman")             # unchanged
})

test_that("cleaner strips RESTRICTED / OCR PESTRICTUD bleed (B2)", {
  expect_equal(.clean_requester_string("Gary C. Peters RESTRICTED (Senate)"),
               "Gary C. Peters (Senate)")
  expect_equal(.clean_requester_string("Gary C. Peters PESTRICTUD (Senate)"),
               "Gary C. Peters (Senate)")
  expect_equal(.clean_requester_string("Gary C. Peters Publicly RESTRICTED"),
               "Gary C. Peters")
})

test_that("cleaner drops a dash-delimited 'Not to be released' stamp (B2)", {
  expect_equal(
    .clean_requester_string("Gary C. Peters - Not to be released until 10 a.m."),
    "Gary C. Peters")
  # The existing "LUgar RELEASED" behavior is preserved (no cut-to-end here).
  expect_equal(.clean_requester_string("Richard G. LUgar RELEASED (Senate)"),
               "Richard G. Lugar (Senate)")
})

test_that("cleaner is NA/empty safe and handles multi-item strings", {
  expect_true(is.na(.clean_requester_string(NA_character_)))
  expect_equal(.clean_requester_string(""), "")
  expect_equal(
    .clean_requester_string("Committee on GAO Finance (Senate); Committee on Ways and Means (House)"),
    "Committee on Finance (Senate); Committee on Ways and Means (House)")
})
