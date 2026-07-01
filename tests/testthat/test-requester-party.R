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

test_that("multi-word/hyphenated/suffixed surnames reduce to the last token (A1, A6)", {
  # Runtime (First Last) and build (LAST, First) conventions must agree.
  expect_equal(.normalize_member_name("Chris Van Hollen"),          "hollen c")
  expect_equal(.normalize_member_name("Ileana Ros-Lehtinen"),       "lehtinen i")
  expect_equal(.normalize_member_name("E. de la Garza"),            "garza e")
  expect_equal(.normalize_member_name("Debbie Wasserman Schultz"),  "schultz d")
  expect_equal(.normalize_member_name("Mario Diaz-Balart"),         "balart m")
  # Generational suffix stripped whether before or after the comma-role.
  expect_equal(.normalize_member_name("John D. Dingell, Jr."),      "dingell j")
  expect_equal(.normalize_member_name("John D. Dingell Jr."),       "dingell j")
  expect_equal(.normalize_member_name("Sam Smith III"),             "smith s")
})

test_that("build-mode and runtime keys are identical for hard surnames (A1)", {
  pairs <- list(
    c("VAN HOLLEN, Christopher",   "Chris Van Hollen"),
    c("ROS-LEHTINEN, Ileana",      "Ileana Ros-Lehtinen"),
    c("DE LA GARZA, Eligio",       "E. de la Garza"),
    c("WASSERMAN SCHULTZ, Debbie", "Debbie Wasserman Schultz"),
    c("DINGELL, John David, Jr.",  "John D. Dingell, Jr.")
  )
  for (p in pairs) {
    build.key <- .normalize_member_name(p[1], lastfirst = TRUE)
    run.key   <- .normalize_member_name(p[2], lastfirst = FALSE)
    expect_identical(build.key, run.key, info = p[2])
  }
})

test_that("the bundled crosswalk carries a caucus column (A2, A5)", {
  expect_true("caucus" %in% names(.member_party))
  # A caucusing independent (Bernie Sanders, ICPSR 29147) is party 'Other',
  # caucus 'D'.
  s <- .member_party[.member_party$congress == 117 &
                     .member_party$chamber == "Senate" &
                     .member_party$match_key == "sanders b", ]
  expect_true(nrow(s) >= 1)
  expect_equal(unique(s$party),  "Other")
  expect_equal(unique(s$caucus), "D")
})

test_that("Senate majority table is corrected for near-ties (A2)", {
  lk <- .build_party_lookups()
  sen <- function(cong) get0(paste0(cong, "|Senate"), envir = lk$maj,
                             inherits = FALSE, ifnotfound = NA_character_)
  expect_equal(sen(110), "D")   # 110th Senate: D (was mis-tallied)
  expect_equal(sen(117), "D")   # 117th Senate: D on the VP tie-break
  expect_equal(sen(112), "D")   # 112th Senate: D
  expect_equal(sen(104), "R")   # 104th Senate: R (unchanged)
  expect_equal(sen(103), "D")   # 103rd Senate: D (unchanged)
})

test_that("chamber-aware lookup disambiguates House/Senate namesakes (A3, A4)", {
  lk <- .build_party_lookups()
  # 117th: Mark Kelly (D, Senate) vs Mike Kelly (R, House) share key "kelly m".
  sen <- .requester_party_features("Mark Kelly", "Committee on X (Senate)",
                                   "2021-06-01", lk)
  hou <- .requester_party_features("Mike Kelly", "Committee on X (House)",
                                   "2021-06-01", lk)
  expect_equal(sen$requester_party, "D")
  expect_equal(sen$requester_majority_status, "majority")  # D holds the Senate
  expect_equal(hou$requester_party, "R")
  expect_equal(hou$requester_majority_status, "minority")  # D holds the House
})

test_that("independents are labeled 'Other' with caucus-based majority (A5)", {
  lk <- .build_party_lookups()
  # Bernie Sanders (I-VT) caucuses D; 117th Senate majority is D.
  bs <- .requester_party_features("Bernard Sanders", "Committee on X (Senate)",
                                  "2021-06-01", lk)
  expect_equal(bs$requester_party, "Other")
  expect_false(bs$requester_bipartisan)
  expect_equal(bs$requester_majority_status, "majority")

  # 115th Senate majority is R, so an independent caucusing D is minority; the
  # chamber-less fallback still resolves majority via the resolved chamber.
  ak <- .requester_party_features("Angus King", NA_character_, "2017-06-01", lk)
  expect_equal(ak$requester_party, "Other")
  expect_equal(ak$requester_majority_status, "minority")
})

