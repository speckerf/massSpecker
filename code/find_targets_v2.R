library("optparse")
library("magrittr") # loads pipe "%>%" operator

# for debugging
opt <- list("peaklist" = "../data/peaklist.csv",
            "compoundlist" = "http://localhost:8080/database/compoundlist.csv?_size=max",
            "output" = "../output/results_v2.db")

######
# Parse command-line arguments
######

option_list = list(
  make_option(c("-p", "--peaklist"), type="character", default=NULL,
              help="peaklist path", metavar="character"),
  make_option(c("-c", "--compoundlist"), type="character",
              help="API call to compound list database path", metavar="character"),
  make_option(c("-o", "--output"), type="character", default="output/results_v2.db",
              help="output path [default= %default]", metavar="character")
);

opt_parser = OptionParser(option_list=option_list);
opt = parse_args(opt_parser);


######
# Load Data
## 1. Peaklist
## 2. Database connection
######

peaklist <- readr::read_csv(opt$peaklist, show_col_types = FALSE)
compoundlist <- readr::read_csv(opt$compoundlist, show_col_types = FALSE)

######
# Find Targets in Peaklist
######

targets <- compoundlist %>% 
  dplyr::filter(!is.na(retention_time))

## join targets with peaklist and allow a numeric difference of 0.002 for the mz value
targets_in_peaklist <- targets %>% 
  fuzzyjoin::difference_inner_join(
    peaklist, 
    by = c("mass_to_charge_ratio" = "mz"), 
    max_dist = 0.002, 
    distance_col = "mz_error"
  )

## create new retention_time tolerance column
## check that retention times are within the accepted tolerances
targets_in_peaklist <- targets_in_peaklist %>%
  dplyr::mutate(my_rt_tolerance = ifelse(is.na(retention_time_tolerance), 0.5, as.numeric(retention_time_tolerance)),
                rt_error = abs(retention_time - rt)) %>%
  dplyr::filter(rt_error < my_rt_tolerance)

## select columns of interest and rename columns
targets_in_peaklist <- targets_in_peaklist %>%
  dplyr::select(dplyr::matches("compound"), mass_to_charge_ratio, mz, mz_error, retention_time, rt, rt_error, intensity) %>%
  dplyr::rename("mz_db" = "mass_to_charge_ratio",
                "mz_pl" = "mz",
                "rt_db" = "retention_time",
                "rt_pl" = "rt",
                "intensity_pl" = "intensity")
 
######
# Post resulting table directly to Datasette
######

# request_body_json <- jsonlite::toJSON(targets_in_peaklist %>% dplyr::slice(1))
# 
# token <- dstok_eyJhIjoicm9vdCIsInQiOjE2NzY5MzY3NDMsImQiOjM2MDB9.nkx0Lc0eULKE7KQlxQQ8TDsmcDI
# 
# result <- httr::POST("http://127.0.0.1:8080/database/asdf",
#                body = request_body_json,
#                httr::add_headers(.headers = c("Content-Type"="application/json","Authorization"="Bearer dstok_eyJhIjoicm9vdCIsInQiOjE2NzY5MzY3NDMsImQiOjM2MDB9.nkx0Lc0eULKE7KQlxQQ8TDsmcDI")))
# result <- httr::POST("http://127.0.0.1:8080/database/-/create",
#                      body = request_body_json,
#                      httr::add_headers(.headers = c("Content-Type"="application/json","Authorization"="Bearer dstok_eyJhIjoicm9vdCIsInQiOjE2NzY5MzY3NDMsImQiOjM2MDB9.nkx0Lc0eULKE7KQlxQQ8TDsmcDI")))
# 
# ?tidyjson::as.tbl_json(targets_in_peaklist %>% dplyr::slice(1), json.column = "compound")


######
# Find Suspects in Peaklist
######

suspects <- compoundlist %>% 
  dplyr::filter(is.na(retention_time)) %>%
  dplyr::collect()

## join suspects with peaklist and allow a numeric difference of 0.002 for the mz value
suspects_in_peaklist <- suspects %>% 
  fuzzyjoin::difference_inner_join(
    peaklist, 
    by = c("mass_to_charge_ratio" = "mz"), 
    max_dist = 0.002, 
    distance_col = "mz_error"
  )

suspects_in_peaklist <- suspects_in_peaklist %>%
  dplyr::select(dplyr::matches("compound"), mass_to_charge_ratio, mz, mz_error, retention_time, rt, intensity) %>%
  dplyr::rename("mz_db" = "mass_to_charge_ratio",
                "mz_pl" = "mz",
                "rt_db" = "retention_time",
                "rt_pl" = "rt",
                "intensity_pl" = "intensity") %>%
  dplyr::mutate("rt_error" = abs(rt_db - rt_pl))


######
# Save results
######

output_conn <- DBI::dbConnect(RSQLite::SQLite(), opt$output)
DBI::dbWriteTable(output_conn, "targets", targets_in_peaklist, overwrite = TRUE)
DBI::dbWriteTable(output_conn, "suspects", suspects_in_peaklist, overwrite = TRUE)
