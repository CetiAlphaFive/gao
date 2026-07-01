test_that("issuing division decodes known GAO division prefixes", {
  expect_equal(.gao_issuing_division("NSIAD-94-100"),
               "National Security & International Affairs")
  expect_equal(.gao_issuing_division("T-RCED-95-12"),   # testimony carries division
               "Resources, Community & Economic Development")
  expect_equal(.gao_issuing_division("B-271985"),
               "Legal decision (Comptroller General)")
  expect_equal(.gao_issuing_division("GAO-24-106198"),
               "Post-2000 (division code dropped)")
  expect_equal(.gao_issuing_division("087528"), NA_character_)  # pure-numeric legacy
  expect_equal(.gao_issuing_division("ZZZ-99-1"), "Other/uncommon office")
})

test_that("product type classifies the four channels plus reports", {
  expect_equal(.gao_product_type("NSIAD-94-100"),   "report")
  expect_equal(.gao_product_type("T-HEHS-95-12"),   "testimony")
  expect_equal(.gao_product_type("GAO-24-107436T"), "testimony")
  expect_equal(.gao_product_type("B-271985"),       "legal_decision")
  expect_equal(.gao_product_type("GGD-95-12R"),     "correspondence")
  expect_equal(.gao_product_type("OGC-95-1"),       "legal_other")
  expect_equal(.gao_product_type(NA_character_),    NA_character_)
})
