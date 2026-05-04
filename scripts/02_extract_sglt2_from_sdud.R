if (!requireNamespace("here", quietly = TRUE)) {
  stop("Install the `here` package before running this script.", call. = FALSE)
}
source(here::here("scripts", "00_setup.R"))

sdud_dir <- project_path("data_raw", "sdud")
sglt2_file <- project_path("data_processed", "ndc_lookup", "sglt2_ndc_11_digit_list.csv")
duckdb_file <- project_path("data_processed", "sdud_extracts", "sdud_analysis.duckdb")
output_dir <- project_path("data_processed", "sdud_extracts")

ensure_dir(output_dir)
require_files(sglt2_file, "SGLT2 NDC lookup")

sdud_files <- list.files(sdud_dir, pattern = "[.]csv$", full.names = TRUE)
if (length(sdud_files) == 0) {
  stop("No raw SDUD CSV files found in `data_raw/sdud/`.", call. = FALSE)
}

sdud_file_index <- tibble::tibble(
  file_path = sdud_files,
  file_name = basename(sdud_files),
  file_year = stringr::str_extract(basename(sdud_files), "20[0-9]{2}") |> as.integer()
) |>
  dplyr::filter(file_year %in% 2015:2025) |>
  dplyr::arrange(file_year)

missing_years <- setdiff(2015:2025, sdud_file_index$file_year)
if (length(missing_years) > 0) {
  stop(
    "Missing raw SDUD file(s) for year(s): ",
    paste(missing_years, collapse = ", "),
    ". Place annual SDUD CSVs in `data_raw/sdud/` with the year in the filename.",
    call. = FALSE
  )
}

if (file.exists(duckdb_file)) {
  file.remove(duckdb_file)
}

con <- DBI::dbConnect(duckdb::duckdb(), dbdir = duckdb_file)

sglt2_ndcs <- readr::read_csv(
  sglt2_file,
  col_types = readr::cols(ndc_11 = readr::col_character(), .default = readr::col_guess()),
  show_col_types = FALSE
) |>
  dplyr::mutate(
    ndc_11 = stringr::str_pad(as.character(ndc_11), 11, side = "left", pad = "0"),
    combination_product = as.logical(combination_product),
    active_currently = as.logical(active_currently)
  ) |>
  dplyr::select(ndc_11, sglt2_drug, PROPRIETARYNAME, NONPROPRIETARYNAME, combination_product, active_currently) |>
  dplyr::distinct(ndc_11, .keep_all = TRUE)

require_columns(
  sglt2_ndcs,
  c("ndc_11", "sglt2_drug", "PROPRIETARYNAME", "NONPROPRIETARYNAME", "combination_product", "active_currently"),
  "SGLT2 NDC lookup"
)

DBI::dbWriteTable(con, "sglt2_ndcs", sglt2_ndcs, overwrite = TRUE)

DBI::dbExecute(con, "
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

for (i in seq_len(nrow(sdud_file_index))) {
  file_path <- sdud_file_index$file_path[i]
  file_name <- sdud_file_index$file_name[i]
  file_year <- sdud_file_index$file_year[i]

  message("Processing raw SDUD ", file_year, ": ", file_name)

  DBI::dbExecute(con, glue::glue("
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

  DBI::dbExecute(con, "
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

  DBI::dbExecute(con, glue::glue("
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
}

sglt2_row_level <- DBI::dbGetQuery(con, "
  SELECT *
  FROM sdud_sglt2_all_years
  ORDER BY state, CAST(year AS INTEGER), CAST(quarter AS INTEGER), sglt2_drug, ndc
")

safe_write_csv(
  sglt2_row_level,
  project_path("data_processed", "sdud_extracts", "sdud_sglt2_row_level_2015_2025.csv")
)

state_quarter_query <- function(where_clause = "") {
  DBI::dbGetQuery(con, paste0("
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
    ", where_clause, "
    GROUP BY state, year, quarter
    ORDER BY state, year, quarter
  "))
}

safe_write_csv(
  state_quarter_query(),
  project_path("data_processed", "sdud_extracts", "sglt2_state_quarter_all_products_2015_2025.csv")
)

safe_write_csv(
  state_quarter_query("WHERE combination_product = FALSE"),
  project_path("data_processed", "sdud_extracts", "sglt2_state_quarter_single_agent_2015_2025.csv")
)

safe_write_csv(
  state_quarter_query("WHERE sglt2_drug IN ('empagliflozin', 'dapagliflozin')"),
  project_path("data_processed", "sdud_extracts", "sglt2_state_quarter_empa_dapa_2015_2025.csv")
)

message("Wrote final SDUD row-level and state-quarter SGLT2 extracts to: ", output_dir)

DBI::dbDisconnect(con, shutdown = TRUE)
