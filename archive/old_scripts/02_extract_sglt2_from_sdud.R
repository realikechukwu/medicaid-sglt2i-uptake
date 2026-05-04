library(DBI)
library(duckdb)
library(tidyverse)
library(here)

# Paths
sdud_file <- here("data_raw", "sdud-2025-updated.csv")
sglt2_file <- here("data_processed", "sglt2_ndc_11_digit_list.csv")

# Connect to DuckDB
con <- dbConnect(duckdb::duckdb(), dbdir = here("data_processed", "sdud_analysis.duckdb"))

# Read SGLT2 NDC lookup into R
sglt2_ndcs <- read_csv(
  sglt2_file,
  col_types = cols(ndc_11 = col_character(), .default = col_guess())
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

# Copy lookup table into DuckDB
dbWriteTable(con, "sglt2_ndcs", sglt2_ndcs, overwrite = TRUE)

dbExecute(con, glue::glue("
CREATE OR REPLACE TABLE sdud AS
SELECT *
FROM read_csv(
  '{sdud_file}',
  header = true,
  delim = ',',
  quote = '\"',
  all_varchar = true,
  ignore_errors = false
)
"))

# Check SDUD columns
dbListFields(con, "sdud")

dbExecute(con, '
CREATE OR REPLACE TABLE sdud_clean AS
SELECT
  "Utilization Type" AS utilization_type,
  "State" AS state,
  "NDC" AS ndc,
  "Labeler Code" AS labeler_code,
  "Product Code" AS product_code,
  "Package Size" AS package_size,
  "Year" AS year,
  "Quarter" AS quarter,
  "Suppression Used" AS suppression_used,
  "Product Name" AS product_name,
  "Units Reimbursed" AS units_reimbursed,
  "Number of Prescriptions" AS number_of_prescriptions,
  "Total Amount Reimbursed" AS total_amount_reimbursed,
  "Medicaid Amount Reimbursed" AS medicaid_amount_reimbursed,
  "Non Medicaid Amount Reimbursed" AS non_medicaid_amount_reimbursed
FROM sdud
')


dbExecute(con, "
CREATE OR REPLACE TABLE sdud_sglt2 AS
SELECT
  s.*,
  n.sglt2_drug,
  n.PROPRIETARYNAME,
  n.NONPROPRIETARYNAME,
  n.combination_product,
  n.active_currently
FROM sdud_clean s
INNER JOIN sglt2_ndcs n
  ON lpad(CAST(s.ndc AS VARCHAR), 11, '0') = n.ndc_11
")

dbGetQuery(con, "
SELECT
  sglt2_drug,
  combination_product,
  COUNT(*) AS rows,
  SUM(CAST(number_of_prescriptions AS DOUBLE)) AS prescriptions
FROM sdud_sglt2
GROUP BY sglt2_drug, combination_product
ORDER BY sglt2_drug, combination_product
")

dbGetQuery(con, "
SELECT
  utilization_type,
  COUNT(*) AS rows,
  SUM(CAST(number_of_prescriptions AS DOUBLE)) AS prescriptions
FROM sdud_sglt2
GROUP BY utilization_type
ORDER BY utilization_type
")


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
FROM sdud_sglt2
GROUP BY state, year, quarter
ORDER BY state, year, quarter
")

write_csv(
  sglt2_state_quarter_all,
  here("data_processed", "sglt2_state_quarter_all_products.csv")
)

#single agent dataset
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
FROM sdud_sglt2
WHERE combination_product = FALSE
GROUP BY state, year, quarter
ORDER BY state, year, quarter
")

write_csv(
  sglt2_state_quarter_single_agent,
  here("data_processed", "sglt2_state_quarter_single_agent.csv")
)

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
FROM sdud_sglt2
WHERE sglt2_drug IN ('empagliflozin', 'dapagliflozin')
GROUP BY state, year, quarter
ORDER BY state, year, quarter
")

write_csv(
  sglt2_state_quarter_empa_dapa,
  here("data_processed", "sglt2_state_quarter_empa_dapa.csv")
)

#compare combination to single agent
sglt2_state_quarter_by_type <- dbGetQuery(con, "
SELECT
  state,
  CAST(year AS INTEGER) AS year,
  CAST(quarter AS INTEGER) AS quarter,
  combination_product,

  SUM(CAST(number_of_prescriptions AS DOUBLE)) AS sglt2_prescriptions,
  SUM(CAST(units_reimbursed AS DOUBLE)) AS sglt2_units,
  SUM(CAST(medicaid_amount_reimbursed AS DOUBLE)) AS sglt2_medicaid_reimbursed,

  COUNT(*) AS n_rows,
  COUNT(DISTINCT ndc) AS n_ndcs
FROM sdud_sglt2
GROUP BY state, year, quarter, combination_product
ORDER BY state, year, quarter, combination_product
")

write_csv(
  sglt2_state_quarter_by_type,
  here("data_processed", "sglt2_state_quarter_by_product_type.csv")
)
