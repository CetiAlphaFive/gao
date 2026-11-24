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


test_that("accented VoteView names match plain GAO spellings", {
  expect_equal(.ascii_name("GONZÁLEZ, Henry Barbosa"), "GONZALEZ, Henry Barbosa")
  expect_equal(.normalize_member_name("GONZÁLEZ, Henry Barbosa", lastfirst = TRUE),
               .normalize_member_name("Henry B. Gonzalez"))
  f <- .requester_party_features("Henry B. Gonzalez", "Committee on Banking (House)",
                                 "1993-06-01")
  expect_equal(f$requester_party, "D")
})

test_that("nicknames and middle names resolve", {
  lk <- .build_party_lookups()
  party <- function(m, d) .requester_party_features(m, NA_character_, d, lk)$requester_party
  expect_equal(party("Bob Dole (Senate)",       "1995-06-01"), "R")  # (Bob)
  expect_equal(party("Bill Bradley (Senate)",   "1995-06-01"), "D")  # William
  expect_equal(party("Strom Thurmond (Senate)", "1995-06-01"), "R")  # middle name
  expect_equal(party("Mitch McConnell (Senate)", "2001-04-30"), "R")
  expect_equal(party("Ted Cruz (Senate)",       "2015-06-01"), "R")
})

test_that("first-name keys beat middle-name keys; true namesakes stay NA", {
  lk <- .build_party_lookups()
  # Denny Smith (R-OR) shares "smith d" only with colleagues' middle names.
  ds <- .requester_party_features("Denny Smith (House)", NA_character_,
                                  "1985-05-20", lk)
  expect_equal(ds$requester_party, "R")
  # 109th House: Jerry Lewis "(Jerry)" and John Lewis both go by "lewis j".
  jl <- .requester_party_features("Jerry Lewis", "Committee on X (House)",
                                  "2005-06-01", lk)
  expect_true(is.na(jl$requester_party))
  expect_false(jl$requester_party_complete %in% TRUE)
})

test_that("party switchers keep their end-of-Congress affiliation", {
  lk <- .build_party_lookups()
  jj <- .requester_party_features("James M. Jeffords (Senate)", NA_character_,
                                  "2002-03-29", lk)
  expect_equal(jj$requester_party, "Other")             # I, caucusing D
  expect_equal(jj$requester_majority_status, "majority") # D-run 107th Senate
  as <- .requester_party_features("Arlen Specter (Senate)", NA_character_,
                                  "2009-09-01", lk)
  expect_equal(as$requester_party, "D")
})

test_that("member chamber annotations set requester_chamber", {
  f <- .requester_party_features("Zzyzx Q. Nobody (House)", NA_character_,
                                 "2010-06-01")
  expect_equal(f$requester_chamber, "House")
  expect_true(is.na(f$requester_party))
  g <- .requester_party_features("Bob Dole (Senate); Zzyzx Nobody (House)",
                                 NA_character_, "1995-06-01")
  expect_equal(g$requester_chamber, "both")
})

test_that("requester_party_complete flags partially resolved requester lists", {
  lk <- .build_party_lookups()
  full <- .requester_party_features("Richard G. Lugar, Chairman; Chairman",
                                    NA_character_, "1995-06-01", lk)
  expect_true(full$requester_party_complete)   # role-only item is ignored
  part <- .requester_party_features("Richard G. Lugar; Zzyzx Nobody",
                                    NA_character_, "1995-06-01", lk)
  expect_equal(part$requester_party, "R")
  expect_false(part$requester_party_complete)
  none <- .requester_party_features(NA_character_, NA_character_, "1995-06-01", lk)
  expect_true(is.na(none$requester_party_complete))
})

test_that("non-caucusing independents get no majority status", {
  # Justin Amash left the GOP in July 2019 and caucused with neither party.
  f <- .requester_party_features("Justin Amash (House)", NA_character_,
                                 "2019-09-01")
  expect_equal(f$requester_party, "Other")
  expect_true(is.na(f$requester_majority_status))
})

test_that("one-word name fragments are unresolved, not matched as surnames", {
  f <- .requester_party_features("Lloyd", "Committee on Finance (Senate)",
                                 "1990-06-01")
  expect_true(is.na(f$requester_party))
  expect_false(f$requester_party_complete %in% TRUE)
})
