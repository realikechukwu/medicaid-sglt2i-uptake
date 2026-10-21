if (!requireNamespace("here", quietly = TRUE)) {
  stop("Install the `here` package before running this script.", call. = FALSE)
}
source(here::here("scripts", "00_setup.R"))

master_file <- project_path("for_analysis", "master", "master_state_quarter_sglt2_covariates.csv")
missingness_file <- project_path("for_analysis", "model_outputs", "diagnostics", "master_missingness_report.csv")
log_file <- project_path("docs", "logs", "2026-05_master_table_log.md")

sglt2_file <- project_path("data_processed", "sdud_extracts", "sglt2_state_quarter_all_products_2015_2025.csv")
enrolment_file <- project_path("data_processed", "enrolment", "medicaid_enrolment_state_quarter.csv")

covariate_files <- c(
  expansion = project_path("data_processed", "covariates", "medicaid_expansion_state_quarter.csv"),
  physician_density = project_path("data_processed", "covariates", "ahrf_physician_density_2023_50dc.csv"),
  disease_burden = project_path("data_processed", "covariates", "mmd_disease_burden_2023_50dc.csv"),
  rucc = project_path("data_processed", "covariates", "rucc_state_rurality_2023.csv"),
  svi = project_path("data_processed", "covariates", "svi_state_2022_50dc.csv"),
  region = project_path("data_processed", "covariates", "census_region_division_50dc.csv")
)

require_files(c(sglt2_file, enrolment_file, covariate_files), "master input file")

read_clean_csv <- function(path, label) {
  readr::read_csv(path, show_col_types = FALSE) |>
    janitor::clean_names()
}

sglt2 <- read_clean_csv(sglt2_file, "SGLT2 all-products state-quarter file") |>
  dplyr::mutate(
    state = stringr::str_to_upper(state),
    year = as.integer(year),
    quarter = as.integer(quarter)
  )

require_columns(
  sglt2,
  c(
    "state",
    "year",
    "quarter",
    "sglt2_prescriptions",
    "sglt2_units",
    "sglt2_medicaid_reimbursed",
    "sglt2_total_reimbursed",
    "n_rows",
    "n_ndcs"
  ),
  "SGLT2 all-products state-quarter file"
)

enrolment <- read_clean_csv(enrolment_file, "Medicaid state-quarter denominator file") |>
  dplyr::mutate(
    state = stringr::str_to_upper(state),
    year = as.integer(year),
    quarter = as.integer(quarter)
  )

require_columns(
  enrolment,
  c("state", "year", "quarter", "medicaid_enrolment_quarter_avg", "n_enrolment_months"),
  "Medicaid state-quarter denominator file"
)

forbidden_denominator_cols <- intersect(c("medicaid_enrolment", "medicaid_enrolment_avg"), names(enrolment))
if (length(forbidden_denominator_cols) > 0) {
  stop(
    "Final denominator file must not contain denominator aliases: ",
    paste(forbidden_denominator_cols, collapse = ", "),
    call. = FALSE
  )
}

assert_no_duplicate_keys(enrolment, c("state", "year", "quarter"), "Medicaid state-quarter denominator file")
assert_analysis_exclusions(enrolment, "Medicaid state-quarter denominator file")

available_quarters <- enrolment |>
  dplyr::distinct(year, quarter)

analysis_grid <- available_quarters |>
  tidyr::crossing(state = valid_50dc) |>
  dplyr::select(state, year, quarter) |>
  dplyr::arrange(state, year, quarter)

sglt2_filtered <- sglt2 |>
  dplyr::filter(
    year %in% analysis_years,
    state %in% valid_50dc,
    year != 2020
  ) |>
  dplyr::semi_join(available_quarters, by = c("year", "quarter"))

assert_analysis_exclusions(sglt2_filtered, "filtered all-products SGLT2 file")
assert_no_duplicate_keys(sglt2_filtered, c("state", "year", "quarter"), "filtered all-products SGLT2 file")

base <- analysis_grid |>
  dplyr::left_join(sglt2_filtered, by = c("state", "year", "quarter")) |>
  dplyr::left_join(enrolment, by = c("state", "year", "quarter")) |>
  dplyr::mutate(
    has_valid_medicaid_enrolment =
      !is.na(medicaid_enrolment_quarter_avg) & medicaid_enrolment_quarter_avg > 0,
    dplyr::across(
      dplyr::all_of(c(
        "sglt2_prescriptions",
        "sglt2_units",
        "sglt2_medicaid_reimbursed",
        "sglt2_total_reimbursed",
        "n_rows",
        "n_ndcs"
      )),
      ~ dplyr::if_else(has_valid_medicaid_enrolment & is.na(.x), 0, .x)
    ),
    sglt2_prescriptions_all_products_per_10000 =
      dplyr::if_else(
        has_valid_medicaid_enrolment,
        sglt2_prescriptions / medicaid_enrolment_quarter_avg * 10000,
        NA_real_
      ),
    sglt2_units_all_products_per_10000 =
      dplyr::if_else(
        has_valid_medicaid_enrolment,
        sglt2_units / medicaid_enrolment_quarter_avg * 10000,
        NA_real_
      ),
    sglt2_medicaid_reimbursed_per_10000 =
      dplyr::if_else(
        has_valid_medicaid_enrolment,
        sglt2_medicaid_reimbursed / medicaid_enrolment_quarter_avg * 10000,
        NA_real_
      ),
    sglt2_reimbursement_per_prescription = dplyr::case_when(
      is.na(sglt2_prescriptions) ~ NA_real_,
      sglt2_prescriptions == 0 ~ NA_real_,
      TRUE ~ sglt2_medicaid_reimbursed / sglt2_prescriptions
    ),
    quarter_start_date = quarter_start_date(year, quarter),
    quarter_end_date = quarter_start_date %m+% lubridate::period(months = 3) - lubridate::days(1)
  ) |>
  dplyr::rename(
    sglt2_prescriptions_all_products = sglt2_prescriptions,
    sglt2_units_all_products = sglt2_units
  ) |>
  dplyr::select(-has_valid_medicaid_enrolment)

physician <- read_clean_csv(covariate_files[["physician_density"]], "AHRF physician density") |>
  dplyr::transmute(
    state = stringr::str_to_upper(state),
    population_2023_ahrf = population,
    number_physicians_2023 = number_physicians,
    physicians_per_100k_2023 = physicians_per_100k,
    number_primary_care_physicians_2023 = number_primary_care_physicians,
    primary_care_physicians_per_100k_2023 = primary_care_physicians_per_100k,
    number_cvd_physicians_2023 = number_cvd_physicians,
    cvd_physicians_per_100k_2023 = cvd_physicians_per_100k
  )

disease <- read_clean_csv(covariate_files[["disease_burden"]], "MMD disease burden") |>
  dplyr::transmute(
    state = stringr::str_to_upper(state),
    medicare_ffs_hf_ihd_prevalence_2023,
    medicare_ffs_diabetes_prevalence_2023,
    medicare_ffs_ckd_prevalence_2023
  )

rucc <- read_clean_csv(covariate_files[["rucc"]], "RUCC state rurality") |>
  dplyr::transmute(
    state = stringr::str_to_upper(state),
    rucc_nonmetro_population_share_2023,
    rucc_nonmetro_county_share_2023,
    rurality_quintile,
    rurality_quintile_label
  )

svi <- read_clean_csv(covariate_files[["svi"]], "SVI 2022 state aggregate") |>
  dplyr::transmute(
    state = stringr::str_to_upper(state),
    svi_2022,
    svi_2022_per_0_1,
    svi_counties_used_2022,
    svi_population_weight_2022,
    svi_source_year
  )

region <- read_clean_csv(covariate_files[["region"]], "Census region/division") |>
  dplyr::mutate(state = stringr::str_to_upper(state))

expansion <- read_clean_csv(covariate_files[["expansion"]], "Medicaid expansion state-quarter") |>
  dplyr::mutate(
    state = stringr::str_to_upper(state),
    year = as.integer(year),
    quarter = as.integer(quarter)
  )

list(
  physician = physician,
  disease = disease,
  rucc = rucc,
  svi = svi,
  region = region
) |>
  purrr::iwalk(~ {
    assert_valid_states(.x, .y)
    assert_no_duplicate_keys(.x, "state", .y)
  })

assert_no_duplicate_keys(expansion, c("state", "year", "quarter"), "Medicaid expansion state-quarter")

master <- base |>
  dplyr::left_join(expansion, by = c("state", "year", "quarter")) |>
  dplyr::left_join(rucc, by = "state") |>
  dplyr::left_join(svi, by = "state") |>
  dplyr::left_join(region, by = "state") |>
  dplyr::left_join(physician, by = "state") |>
  dplyr::left_join(disease, by = "state") |>
  dplyr::select(
    state,
    year,
    quarter,
    quarter_start_date,
    quarter_end_date,
    sglt2_prescriptions_all_products,
    sglt2_units_all_products,
    sglt2_medicaid_reimbursed,
    sglt2_total_reimbursed,
    n_rows,
    n_ndcs,
    medicaid_enrolment_quarter_avg,
    n_enrolment_months,
    sglt2_prescriptions_all_products_per_10000,
    sglt2_units_all_products_per_10000,
    sglt2_medicaid_reimbursed_per_10000,
    sglt2_reimbursement_per_prescription,
    rurality_quintile,
    rurality_quintile_label,
    rucc_nonmetro_population_share_2023,
    rucc_nonmetro_county_share_2023,
    svi_2022,
    svi_2022_per_0_1,
    medicaid_expansion_ever_adopted,
    medicaid_expansion_effective_date,
    medicaid_expansion_active,
    medicaid_expansion_active_any_part_quarter,
    cvd_physicians_per_100k_2023,
    primary_care_physicians_per_100k_2023,
    physicians_per_100k_2023,
    medicare_ffs_hf_ihd_prevalence_2023,
    medicare_ffs_diabetes_prevalence_2023,
    medicare_ffs_ckd_prevalence_2023,
    census_region,
    census_division,
    dplyr::everything()
  ) |>
  dplyr::arrange(state, year, quarter)

forbidden_master_denominator_cols <- intersect(c("medicaid_enrolment", "medicaid_enrolment_avg"), names(master))
if (length(forbidden_master_denominator_cols) > 0) {
  stop(
    "Final master table must only contain `medicaid_enrolment_quarter_avg`; remove: ",
    paste(forbidden_master_denominator_cols, collapse = ", "),
    call. = FALSE
  )
}

required_master_cols <- c(
  "state",
  "year",
  "quarter",
  "sglt2_prescriptions_all_products",
  "sglt2_prescriptions_all_products_per_10000",
  "medicaid_enrolment_quarter_avg",
  "rurality_quintile",
  "rurality_quintile_label",
  "rucc_nonmetro_population_share_2023",
  "svi_2022",
  "svi_2022_per_0_1",
  "medicaid_expansion_active",
  "medicaid_expansion_active_any_part_quarter",
  "cvd_physicians_per_100k_2023",
  "primary_care_physicians_per_100k_2023",
  "physicians_per_100k_2023",
  "medicare_ffs_hf_ihd_prevalence_2023",
  "medicare_ffs_diabetes_prevalence_2023",
  "medicare_ffs_ckd_prevalence_2023",
  "census_region",
  "census_division"
)

require_columns(master, required_master_cols, "final master table")
assert_no_duplicate_keys(master, c("state", "year", "quarter"), "final master table")
assert_valid_states(master, "final master table")
assert_analysis_exclusions(master, "final master table")

state_counts <- master |>
  dplyr::count(year, quarter, name = "n_states") |>
  dplyr::arrange(year, quarter)

bad_counts <- state_counts |>
  dplyr::filter(n_states != 51)

if (nrow(bad_counts) > 0) {
  print(bad_counts, n = Inf)
  stop("Final master table must have one row per state-year-quarter for all included quarters.", call. = FALSE)
}

missingness <- purrr::map_dfr(
  names(master),
  function(var) {
    tibble::tibble(
      variable = var,
      n_missing = sum(is.na(master[[var]])),
      n_non_missing = sum(!is.na(master[[var]])),
      pct_missing = 100 * mean(is.na(master[[var]]))
    )
  }
) |>
  dplyr::arrange(dplyr::desc(n_missing), variable)

safe_write_csv(master, master_file)
safe_write_csv(missingness, missingness_file)

log_lines <- c(
  "# Master Table Log",
  "",
  "Date: 2026-05-04",
  "",
  "## Inputs",
  "",
  paste0("- `", relative_project_path(c(sglt2_file, enrolment_file, covariate_files)), "`"),
  "",
  "## Output",
  "",
  paste0("- `", relative_project_path(master_file), "`"),
  paste0("- Rows: ", nrow(master)),
  paste0("- Columns: ", ncol(master)),
  "",
  "## Validation",
  "",
  "- One row per `state`-`year`-`quarter`.",
  "- 2020 excluded.",
  "- PR and XX excluded.",
  "- `medicaid_enrolment_quarter_avg` is the only Medicaid denominator in the master table.",
  "- SGLT2 outcome/count values are zero-filled only where Medicaid enrolment is valid.",
  "- Enrolment and covariates are not zero-filled.",
  "",
  "## State-Quarter Counts",
  "",
  "```",
  capture.output(print(state_counts, n = Inf)),
  "```",
  "",
  "## Missingness",
  "",
  "```",
  capture.output(print(missingness, n = Inf, width = Inf)),
  "```"
)

ensure_dir(dirname(log_file))
writeLines(log_lines, log_file)

message("Wrote final master table: ", master_file)
message("Wrote master missingness report: ", missingness_file)
message("Wrote master table log: ", log_file)
