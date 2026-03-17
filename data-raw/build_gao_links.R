## build_gao_links.R — rebuild bundled GAO links dataset
## Resumable: caches HTML pages to data-raw/gao_pages/, skips existing ones.
## Safe to re-run after interruption.

devtools::load_all()

all.data <- extract_links(cache_dir = "data-raw/gao_pages",
                          sleep_time = 2, verbose = TRUE)

message("Total unique reports: ", nrow(all.data))
message("NA published dates: ", sum(is.na(all.data$published)),
        " (", round(100 * mean(is.na(all.data$published)), 1), "%)")

dir.create("inst/extdata", recursive = TRUE, showWarnings = FALSE)
saveRDS(all.data, "inst/extdata/gao_links.rds")
message("Saved to inst/extdata/gao_links.rds (",
        round(file.size("inst/extdata/gao_links.rds") / 1e6, 1), " MB)")
