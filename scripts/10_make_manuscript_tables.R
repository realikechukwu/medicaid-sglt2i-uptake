if (!requireNamespace("here", quietly = TRUE)) {
  stop("Install the `here` package before running this script.", call. = FALSE)
}
source(here::here("scripts", "00_setup.R"))

# Manuscript Tables 1-3 and the supplementary sequential-model table, laid out
# as reported. Values keep full precision; rounding is applied in the manuscript.

tables_dir <- project_path("for_analysis", "model_outputs", "tables")
manuscript_dir <- project_path("for_analysis", "manuscript_tables")
ensure_dir(manuscript_dir)

master_file <- project_path("for_analysis", "master", "master_state_quarter_sglt2_covariates.csv")
state_summary_file <- file.path(tables_dir, "descriptive_state_summary.csv")
main_key_file <- file.path(tables_dir, "main_model_key_results.csv")
region_key_file <- file.path(tables_dir, "region_adjusted_key_results.csv")
sequential_key_file <- file.path(tables_dir, "sequential_models_key_results.csv")

require_files(
  c(master_file, state_summary_file, main_key_file, region_key_file, sequential_key_file),
  "manuscript table input file"
)

master <- readr::read_csv(master_file, show_col_types = FALSE) |>
  janitor::clean_names()

# Table 1: Panel A (prescribing and exposures) and Panel B (policy, provider capacity, disease burden).
final_quarter <- master |>
  dplyr::distinct(year, quarter) |>
  dplyr::arrange(dplyr::desc(year), dplyr::desc(quarter)) |>
  dplyr::slice(1)

state_context <- master |>
  dplyr::group_by(state) |>
  dplyr::summarise(
    dplyr::across(
      c(
        rucc_nonmetro_population_share_2023,
        census_region,
        cvd_physicians_per_100k_2023,
        medicare_ffs_hf_ihd_prevalence_2023,
        medicare_ffs_diabetes_prevalence_2023,
        medicare_ffs_ckd_prevalence_2023
      ),
      dplyr::first
    ),
    n_distinct_context = dplyr::n_distinct(
      rucc_nonmetro_population_share_2023,
      census_region,
      cvd_physicians_per_100k_2023,
      medicare_ffs_hf_ihd_prevalence_2023,
      medicare_ffs_diabetes_prevalence_2023,
      medicare_ffs_ckd_prevalence_2023
    ),
    .groups = "drop"
  )

if (any(state_context$n_distinct_context != 1)) {
  stop("Table 1 contextual covariates must be constant within each state.", call. = FALSE)
}

final_expansion <- master |>
  dplyr::semi_join(final_quarter, by = c("year", "quarter")) |>
  dplyr::transmute(state, medicaid_expansion_active_final_quarter = medicaid_expansion_active)

table1 <- readr::read_csv(state_summary_file, show_col_types = FALSE) |>
  dplyr::transmute(
    state,
    rurality_quintile,
    svi_2022,
    mean_prescriptions_per_10000,
    median_prescriptions_per_10000,
    min_prescriptions_per_10000,
    max_prescriptions_per_10000,
    total_prescriptions,
    mean_medicaid_enrolment
  ) |>
  dplyr::left_join(dplyr::select(state_context, -n_distinct_context), by = "state") |>
  dplyr::left_join(final_expansion, by = "state") |>
  dplyr::mutate(
    nonmetro_population_pct_2023 = rucc_nonmetro_population_share_2023 * 100,
    final_quarter = paste0(final_quarter$year, " Q", final_quarter$quarter)
  ) |>
  dplyr::select(
    state,
    rurality_quintile,
    svi_2022,
    mean_prescriptions_per_10000,
    median_prescriptions_per_10000,
    min_prescriptions_per_10000,
    max_prescriptions_per_10000,
    total_prescriptions,
    mean_medicaid_enrolment,
    nonmetro_population_pct_2023,
    census_region,
    medicaid_expansion_active_final_quarter,
    final_quarter,
    cvd_physicians_per_100k_2023,
    medicare_ffs_hf_ihd_prevalence_2023,
    medicare_ffs_diabetes_prevalence_2023,
    medicare_ffs_ckd_prevalence_2023
  ) |>
  dplyr::arrange(state)

if (nrow(table1) != length(valid_50dc) || anyNA(table1)) {
  stop("Table 1 must have one complete row for each of the 50 states and DC.", call. = FALSE)
}

safe_write_csv(table1, file.path(manuscript_dir, "table1_state_characteristics.csv"))

# Table 2: primary fully adjusted model (Model 6), state-characteristic coefficients.
table2_terms <- c(
  "rurality_quintile1",
  "rurality_quintile2",
  "rurality_quintile3",
  "rurality_quintile4",
  "svi_2022_per_0_1",
  "medicaid_expansion_active",
  "cvd_physicians_per_100k_2023",
  "medicare_ffs_hf_ihd_prevalence_2023",
  "medicare_ffs_diabetes_prevalence_2023",
  "medicare_ffs_ckd_prevalence_2023"
)

main_key <- readr::read_csv(main_key_file, show_col_types = FALSE) |>
  dplyr::filter(model_id == "main_full")

table2 <- main_key |>
  dplyr::filter(term %in% table2_terms) |>
  dplyr::mutate(term = factor(term, levels = table2_terms)) |>
  dplyr::arrange(term) |>
  dplyr::mutate(term = as.character(term)) |>
  dplyr::select(term, exposure, comparison_or_unit, irr, conf_low, conf_high, p_value)

if (nrow(table2) != length(table2_terms)) {
  stop("Table 2 is missing primary-model terms.", call. = FALSE)
}

safe_write_csv(table2, file.path(manuscript_dir, "table2_primary_model.csv"))

# Table 3: primary versus Census-region-adjusted model for the three central associations.
table3_terms <- c("rurality_quintile1", "svi_2022_per_0_1", "medicaid_expansion_active")

region_key <- readr::read_csv(region_key_file, show_col_types = FALSE)

table3 <- main_key |>
  dplyr::filter(term %in% table3_terms) |>
  dplyr::select(term, exposure, comparison_or_unit, primary_irr = irr, primary_conf_low = conf_low, primary_conf_high = conf_high, primary_p_value = p_value) |>
  dplyr::inner_join(
    region_key |>
      dplyr::select(term, region_adjusted_irr = irr, region_adjusted_conf_low = conf_low, region_adjusted_conf_high = conf_high, region_adjusted_p_value = p_value),
    by = "term"
  ) |>
  dplyr::mutate(term = factor(term, levels = table3_terms)) |>
  dplyr::arrange(term) |>
  dplyr::mutate(term = as.character(term))

if (nrow(table3) != length(table3_terms)) {
  stop("Table 3 is missing primary or region-adjusted terms.", call. = FALSE)
}

safe_write_csv(table3, file.path(manuscript_dir, "table3_primary_vs_region_adjusted.csv"))

# Supplementary table: sequential adjustment series (Models 1-7).
file.copy(
  sequential_key_file,
  file.path(manuscript_dir, "table_supplement_sequential_models.csv"),
  overwrite = TRUE
)

message("Wrote manuscript tables to: ", relative_project_path(manuscript_dir))
