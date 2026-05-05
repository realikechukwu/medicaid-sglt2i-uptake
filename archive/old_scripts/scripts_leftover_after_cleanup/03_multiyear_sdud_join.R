# ============================================================
# Extract SGLT2 inhibitor utilization from SDUD, 2015 to 2025
# ============================================================

library(DBI)
library(duckdb)
library(tidyverse)
library(here)
library(glue)

# ------------------------------------------------------------
# 0. Paths and settings
# ------------------------------------------------------------

sdud_dir <- here("data_raw", "sdud")
sglt2_file <- here("data_processed", "sglt2_ndc_11_digit_list.csv")
duckdb_file <- here("data_processed", "sdud_analysis.duckdb")

dir.create(here("data_processed"), showWarnings = FALSE)

years_to_include <- 2015:2025

# ------------------------------------------------------------
# 1. Find SDUD files
# ------------------------------------------------------------

sdud_files <- list.files(
  sdud_dir,
  pattern = "\\.csv$",
  full.names = TRUE
)

if (length(sdud_files) == 0) {
  stop("No CSV files found in data_raw/sdud/. Put annual SDUD CSV files there first.")
}

sdud_file_index <- tibble(
  file_path = sdud_files,
  file_name = basename(sdud_files),
  file_year = str_extract(basename(sdud_files), "20[0-9]{2}") |> as.integer()
) %>%
  filter(file_year %in% years_to_include) %>%
  arrange(file_year)

print(sdud_file_index)

if (nrow(sdud_file_index) == 0) {
  stop("No SDUD files matched years 2015 to 2025. Check file names include the year.")
}

missing_years <- setdiff(years_to_include, sdud_file_index$file_year)

if (length(missing_years) > 0) {
  warning(
    "These years are missing from data_raw/sdud/: ",
    paste(missing_years, collapse = ", ")
  )
}

# ------------------------------------------------------------
# 2. Connect to DuckDB
# ------------------------------------------------------------

if (file.exists(duckdb_file)) {
  file.remove(duckdb_file)
}

con <- dbConnect(
  duckdb::duckdb(),
  dbdir = duckdb_file
)

# ------------------------------------------------------------
# 3. Load SGLT2 NDC lookup
# ------------------------------------------------------------

sglt2_ndcs <- read_csv(
  sglt2_file,
  col_types = cols(ndc_11 = col_character(), .default = col_guess())
) %>%
  mutate(
    ndc_11 = str_pad(as.character(ndc_11), width = 11, side = "left", pad = "0"),
    combination_product = as.logical(combination_product),
    active_currently = as.logical(active_currently)
  ) %>%
  select(
    ndc_11,
    sglt2_drug,
    PROPRIETARYNAME,
    NONPROPRIETARYNAME,
    combination_product,
    active_currently
  ) %>%
  distinct(ndc_11, .keep_all = TRUE)

# Sanity check
if (nrow(sglt2_ndcs) != n_distinct(sglt2_ndcs$ndc_11)) {
  stop("SGLT2 NDC lookup has duplicate ndc_11 values. Check lookup file.")
}

dbWriteTable(con, "sglt2_ndcs", sglt2_ndcs, overwrite = TRUE)

# ------------------------------------------------------------
# 4. Create empty all-years SGLT2 table
# ------------------------------------------------------------

dbExecute(con, "
CREATE TABLE sdud_sglt2_all_years (
  utilization_type VARCHAR,
  state VARCHAR,
  ndc VARCHAR,
  labeler_code VARCHAR,
  product_code VARCHAR,
  package_size VARCHAR,
  year VARCHAR,
  quarter VARCHAR,
  suppression_used VARCHAR,
  product_name VARCHAR,
  units_reimbursed VARCHAR,
  number_of_prescriptions VARCHAR,
  total_amount_reimbursed VARCHAR,
  medicaid_amount_reimbursed VARCHAR,
  non_medicaid_amount_reimbursed VARCHAR,
  source_file VARCHAR,
  sglt2_drug VARCHAR,
  PROPRIETARYNAME VARCHAR,
  NONPROPRIETARYNAME VARCHAR,
  combination_product BOOLEAN,
  active_currently BOOLEAN
)
")

# ------------------------------------------------------------
# 5. Process each annual SDUD file
# ------------------------------------------------------------

for (i in seq_len(nrow(sdud_file_index))) {
  
  file_path <- sdud_file_index$file_path[i]
  file_name <- sdud_file_index$file_name[i]
  file_year <- sdud_file_index$file_year[i]
  
  message("Processing ", file_year, ": ", file_name)
  
  # Read raw SDUD CSV into temporary table
  dbExecute(con, glue("
  CREATE OR REPLACE TEMP TABLE sdud_temp AS
  SELECT *
  FROM read_csv(
    '{file_path}',
    header = true,
    delim = ',',
    quote = '\"',
    all_varchar = true,
    ignore_errors = false
  )
  "))
  
  # Clean column names into temporary table
  dbExecute(con, "
  CREATE OR REPLACE TEMP TABLE sdud_clean_temp AS
  SELECT
    \"Utilization Type\" AS utilization_type,
    \"State\" AS state,
    \"NDC\" AS ndc,
    \"Labeler Code\" AS labeler_code,
    \"Product Code\" AS product_code,
    \"Package Size\" AS package_size,
    \"Year\" AS year,
    \"Quarter\" AS quarter,
    \"Suppression Used\" AS suppression_used,
    \"Product Name\" AS product_name,
    \"Units Reimbursed\" AS units_reimbursed,
    \"Number of Prescriptions\" AS number_of_prescriptions,
    \"Total Amount Reimbursed\" AS total_amount_reimbursed,
    \"Medicaid Amount Reimbursed\" AS medicaid_amount_reimbursed,
    \"Non Medicaid Amount Reimbursed\" AS non_medicaid_amount_reimbursed
  FROM sdud_temp
  ")
  
  # Extract SGLT2 rows and append to all-years table
  dbExecute(con, glue("
  INSERT INTO sdud_sglt2_all_years
  SELECT
    s.utilization_type,
    s.state,
    lpad(CAST(s.ndc AS VARCHAR), 11, '0') AS ndc,
    s.labeler_code,
    s.product_code,
    s.package_size,
    s.year,
    s.quarter,
    s.suppression_used,
    s.product_name,
    s.units_reimbursed,
    s.number_of_prescriptions,
    s.total_amount_reimbursed,
    s.medicaid_amount_reimbursed,
    s.non_medicaid_amount_reimbursed,
    '{file_name}' AS source_file,
    n.sglt2_drug,
    n.PROPRIETARYNAME,
    n.NONPROPRIETARYNAME,
    n.combination_product,
    n.active_currently
  FROM sdud_clean_temp s
  INNER JOIN sglt2_ndcs n
    ON lpad(CAST(s.ndc AS VARCHAR), 11, '0') = n.ndc_11
  "))
  
  # Optional quick progress check
  progress <- dbGetQuery(con, "
  SELECT COUNT(*) AS n_rows
  FROM sdud_sglt2_all_years
  ")
  
  message("Cumulative SGLT2 rows: ", progress$n_rows)
}

# ------------------------------------------------------------
# 6. Sanity checks
# ------------------------------------------------------------

check_by_year <- dbGetQuery(con, "
SELECT
  CAST(year AS INTEGER) AS year,
  COUNT(*) AS rows,
  SUM(CAST(number_of_prescriptions AS DOUBLE)) AS prescriptions,
  COUNT(DISTINCT state) AS n_states,
  COUNT(DISTINCT ndc) AS n_ndcs
FROM sdud_sglt2_all_years
GROUP BY year
ORDER BY year
")

print(check_by_year)

write_csv(
  check_by_year,
  here("data_processed", "check_sglt2_rows_by_year.csv")
)

check_by_drug <- dbGetQuery(con, "
SELECT
  sglt2_drug,
  combination_product,
  COUNT(*) AS rows,
  SUM(CAST(number_of_prescriptions AS DOUBLE)) AS prescriptions,
  COUNT(DISTINCT ndc) AS n_ndcs
FROM sdud_sglt2_all_years
GROUP BY sglt2_drug, combination_product
ORDER BY sglt2_drug, combination_product
")

print(check_by_drug)

write_csv(
  check_by_drug,
  here("data_processed", "check_sglt2_rows_by_drug.csv")
)

check_by_utilization_type <- dbGetQuery(con, "
SELECT
  utilization_type,
  COUNT(*) AS rows,
  SUM(CAST(number_of_prescriptions AS DOUBLE)) AS prescriptions
FROM sdud_sglt2_all_years
GROUP BY utilization_type
ORDER BY utilization_type
")

print(check_by_utilization_type)

write_csv(
  check_by_utilization_type,
  here("data_processed", "check_sglt2_by_utilization_type.csv")
)

# ------------------------------------------------------------
# 7. Save row-level SGLT2 extract
# ------------------------------------------------------------

sglt2_row_level <- dbGetQuery(con, "
SELECT *
FROM sdud_sglt2_all_years
ORDER BY state, CAST(year AS INTEGER), CAST(quarter AS INTEGER), sglt2_drug, ndc
")

write_csv(
  sglt2_row_level,
  here("data_processed", "sdud_sglt2_row_level_2015_2025.csv")
)

# ------------------------------------------------------------
# 8. Main output: all SGLT2i products, state-quarter level
# ------------------------------------------------------------

sglt2_state_quarter_all <- dbGetQuery(con, "
SELECT
  state,
  CAST(year AS INTEGER) AS year,
  CAST(quarter AS INTEGER) AS quarter,

  SUM(CAST(number_of_prescriptions AS DOUBLE)) AS sglt2_prescriptions,
  SUM(CAST(units_reimbursed AS DOUBLE)) AS sglt2_units,
  SUM(CAST(medicaid_amount_reimbursed AS DOUBLE)) AS sglt2_medicaid_reimbursed,
  SUM(CAST(total_amount_reimbursed AS DOUBLE)) AS sglt2_total_reimbursed,

  COUNT(*) AS n_rows,
  COUNT(DISTINCT ndc) AS n_ndcs
FROM sdud_sglt2_all_years
GROUP BY state, year, quarter
ORDER BY state, year, quarter
")

write_csv(
  sglt2_state_quarter_all,
  here("data_processed", "sglt2_state_quarter_all_products_2015_2025.csv")
)

# ------------------------------------------------------------
# 9. Sensitivity 1: single-agent SGLT2i only
# ------------------------------------------------------------

sglt2_state_quarter_single_agent <- dbGetQuery(con, "
SELECT
  state,
  CAST(year AS INTEGER) AS year,
  CAST(quarter AS INTEGER) AS quarter,

  SUM(CAST(number_of_prescriptions AS DOUBLE)) AS sglt2_prescriptions,
  SUM(CAST(units_reimbursed AS DOUBLE)) AS sglt2_units,
  SUM(CAST(medicaid_amount_reimbursed AS DOUBLE)) AS sglt2_medicaid_reimbursed,
  SUM(CAST(total_amount_reimbursed AS DOUBLE)) AS sglt2_total_reimbursed,

  COUNT(*) AS n_rows,
  COUNT(DISTINCT ndc) AS n_ndcs
FROM sdud_sglt2_all_years
WHERE combination_product = FALSE
GROUP BY state, year, quarter
ORDER BY state, year, quarter
")

write_csv(
  sglt2_state_quarter_single_agent,
  here("data_processed", "sglt2_state_quarter_single_agent_2015_2025.csv")
)

# ------------------------------------------------------------
# 10. Sensitivity 2: empagliflozin + dapagliflozin only
# ------------------------------------------------------------

sglt2_state_quarter_empa_dapa <- dbGetQuery(con, "
SELECT
  state,
  CAST(year AS INTEGER) AS year,
  CAST(quarter AS INTEGER) AS quarter,

  SUM(CAST(number_of_prescriptions AS DOUBLE)) AS sglt2_prescriptions,
  SUM(CAST(units_reimbursed AS DOUBLE)) AS sglt2_units,
  SUM(CAST(medicaid_amount_reimbursed AS DOUBLE)) AS sglt2_medicaid_reimbursed,
  SUM(CAST(total_amount_reimbursed AS DOUBLE)) AS sglt2_total_reimbursed,

  COUNT(*) AS n_rows,
  COUNT(DISTINCT ndc) AS n_ndcs
FROM sdud_sglt2_all_years
WHERE sglt2_drug IN ('empagliflozin', 'dapagliflozin')
GROUP BY state, year, quarter
ORDER BY state, year, quarter
")

write_csv(
  sglt2_state_quarter_empa_dapa,
  here("data_processed", "sglt2_state_quarter_empa_dapa_2015_2025.csv")
)

# ------------------------------------------------------------
# 11. Product type comparison: single-agent vs combination
# ------------------------------------------------------------

sglt2_state_quarter_by_type <- dbGetQuery(con, "
SELECT
  state,
  CAST(year AS INTEGER) AS year,
  CAST(quarter AS INTEGER) AS quarter,
  combination_product,

  SUM(CAST(number_of_prescriptions AS DOUBLE)) AS sglt2_prescriptions,
  SUM(CAST(units_reimbursed AS DOUBLE)) AS sglt2_units,
  SUM(CAST(medicaid_amount_reimbursed AS DOUBLE)) AS sglt2_medicaid_reimbursed,
  SUM(CAST(total_amount_reimbursed AS DOUBLE)) AS sglt2_total_reimbursed,

  COUNT(*) AS n_rows,
  COUNT(DISTINCT ndc) AS n_ndcs
FROM sdud_sglt2_all_years
GROUP BY state, year, quarter, combination_product
ORDER BY state, year, quarter, combination_product
")

write_csv(
  sglt2_state_quarter_by_type,
  here("data_processed", "sglt2_state_quarter_by_product_type_2015_2025.csv")
)

# ------------------------------------------------------------
# 12. Drug-specific state-quarter output
# ------------------------------------------------------------

sglt2_state_quarter_by_drug <- dbGetQuery(con, "
SELECT
  state,
  CAST(year AS INTEGER) AS year,
  CAST(quarter AS INTEGER) AS quarter,
  sglt2_drug,

  SUM(CAST(number_of_prescriptions AS DOUBLE)) AS sglt2_prescriptions,
  SUM(CAST(units_reimbursed AS DOUBLE)) AS sglt2_units,
  SUM(CAST(medicaid_amount_reimbursed AS DOUBLE)) AS sglt2_medicaid_reimbursed,
  SUM(CAST(total_amount_reimbursed AS DOUBLE)) AS sglt2_total_reimbursed,

  COUNT(*) AS n_rows,
  COUNT(DISTINCT ndc) AS n_ndcs
FROM sdud_sglt2_all_years
GROUP BY state, year, quarter, sglt2_drug
ORDER BY state, year, quarter, sglt2_drug
")

write_csv(
  sglt2_state_quarter_by_drug,
  here("data_processed", "sglt2_state_quarter_by_drug_2015_2025.csv")
)

# ------------------------------------------------------------
# 13. National quarterly trend output
# ------------------------------------------------------------

sglt2_national_quarterly <- dbGetQuery(con, "
SELECT
  CAST(year AS INTEGER) AS year,
  CAST(quarter AS INTEGER) AS quarter,

  SUM(CAST(number_of_prescriptions AS DOUBLE)) AS sglt2_prescriptions,
  SUM(CAST(units_reimbursed AS DOUBLE)) AS sglt2_units,
  SUM(CAST(medicaid_amount_reimbursed AS DOUBLE)) AS sglt2_medicaid_reimbursed,
  SUM(CAST(total_amount_reimbursed AS DOUBLE)) AS sglt2_total_reimbursed,

  COUNT(*) AS n_rows,
  COUNT(DISTINCT state) AS n_states,
  COUNT(DISTINCT ndc) AS n_ndcs
FROM sdud_sglt2_all_years
GROUP BY year, quarter
ORDER BY year, quarter
")

write_csv(
  sglt2_national_quarterly,
  here("data_processed", "sglt2_national_quarterly_2015_2025.csv")
)

# ------------------------------------------------------------
# 14. Final console summary
# ------------------------------------------------------------

cat("\nDone. Files saved to data_processed:\n")
cat("1. sdud_sglt2_row_level_2015_2025.csv\n")
cat("2. sglt2_state_quarter_all_products_2015_2025.csv\n")
cat("3. sglt2_state_quarter_single_agent_2015_2025.csv\n")
cat("4. sglt2_state_quarter_empa_dapa_2015_2025.csv\n")
cat("5. sglt2_state_quarter_by_product_type_2015_2025.csv\n")
cat("6. sglt2_state_quarter_by_drug_2015_2025.csv\n")
cat("7. sglt2_national_quarterly_2015_2025.csv\n")
cat("8. check_sglt2_rows_by_year.csv\n")
cat("9. check_sglt2_rows_by_drug.csv\n")
cat("10. check_sglt2_by_utilization_type.csv\n")

dbDisconnect(con, shutdown = TRUE)