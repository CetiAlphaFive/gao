# Get Bundled GAO Report Data

Returns a data.frame of GAO report metadata bundled with the package.

## Usage

``` r
gao_links()
```

## Value

A data.frame with columns: url, title, report_id, published, released,
summary, page_count (integer, may be `NA` for reports without a matching
PDF in the bundled archive), topics, subject_terms, has_recommendations
(logical), n_recommendations (integer), has_matters (logical), n_matters
(integer), agencies_affected (character, semicolon-separated), plus 82
integer indicator columns: 31 `topic_*` columns (one per topic), 50
`agency_*` columns (one per top-50 agency), and `agency_other` (1 if any
non-top-50 agency appears). Indicator columns are `NA_integer_` where
the source field is missing.

## Examples

``` r
reports <- gao_links()
nrow(reports)
#> [1] 56270
head(reports)
#>                                   url
#> 1 https://www.gao.gov/products/087286
#> 2 https://www.gao.gov/products/087364
#> 3 https://www.gao.gov/products/087365
#> 4 https://www.gao.gov/products/087528
#> 5 https://www.gao.gov/products/087529
#> 6 https://www.gao.gov/products/087530
#>                                                                                                                                                                                  title
#> 1                                                                                                        Request for Exemption from Standard Authorization Process on Security Grounds
#> 2                                                                                                                                       Comments on TVA Treasurer Accounts and Records
#> 3 Request for Advance Decision as to Availability of Pending Appropriation for Credit of 5 Percent to Salary Accounts of Civilian Professors and Instructors at the U.S. Naval Academy
#> 4                                                                                                                                             Comptroller General's Annual Report 1965
#> 5                                                                                                                                             Comptroller General's Annual Report 1970
#> 6                                                                                                                                             Comptroller General's Annual Report 1966
#>   report_id  published   released
#> 1    087286 1944-11-13 1944-11-13
#> 2    087364 1942-09-21 1950-09-21
#> 3    087365 1936-06-08 1936-06-08
#> 4    087528 1966-01-10 1966-01-10
#> 5    087529 1971-01-21 1971-01-21
#> 6    087530 1967-01-10 1967-01-10
#>                                                                                                                                                    summary
#> 1   GAO commented on a Department of Defense (DOD) request for exemption from the standard way funds were advanced to its national defense project. DOD...
#> 2        GAO commented on the bonding of Tennessee Valley Authority (TVA) agent officers and its internal control procedures concerning the handling of...
#> 3  GAO commented on whether funds from the Navy's 1937 appropriations act were available to pay the salaries of civilian professors and instructors for...
#> 4 GAO reported on its activities for the fiscal year ended June 30, 1965. GAO highlighted its: (1) assistance to Congress; (2) audits of civil, defense...
#> 5 GAO reported on its activities for the fiscal year ended June 30, 1970. GAO highlighted its: (1) assistance to Congress; (2) audits of civil, defense...
#> 6 GAO reported on its activities for the fiscal year ended June 30, 1966. GAO highlighted its: (1) assistance to Congress; (2) audits of defense, civil...
#>   page_count topics subject_terms has_recommendations n_recommendations
#> 1          2   <NA>          <NA>               FALSE                 0
#> 2         NA   <NA>          <NA>               FALSE                 0
#> 3         NA   <NA>          <NA>               FALSE                 0
#> 4        399   <NA>          <NA>               FALSE                 0
#> 5        179   <NA>          <NA>               FALSE                 0
#> 6        315   <NA>          <NA>               FALSE                 0
#>   has_matters n_matters agencies_affected topic_agriculture_and_food
#> 1       FALSE         0              <NA>                         NA
#> 2       FALSE         0              <NA>                         NA
#> 3       FALSE         0              <NA>                         NA
#> 4       FALSE         0              <NA>                         NA
#> 5       FALSE         0              <NA>                         NA
#> 6       FALSE         0              <NA>                         NA
#>   topic_auditing_and_financial_management topic_budget_and_spending
#> 1                                      NA                        NA
#> 2                                      NA                        NA
#> 3                                      NA                        NA
#> 4                                      NA                        NA
#> 5                                      NA                        NA
#> 6                                      NA                        NA
#>   topic_business_regulation_and_consumer_protection topic_economic_development
#> 1                                                NA                         NA
#> 2                                                NA                         NA
#> 3                                                NA                         NA
#> 4                                                NA                         NA
#> 5                                                NA                         NA
#> 6                                                NA                         NA
#>   topic_education topic_employment topic_energy topic_equal_opportunity
#> 1              NA               NA           NA                      NA
#> 2              NA               NA           NA                      NA
#> 3              NA               NA           NA                      NA
#> 4              NA               NA           NA                      NA
#> 5              NA               NA           NA                      NA
#> 6              NA               NA           NA                      NA
#>   topic_financial_markets_and_institutions topic_gao_mission_and_operations
#> 1                                       NA                               NA
#> 2                                       NA                               NA
#> 3                                       NA                               NA
#> 4                                       NA                               NA
#> 5                                       NA                               NA
#> 6                                       NA                               NA
#>   topic_government_operations topic_health_care topic_homeland_security
#> 1                          NA                NA                      NA
#> 2                          NA                NA                      NA
#> 3                          NA                NA                      NA
#> 4                          NA                NA                      NA
#> 5                          NA                NA                      NA
#> 6                          NA                NA                      NA
#>   topic_housing topic_human_capital topic_information_management
#> 1            NA                  NA                           NA
#> 2            NA                  NA                           NA
#> 3            NA                  NA                           NA
#> 4            NA                  NA                           NA
#> 5            NA                  NA                           NA
#> 6            NA                  NA                           NA
#>   topic_information_security topic_information_technology
#> 1                         NA                           NA
#> 2                         NA                           NA
#> 3                         NA                           NA
#> 4                         NA                           NA
#> 5                         NA                           NA
#> 6                         NA                           NA
#>   topic_international_affairs topic_justice_and_law_enforcement
#> 1                          NA                                NA
#> 2                          NA                                NA
#> 3                          NA                                NA
#> 4                          NA                                NA
#> 5                          NA                                NA
#> 6                          NA                                NA
#>   topic_national_defense topic_natural_resources_and_environment
#> 1                     NA                                      NA
#> 2                     NA                                      NA
#> 3                     NA                                      NA
#> 4                     NA                                      NA
#> 5                     NA                                      NA
#> 6                     NA                                      NA
#>   topic_retirement_security topic_science_and_technology topic_space
#> 1                        NA                           NA          NA
#> 2                        NA                           NA          NA
#> 3                        NA                           NA          NA
#> 4                        NA                           NA          NA
#> 5                        NA                           NA          NA
#> 6                        NA                           NA          NA
#>   topic_tax_policy_and_administration topic_telecommunications
#> 1                                  NA                       NA
#> 2                                  NA                       NA
#> 3                                  NA                       NA
#> 4                                  NA                       NA
#> 5                                  NA                       NA
#> 6                                  NA                       NA
#>   topic_transportation topic_veterans topic_worker_and_family_assistance
#> 1                   NA             NA                                 NA
#> 2                   NA             NA                                 NA
#> 3                   NA             NA                                 NA
#> 4                   NA             NA                                 NA
#> 5                   NA             NA                                 NA
#> 6                   NA             NA                                 NA
#>   agency_board_of_governors agency_centers_for_medicare_medicaid_services
#> 1                        NA                                            NA
#> 2                        NA                                            NA
#> 3                        NA                                            NA
#> 4                        NA                                            NA
#> 5                        NA                                            NA
#> 6                        NA                                            NA
#>   agency_department_of_agriculture agency_department_of_commerce
#> 1                               NA                            NA
#> 2                               NA                            NA
#> 3                               NA                            NA
#> 4                               NA                            NA
#> 5                               NA                            NA
#> 6                               NA                            NA
#>   agency_department_of_defense agency_department_of_education
#> 1                           NA                             NA
#> 2                           NA                             NA
#> 3                           NA                             NA
#> 4                           NA                             NA
#> 5                           NA                             NA
#> 6                           NA                             NA
#>   agency_department_of_energy agency_department_of_health_and_human_services
#> 1                          NA                                             NA
#> 2                          NA                                             NA
#> 3                          NA                                             NA
#> 4                          NA                                             NA
#> 5                          NA                                             NA
#> 6                          NA                                             NA
#>   agency_department_of_homeland_security
#> 1                                     NA
#> 2                                     NA
#> 3                                     NA
#> 4                                     NA
#> 5                                     NA
#> 6                                     NA
#>   agency_department_of_housing_and_urban_development
#> 1                                                 NA
#> 2                                                 NA
#> 3                                                 NA
#> 4                                                 NA
#> 5                                                 NA
#> 6                                                 NA
#>   agency_department_of_justice agency_department_of_labor
#> 1                           NA                         NA
#> 2                           NA                         NA
#> 3                           NA                         NA
#> 4                           NA                         NA
#> 5                           NA                         NA
#> 6                           NA                         NA
#>   agency_department_of_state agency_department_of_the_air_force
#> 1                         NA                                 NA
#> 2                         NA                                 NA
#> 3                         NA                                 NA
#> 4                         NA                                 NA
#> 5                         NA                                 NA
#> 6                         NA                                 NA
#>   agency_department_of_the_army agency_department_of_the_interior
#> 1                            NA                                NA
#> 2                            NA                                NA
#> 3                            NA                                NA
#> 4                            NA                                NA
#> 5                            NA                                NA
#> 6                            NA                                NA
#>   agency_department_of_the_navy agency_department_of_the_treasury
#> 1                            NA                                NA
#> 2                            NA                                NA
#> 3                            NA                                NA
#> 4                            NA                                NA
#> 5                            NA                                NA
#> 6                            NA                                NA
#>   agency_department_of_transportation agency_department_of_veterans_affairs
#> 1                                  NA                                    NA
#> 2                                  NA                                    NA
#> 3                                  NA                                    NA
#> 4                                  NA                                    NA
#> 5                                  NA                                    NA
#> 6                                  NA                                    NA
#>   agency_directorate_of_border_and_transportation_security
#> 1                                                       NA
#> 2                                                       NA
#> 3                                                       NA
#> 4                                                       NA
#> 5                                                       NA
#> 6                                                       NA
#>   agency_environmental_protection_agency agency_federal_aviation_administration
#> 1                                     NA                                     NA
#> 2                                     NA                                     NA
#> 3                                     NA                                     NA
#> 4                                     NA                                     NA
#> 5                                     NA                                     NA
#> 6                                     NA                                     NA
#>   agency_federal_communications_commission
#> 1                                       NA
#> 2                                       NA
#> 3                                       NA
#> 4                                       NA
#> 5                                       NA
#> 6                                       NA
#>   agency_federal_deposit_insurance_corporation
#> 1                                           NA
#> 2                                           NA
#> 3                                           NA
#> 4                                           NA
#> 5                                           NA
#> 6                                           NA
#>   agency_federal_emergency_management_agency
#> 1                                         NA
#> 2                                         NA
#> 3                                         NA
#> 4                                         NA
#> 5                                         NA
#> 6                                         NA
#>   agency_federal_energy_regulatory_commission agency_federal_reserve_system
#> 1                                          NA                            NA
#> 2                                          NA                            NA
#> 3                                          NA                            NA
#> 4                                          NA                            NA
#> 5                                          NA                            NA
#> 6                                          NA                            NA
#>   agency_food_and_drug_administration agency_general_services_administration
#> 1                                  NA                                     NA
#> 2                                  NA                                     NA
#> 3                                  NA                                     NA
#> 4                                  NA                                     NA
#> 5                                  NA                                     NA
#> 6                                  NA                                     NA
#>   agency_health_care_financing_administration agency_internal_revenue_service
#> 1                                          NA                              NA
#> 2                                          NA                              NA
#> 3                                          NA                              NA
#> 4                                          NA                              NA
#> 5                                          NA                              NA
#> 6                                          NA                              NA
#>   agency_national_aeronautics_and_space_administration
#> 1                                                   NA
#> 2                                                   NA
#> 3                                                   NA
#> 4                                                   NA
#> 5                                                   NA
#> 6                                                   NA
#>   agency_national_nuclear_security_administration
#> 1                                              NA
#> 2                                              NA
#> 3                                              NA
#> 4                                              NA
#> 5                                              NA
#> 6                                              NA
#>   agency_national_science_foundation agency_nuclear_regulatory_commission
#> 1                                 NA                                   NA
#> 2                                 NA                                   NA
#> 3                                 NA                                   NA
#> 4                                 NA                                   NA
#> 5                                 NA                                   NA
#> 6                                 NA                                   NA
#>   agency_office_of_federal_procurement_policy
#> 1                                          NA
#> 2                                          NA
#> 3                                          NA
#> 4                                          NA
#> 5                                          NA
#> 6                                          NA
#>   agency_office_of_management_and_budget agency_office_of_personnel_management
#> 1                                     NA                                    NA
#> 2                                     NA                                    NA
#> 3                                     NA                                    NA
#> 4                                     NA                                    NA
#> 5                                     NA                                    NA
#> 6                                     NA                                    NA
#>   agency_office_of_the_comptroller_of_the_currency
#> 1                                               NA
#> 2                                               NA
#> 3                                               NA
#> 4                                               NA
#> 5                                               NA
#> 6                                               NA
#>   agency_resolution_trust_corporation agency_small_business_administration
#> 1                                  NA                                   NA
#> 2                                  NA                                   NA
#> 3                                  NA                                   NA
#> 4                                  NA                                   NA
#> 5                                  NA                                   NA
#> 6                                  NA                                   NA
#>   agency_social_security_administration
#> 1                                    NA
#> 2                                    NA
#> 3                                    NA
#> 4                                    NA
#> 5                                    NA
#> 6                                    NA
#>   agency_transportation_security_administration
#> 1                                            NA
#> 2                                            NA
#> 3                                            NA
#> 4                                            NA
#> 5                                            NA
#> 6                                            NA
#>   agency_u_s_agency_for_international_development
#> 1                                              NA
#> 2                                              NA
#> 3                                              NA
#> 4                                              NA
#> 5                                              NA
#> 6                                              NA
#>   agency_united_states_coast_guard
#> 1                               NA
#> 2                               NA
#> 3                               NA
#> 4                               NA
#> 5                               NA
#> 6                               NA
#>   agency_united_states_customs_and_border_protection
#> 1                                                 NA
#> 2                                                 NA
#> 3                                                 NA
#> 4                                                 NA
#> 5                                                 NA
#> 6                                                 NA
#>   agency_united_states_postal_service
#> 1                                  NA
#> 2                                  NA
#> 3                                  NA
#> 4                                  NA
#> 5                                  NA
#> 6                                  NA
#>   agency_united_states_securities_and_exchange_commission
#> 1                                                      NA
#> 2                                                      NA
#> 3                                                      NA
#> 4                                                      NA
#> 5                                                      NA
#> 6                                                      NA
#>   agency_veterans_administration agency_other
#> 1                             NA           NA
#> 2                             NA           NA
#> 3                             NA           NA
#> 4                             NA           NA
#> 5                             NA           NA
#> 6                             NA           NA
```
