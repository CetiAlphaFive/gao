# --- .classify_report_type() ---

test_that(".classify_report_type() identifies modern testimony", {
  expect_equal(.classify_report_type("GAO-24-107436T"), "testimony")
  expect_equal(.classify_report_type("GAO-01-1001T"), "testimony")
})

test_that(".classify_report_type() identifies legacy testimony", {
  expect_equal(.classify_report_type("T-AFMD-87-1"), "testimony")
  expect_equal(.classify_report_type("T-HEHS-00-50"), "testimony")
})

test_that(".classify_report_type() identifies legal decisions", {
  expect_equal(.classify_report_type("B-422122"), "legal_decision")
  expect_equal(.classify_report_type("B-100063"), "legal_decision")
  expect_equal(.classify_report_type("B-163058-25"), "legal_decision")
})

test_that(".classify_report_type() identifies correspondence", {
  expect_equal(.classify_report_type("GAO-24-106335R"), "correspondence")
  expect_equal(.classify_report_type("NSIAD-92-100R"), "correspondence")
})

test_that(".classify_report_type() excludes briefing reports from correspondence", {
  # BR suffix = briefing report, not correspondence
  expect_true(is.na(.classify_report_type("AFMD-86-21BR")))
})

test_that(".classify_report_type() returns NA for standard reports", {
  expect_true(is.na(.classify_report_type("GAO-24-106335")))
  expect_true(is.na(.classify_report_type("GAO-25-107603")))
})

test_that(".classify_report_type() vectorizes", {
  ids <- c("GAO-24-107436T", "B-100063", "GAO-24-106335R", "GAO-24-106335", NA)
  result <- .classify_report_type(ids)
  expect_equal(result, c("testimony", "legal_decision", "correspondence", NA, NA))
})

test_that(".classify_report_type() handles empty and NA input", {
  expect_equal(.classify_report_type(character(0)), character(0))
  expect_true(is.na(.classify_report_type(NA_character_)))
})

# --- .parse_subtitle_addressee() ---

test_that(".parse_subtitle_addressee() parses 'congressional requesters'", {
  result <- .parse_subtitle_addressee("congressional requesters")
  expect_equal(result$requester_type, "congressional_request")
  expect_true(is.na(result$requester_committees))
  expect_true(is.na(result$requester_members))
})

test_that(".parse_subtitle_addressee() parses 'congressional addressees' as statutory", {
  result <- .parse_subtitle_addressee("congressional addressees")
  expect_equal(result$requester_type, "statutory_mandate")
  expect_true(is.na(result$requester_committees))
})

test_that(".parse_subtitle_addressee() parses 'congressional committees' as congressional_request", {
  # "congressional committees" is ambiguous — defaults to congressional_request.
  # The mandate check in .parse_report_html() can override to statutory_mandate.
  result <- .parse_subtitle_addressee("congressional committees")
  expect_equal(result$requester_type, "congressional_request")
  expect_true(is.na(result$requester_committees))
})

test_that(".parse_subtitle_addressee() parses specific committee with role", {
  text <- "the Ranking Member, Committee on Homeland Security and Governmental Affairs, U.S. Senate"
  result <- .parse_subtitle_addressee(text)
  expect_equal(result$requester_type, "congressional_request")
  expect_equal(result$requester_committees,
               "Committee on Homeland Security and Governmental Affairs (Senate)")
  expect_equal(result$requester_members, "Ranking Member")
})

test_that(".parse_subtitle_addressee() parses committee without role", {
  text <- "the Committee on Transportation and Infrastructure, House of Representatives"
  result <- .parse_subtitle_addressee(text)
  expect_equal(result$requester_type, "congressional_request")
  expect_equal(result$requester_committees,
               "Committee on Transportation and Infrastructure (House)")
  expect_true(is.na(result$requester_members))
})

test_that(".parse_subtitle_addressee() handles NA and empty input", {
  result <- .parse_subtitle_addressee(NA_character_)
  expect_true(is.na(result$requester_type))
  result2 <- .parse_subtitle_addressee("")
  expect_true(is.na(result2$requester_type))
})

# --- .parse_highlights_subtitle() ---

test_that(".parse_highlights_subtitle() extracts subtitle from mock HTML", {
  html <- rvest::read_html('
    <html><body>
      <div class="js-endpoint-highlights">
        <div class="field__item">
          Highlights of GAO-25-107603, a report to the Ranking Member,
          Committee on Homeland Security and Governmental Affairs,
          U.S. Senate
          What GAO Found
          Some findings here.
        </div>
      </div>
    </body></html>
  ')
  result <- .parse_highlights_subtitle(html)
  expect_equal(result$requester_type, "congressional_request")
  expect_equal(result$requester_committees,
               "Committee on Homeland Security and Governmental Affairs (Senate)")
})

test_that(".parse_highlights_subtitle() parses 'congressional requesters'", {
  html <- rvest::read_html('
    <html><body>
      <div class="js-endpoint-highlights">
        <div class="field__item">
          Highlights of GAO-25-107108, a report to congressional requesters
          What GAO Found
        </div>
      </div>
    </body></html>
  ')
  result <- .parse_highlights_subtitle(html)
  expect_equal(result$requester_type, "congressional_request")
  expect_true(is.na(result$requester_committees))
})

test_that(".parse_highlights_subtitle() parses 'congressional addressees' as statutory", {
  html <- rvest::read_html('
    <html><body>
      <div class="js-endpoint-highlights">
        <div class="field__item">
          Highlights of GAO-24-106915, a report to congressional addressees
          What GAO Found
        </div>
      </div>
    </body></html>
  ')
  result <- .parse_highlights_subtitle(html)
  expect_equal(result$requester_type, "statutory_mandate")
})

test_that(".parse_highlights_subtitle() returns NA when no highlights section", {
  html <- rvest::read_html("<html><body><p>No highlights</p></body></html>")
  result <- .parse_highlights_subtitle(html)
  expect_true(is.na(result$requester_type))
  expect_true(is.na(result$requester_committees))
  expect_true(is.na(result$requester_members))
})

test_that(".parse_highlights_subtitle() returns NA when no subtitle present", {
  # Mimics gao-22-105502 which has highlights but no subtitle
  html <- rvest::read_html('
    <html><body>
      <div class="js-endpoint-highlights">
        <div class="field__item">
          <h2>What GAO Found</h2>
          <p>Some findings.</p>
        </div>
      </div>
    </body></html>
  ')
  result <- .parse_highlights_subtitle(html)
  expect_true(is.na(result$requester_type))
})

test_that(".parse_highlights_subtitle() uses fallback CSS selector", {
  html <- rvest::read_html('
    <html><body>
      <div class="field--name-product-highlights-custom">
        <div class="field__item">
          Highlights of GAO-25-108085, a report to the Committee on
          Transportation and Infrastructure, House of Representatives
          What GAO Found
        </div>
      </div>
    </body></html>
  ')
  result <- .parse_highlights_subtitle(html)
  expect_equal(result$requester_type, "congressional_request")
  expect_equal(result$requester_committees,
               "Committee on Transportation and Infrastructure (House)")
})

# --- .parse_addressee_block() ---

test_that(".parse_addressee_block() parses single addressee with role", {
  text <- paste(
    "The Honorable Gary C. Peters",
    "Ranking Member",
    "Committee on Homeland Security and Governmental Affairs",
    "United States Senate",
    "",
    "Dear Senator Peters:",
    sep = "\n"
  )
  result <- .parse_addressee_block(text)
  expect_equal(result$requester_type, "congressional_request")
  expect_equal(result$requester_committees,
               "Committee on Homeland Security and Governmental Affairs (Senate)")
  expect_equal(result$requester_members, "Gary C. Peters, Ranking Member")
})

test_that(".parse_addressee_block() parses multiple addressees", {
  text <- paste(
    "The Honorable Roger F. Wicker",
    "Chairman",
    "Committee on Armed Services",
    "United States Senate",
    "",
    "The Honorable Jack Reed",
    "Ranking Member",
    "Committee on Armed Services",
    "United States Senate",
    "",
    "The Honorable Mike Rogers",
    "Chairman",
    "Committee on Armed Services",
    "House of Representatives",
    "",
    "The Honorable Adam Smith",
    "Ranking Member",
    "Committee on Armed Services",
    "House of Representatives",
    "",
    "Dear Chairmen and Ranking Members:",
    sep = "\n"
  )
  result <- .parse_addressee_block(text)
  expect_equal(result$requester_type, "congressional_request")
  # Should have both chambers
  expect_true(grepl("Committee on Armed Services \\(Senate\\)", result$requester_committees))
  expect_true(grepl("Committee on Armed Services \\(House\\)", result$requester_committees))
  # Should have all 4 members
  expect_true(grepl("Roger F. Wicker, Chairman", result$requester_members))
  expect_true(grepl("Jack Reed, Ranking Member", result$requester_members))
  expect_true(grepl("Mike Rogers, Chairman", result$requester_members))
  expect_true(grepl("Adam Smith, Ranking Member", result$requester_members))
})

test_that(".parse_addressee_block() parses multiple committees", {
  text <- paste(
    "The Honorable Shelley Moore Capito",
    "Chairman",
    "Committee on Environment and Public Works",
    "United States Senate",
    "",
    "The Honorable Brett Guthrie",
    "Chairman",
    "Committee on Energy and Commerce",
    "House of Representatives",
    "",
    "The Honorable Sam Graves",
    "Chairman",
    "Committee on Transportation and Infrastructure",
    "House of Representatives",
    sep = "\n"
  )
  result <- .parse_addressee_block(text)
  expect_equal(result$requester_type, "congressional_request")
  committees <- strsplit(result$requester_committees, "; ")[[1]]
  expect_equal(length(committees), 3)
  expect_true("Committee on Environment and Public Works (Senate)" %in% committees)
  expect_true("Committee on Energy and Commerce (House)" %in% committees)
  expect_true("Committee on Transportation and Infrastructure (House)" %in% committees)
})

test_that(".parse_addressee_block() deduplicates committees", {
  text <- paste(
    "The Honorable Roger F. Wicker",
    "Chairman",
    "Committee on Armed Services",
    "United States Senate",
    "",
    "The Honorable Jack Reed",
    "Ranking Member",
    "Committee on Armed Services",
    "United States Senate",
    sep = "\n"
  )
  result <- .parse_addressee_block(text)
  # Same committee listed twice (Chairman + Ranking Member) should be deduplicated
  expect_equal(result$requester_committees, "Committee on Armed Services (Senate)")
  # But both members should be listed
  expect_true(grepl("Roger F. Wicker", result$requester_members))
  expect_true(grepl("Jack Reed", result$requester_members))
})

test_that(".parse_addressee_block() handles Chairwoman role variant", {
  text <- paste(
    "The Honorable Virginia Foxx",
    "Chairwoman",
    "Committee on Education and the Workforce",
    "House of Representatives",
    sep = "\n"
  )
  result <- .parse_addressee_block(text)
  expect_equal(result$requester_type, "congressional_request")
  expect_equal(result$requester_committees,
               "Committee on Education and the Workforce (House)")
  expect_equal(result$requester_members, "Virginia Foxx, Chairwoman")
})

test_that(".parse_addressee_block() returns NA for no addressees", {
  result <- .parse_addressee_block("This report examines federal spending.")
  expect_true(is.na(result$requester_type))
  expect_true(is.na(result$requester_committees))
  expect_true(is.na(result$requester_members))
})

test_that(".parse_addressee_block() handles NA and empty input", {
  result <- .parse_addressee_block(NA_character_)
  expect_true(is.na(result$requester_type))
  result2 <- .parse_addressee_block("")
  expect_true(is.na(result2$requester_type))
})

test_that(".parse_addressee_block() handles PDF whitespace artifacts", {
  # PDF text often has extra spaces
  text <- paste(
    "The Honorable  Gary C.  Peters",
    "Ranking Member",
    "Committee on Homeland Security and Governmental Affairs",
    "United States Senate",
    sep = "\n"
  )
  result <- .parse_addressee_block(text)
  expect_equal(result$requester_type, "congressional_request")
  expect_true(grepl("Committee on Homeland Security", result$requester_committees))
})

# --- .extract_requester_info() ---

test_that(".extract_requester_info() ID type overrides highlights", {
  html <- rvest::read_html('
    <html><body>
      <div class="js-endpoint-highlights">
        <div class="field__item">
          Highlights of GAO-24-107436T, a report to congressional requesters
          What GAO Found
        </div>
      </div>
    </body></html>
  ')
  result <- .extract_requester_info(html, "GAO-24-107436T")
  expect_equal(result$requester_type, "testimony")
})

test_that(".extract_requester_info() falls back to highlights when ID is normal", {
  html <- rvest::read_html('
    <html><body>
      <div class="js-endpoint-highlights">
        <div class="field__item">
          Highlights of GAO-25-107603, a report to the Ranking Member,
          Committee on Homeland Security and Governmental Affairs,
          U.S. Senate
          What GAO Found
        </div>
      </div>
    </body></html>
  ')
  result <- .extract_requester_info(html, "GAO-25-107603")
  expect_equal(result$requester_type, "congressional_request")
  expect_true(grepl("Homeland Security", result$requester_committees))
})

test_that(".extract_requester_info() uses addressee block when available", {
  html <- rvest::read_html('
    <html><body>
      <div class="js-endpoint-highlights">
        <div class="field__item">
          Highlights of GAO-25-107603, a report to congressional requesters
          What GAO Found
        </div>
      </div>
    </body></html>
  ')
  report.text <- paste(
    "The Honorable Gary C. Peters",
    "Ranking Member",
    "Committee on Homeland Security and Governmental Affairs",
    "United States Senate",
    sep = "\n"
  )
  result <- .extract_requester_info(html, "GAO-25-107603", report.text)
  expect_equal(result$requester_type, "congressional_request")
  # Addressee block should provide committee details even though highlights said "requesters"
  expect_true(grepl("Homeland Security", result$requester_committees))
  expect_true(grepl("Gary C. Peters", result$requester_members))
})

test_that(".extract_requester_info() handles NULL page", {
  result <- .extract_requester_info(NULL, "B-422122")
  expect_equal(result$requester_type, "legal_decision")
  expect_true(is.na(result$requester_committees))
})

test_that(".extract_requester_info() returns all NA when no info available", {
  html <- rvest::read_html("<html><body></body></html>")
  result <- .extract_requester_info(html, "GAO-24-106335")
  expect_true(is.na(result$requester_type))
  expect_true(is.na(result$requester_committees))
  expect_true(is.na(result$requester_members))
})
