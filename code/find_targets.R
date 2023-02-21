library("optparse")
library("magrittr") # loads pipe "%>%" operator

######
# Parse command-line arguments
######

option_list = list(
  make_option(c("-p", "--peaklist"), type="character", default=NULL, 
              help="peaklist path", metavar="character"),
  make_option(c("-d", "--database"), type="character", default="data/database.db", 
              help="reference database path [default= %default]", metavar="character"),
  make_option(c("-o", "--output"), type="character", default="output/results.db", 
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

db_conn <- DBI::dbConnect(RSQLite::SQLite(), opt$database)
print(db_conn)

compoundlist <- dplyr::tbl(db_conn, "compoundlist")

######
# Find Targets in Peaklist
######

## note: comp only corresponds to a SQL query so far, no data has been loaded into memory
# to apply the SQL query and return the result, use dplyr::collect()
targets <- compoundlist %>% 
  dplyr::filter(!is.na(retention_time)) %>%
  dplyr::collect()

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
  dplyr::mutate(my_rt_tolerance = ifelse(is.na(retention_time_tolerance), 0.5, as.numeric(retention_time_tolerance))) %>%
  dplyr::filter(abs(retention_time - rt) < my_rt_tolerance)

## select columns of interest and rename columns
targets_in_peaklist <- targets_in_peaklist %>%
  dplyr::select(dplyr::matches("compound"), mass_to_charge_ratio, mz, mz_error, retention_time, rt, intensity) %>%
  dplyr::rename("mz_db" = "mass_to_charge_ratio",
                "mz_pl" = "mz",
                "rt_db" = "retention_time",
                "rt_pl" = "rt",
                "intensity_pl" = "intensity") %>%
  dplyr::mutate("rt_error" = abs(rt_db - rt_pl))

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

### close connections
DBI::dbDisconnect(db_conn)
DBI::dbDisconnect(output_conn)
