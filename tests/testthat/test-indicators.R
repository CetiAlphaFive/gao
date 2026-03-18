# --- Column name helpers ---

test_that(".make_topic_colname() produces expected names", {
  expect_equal(.make_topic_colname("National Defense"), "topic_national_defense")
  expect_equal(.make_topic_colname("Agriculture and Food"), "topic_agriculture_and_food")
  expect_equal(.make_topic_colname("GAO Mission and Operations"), "topic_gao_mission_and_operations")
  expect_equal(.make_topic_colname("Tax Policy and Administration"), "topic_tax_policy_and_administration")
})

test_that(".make_agency_colname() produces expected names", {
  expect_equal(.make_agency_colname("Department of Defense"), "agency_department_of_defense")
  expect_equal(.make_agency_colname("Internal Revenue Service"), "agency_internal_revenue_service")
  expect_equal(.make_agency_colname("U.S. Agency for International Development"),
               "agency_u_s_agency_for_international_development")
  expect_equal(.make_agency_colname("Centers for Medicare & Medicaid Services"),
               "agency_centers_for_medicare_medicaid_services")
})

test_that(".topic_levels has 31 unique entries", {
  expect_length(.topic_levels, 31)
  expect_length(unique(.topic_levels), 31)
})

test_that(".agency_levels has 50 unique entries", {
  expect_length(.agency_levels, 50)
  expect_length(unique(.agency_levels), 50)
})

test_that(".indicator_colnames() returns 82 names", {
  cols <- .indicator_colnames()
  expect_length(cols, 82)
  expect_true(all(grepl("^(topic_|agency_)", cols)))
  expect_equal(cols[82], "agency_other")
})

# --- .expand_indicators() ---

test_that(".expand_indicators() adds correct topic columns", {
  df <- data.frame(
    topics = c("National Defense", "Health Care", "National Defense"),
    agencies_affected = NA_character_,
    stringsAsFactors = FALSE
  )
  result <- .expand_indicators(df)
  expect_equal(result$topic_national_defense, c(1L, 0L, 1L))
  expect_equal(result$topic_health_care, c(0L, 1L, 0L))
  expect_equal(result$topic_education, c(0L, 0L, 0L))
})

test_that(".expand_indicators() adds correct agency columns", {
  df <- data.frame(
    topics = NA_character_,
    agencies_affected = c(
      "Department of Defense",
      "Department of Defense; Internal Revenue Service",
      "Department of Defense; Some Unknown Agency"
    ),
    stringsAsFactors = FALSE
  )
  result <- .expand_indicators(df)
  expect_equal(result$agency_department_of_defense, c(1L, 1L, 1L))
  expect_equal(result$agency_internal_revenue_service, c(0L, 1L, 0L))
  expect_equal(result$agency_other, c(0L, 0L, 1L))
})

test_that(".expand_indicators() propagates NA for missing topics", {
  df <- data.frame(
    topics = c(NA_character_, "Energy"),
    agencies_affected = c("Department of Defense", NA_character_),
    stringsAsFactors = FALSE
  )
  result <- .expand_indicators(df)
  # Topic columns: NA for row 1, integers for row 2
  expect_true(is.na(result$topic_national_defense[1]))
  expect_true(is.na(result$topic_energy[1]))
  expect_equal(result$topic_energy[2], 1L)
  expect_equal(result$topic_national_defense[2], 0L)
  # Agency columns: integers for row 1, NA for row 2
  expect_equal(result$agency_department_of_defense[1], 1L)
  expect_true(is.na(result$agency_department_of_defense[2]))
  expect_equal(result$agency_other[1], 0L)
  expect_true(is.na(result$agency_other[2]))
})

test_that(".expand_indicators() handles all-NA input", {
  df <- data.frame(
    topics = NA_character_,
    agencies_affected = NA_character_,
    stringsAsFactors = FALSE
  )
  result <- .expand_indicators(df)
  # All indicator columns should be NA
  for (col in .indicator_colnames()) {
    expect_true(is.na(result[[col]]),
                info = paste("Expected NA for column:", col))
  }
})

test_that("agency_other is 1 when literal 'Other' appears", {
  df <- data.frame(
    topics = NA_character_,
    agencies_affected = "Department of Defense; Other",
    stringsAsFactors = FALSE
  )
  result <- .expand_indicators(df)
  expect_equal(result$agency_department_of_defense, 1L)
  expect_equal(result$agency_other, 1L)
})

test_that(".expand_indicators() on zero-row data.frame", {
  df <- data.frame(
    topics = character(0),
    agencies_affected = character(0),
    stringsAsFactors = FALSE
  )
  result <- .expand_indicators(df)
  expect_equal(nrow(result), 0)
  expect_true(all(.indicator_colnames() %in% names(result)))
})

test_that("multiple agencies: each gets flagged", {
  df <- data.frame(
    topics = NA_character_,
    agencies_affected = "Department of Defense; Internal Revenue Service; Department of Energy",
    stringsAsFactors = FALSE
  )
  result <- .expand_indicators(df)
  expect_equal(result$agency_department_of_defense, 1L)
  expect_equal(result$agency_internal_revenue_service, 1L)
  expect_equal(result$agency_department_of_energy, 1L)
  expect_equal(result$agency_department_of_state, 0L)
  expect_equal(result$agency_other, 0L)
})
