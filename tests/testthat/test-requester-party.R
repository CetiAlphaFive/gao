test_that("congress number is computed from a date", {
  expect_equal(.congress_for_date(as.Date("1994-06-01")), 103L)  # 103rd: 1993-95
  expect_equal(.congress_for_date(as.Date("1995-06-01")), 104L)  # 104th: 1995-97
  expect_equal(.congress_for_date(as.Date("1995-01-02")), 103L)  # before Jan 3
  expect_equal(.congress_for_date(as.Date("1995-01-03")), 104L)  # swearing-in
})

test_that("member names normalize to LAST + first-initial keys", {
  expect_equal(.normalize_member_name("Richard G. Lugar"),  "lugar r")
  expect_equal(.normalize_member_name("Edward Kennedy"),    "kennedy e")
  expect_equal(.normalize_member_name("G. V. (Sonny) Montgomery"), "montgomery g")
  expect_equal(.normalize_member_name("Richard G. Lugar, Chairman"), "lugar r")  # role dropped
  expect_equal(.normalize_member_name("Edward Kennedy (Senate)"), "kennedy e")   # chamber dropped
  expect_equal(.normalize_member_name("LUGAR, Richard Green", lastfirst = TRUE), "lugar r")
  expect_true(is.na(.normalize_member_name(NA_character_)))
})

test_that("requester party features resolve against the bundled crosswalk", {
  # single R requester in the 104th-Senate majority
  f1 <- .requester_party_features("Richard G. Lugar, Chairman",
                                  "Committee on Foreign Relations (Senate)", "1995-06-01")
  expect_equal(f1$requester_party, "R")
  expect_equal(f1$requester_majority_status, "majority")
  expect_equal(f1$requester_chamber, "Senate")
  expect_false(f1$requester_bipartisan)

  # bipartisan: R + D
  f2 <- .requester_party_features("Richard G. Lugar; Edward Kennedy",
                                  NA_character_, "1995-06-01")
  expect_equal(f2$requester_party, "mixed")
  expect_true(f2$requester_bipartisan)

  # D requester in the 103rd-Senate majority (pre-1994)
  f3 <- .requester_party_features("Edward Kennedy", "Committee on Labor (Senate)",
                                  "1994-06-01")
  expect_equal(f3$requester_party, "D")
  expect_equal(f3$requester_majority_status, "majority")

  # empty members -> NA party but chamber still inferred from committee
  f4 <- .requester_party_features(NA_character_, "Committee on X (House)", "1996-01-01")
  expect_true(is.na(f4$requester_party))
  expect_equal(f4$requester_chamber, "House")
})

