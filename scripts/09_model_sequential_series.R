if (!requireNamespace("here", quietly = TRUE)) {
  stop("Install the `here` package before running this script.", call. = FALSE)
}
source(here::here("scripts", "00_setup.R"))

# Sequential adjustment series reported in the manuscript Methods/Results
# (Models 1-5), assembled with the primary model (Model 6, script 06) and the
# Census-region-adjusted model (Model 7, script 08) into one comparison table.

master_file <- project_path("for_analysis", "master", "master_state_quarter_sglt2_covariates.csv")
main_coef_file <- project_path("for_analysis", "model_outputs", "tables", "main_model_full_cluster_robust_coefficients.csv")
region_key_file <- project_path("for_analysis", "model_outputs", "tables", "region_adjusted_key_results.csv")
tables_dir <- project_path("for_analysis", "model_outputs", "tables")
log_file <- project_path("docs", "logs", "2026-05_modelling_log.md")

require_files(c(master_file, main_coef_file, region_key_file), "sequential-series input file")
ensure_dir(tables_dir)

master <- readr::read_csv(master_file, show_col_types = FALSE) |>
  janitor::clean_names() |>
  dplyr::mutate(
    state = stringr::str_to_upper(state),
    year = as.integer(year),
    quarter = as.integer(quarter)
  )

assert_no_duplicate_keys(master, c("state", "year", "quarter"), "final master table")
assert_analysis_exclusions(master, "final master table")

# Same analytic sample and coding as scripts/06_model_main_analysis.R.
model_data <- master |>
  dplyr::filter(
    state %in% valid_50dc,
    !is.na(medicaid_enrolment_quarter_avg),
    medicaid_enrolment_quarter_avg > 0
  ) |>
  dplyr::mutate(
    rurality_quintile = factor(rurality_quintile, levels = c(5, 4, 3, 2, 1)),
    log_medicaid_enrolment = log(medicaid_enrolment_quarter_avg)
  )

time_terms <- "factor(year) + factor(quarter) + offset(log_medicaid_enrolment)"

sequential_specs <- tibble::tribble(
  ~model_id, ~model_label, ~adjustment_set, ~exposures,
  "model_1", "Model 1", "Rurality + time", "rurality_quintile",
  "model_2", "Model 2", "SVI + time", "svi_2022_per_0_1",
  "model_3", "Model 3", "Rurality + SVI + time", "rurality_quintile + svi_2022_per_0_1",
  "model_4", "Model 4", "Model 3 + Medicaid expansion", "rurality_quintile + svi_2022_per_0_1 + medicaid_expansion_active",
  "model_5", "Model 5", "Model 4 + CVD physician density", "rurality_quintile + svi_2022_per_0_1 + medicaid_expansion_active + cvd_physicians_per_100k_2023"
)

sequential_results <- purrr::pmap(sequential_specs, function(model_id, model_label, adjustment_set, exposures) {
  fit_nb_model(
    data = model_data,
    formula = stats::as.formula(paste("sglt2_prescriptions_all_products ~", exposures, "+", time_terms)),
    model_id = model_id,
    model_name = paste0(model_label, ": ", adjustment_set)
  )
})
names(sequential_results) <- sequential_specs$model_id

# Guard against drift: refitting the primary model here must reproduce script 06 exactly.
primary_check <- fit_nb_model(
  data = model_data,
  formula = stats::as.formula(paste(
    "sglt2_prescriptions_all_products ~ rurality_quintile + svi_2022_per_0_1 + medicaid_expansion_active +",
    "cvd_physicians_per_100k_2023 + medicare_ffs_hf_ihd_prevalence_2023 + medicare_ffs_diabetes_prevalence_2023 +",
    "medicare_ffs_ckd_prevalence_2023 +", time_terms
  )),
  model_id = "model_6_check",
  model_name = "Primary model refit (consistency check)"
)

main_coefficients <- readr::read_csv(main_coef_file, show_col_types = FALSE)
primary_diff <- dplyr::inner_join(main_coefficients, primary_check$preferred, by = "term", suffix = c("_main", "_check")) |>
  dplyr::summarise(
    n_terms = dplyr::n(),
    max_abs_diff = max(abs(estimate_main - estimate_check), abs(std_error_main - std_error_check))
  )

if (primary_diff$n_terms != nrow(main_coefficients) || primary_diff$max_abs_diff > 1e-8) {
  stop("Sequential-series data preparation no longer reproduces the primary model from script 06.", call. = FALSE)
}

sequential_coefficients <- purrr::imap_dfr(sequential_results, function(result, model_id) {
  result$preferred |>
    dplyr::mutate(model_id = model_id, .before = 1)
}) |>
  dplyr::left_join(dplyr::select(sequential_specs, model_id, model_label, adjustment_set), by = "model_id") |>
  dplyr::relocate(model_label, adjustment_set, .after = model_id)

safe_write_csv(sequential_coefficients, file.path(tables_dir, "sequential_models_cluster_robust_coefficients.csv"))

key_lookup <- tibble::tribble(
  ~term, ~exposure, ~comparison_or_unit,
  "rurality_quintile1", "Rurality", "Q1 most rural vs Q5 most urban",
  "rurality_quintile2", "Rurality", "Q2 vs Q5 most urban",
  "rurality_quintile3", "Rurality", "Q3 vs Q5 most urban",
  "rurality_quintile4", "Rurality", "Q4 vs Q5 most urban",
  "svi_2022_per_0_1", "SVI", "Per 0.1 increase",
  "medicaid_expansion_active", "Medicaid expansion", "Active vs not active",
  "cvd_physicians_per_100k_2023", "CVD physician density", "Per 1 CVD physician per 100k"
)

model_order <- tibble::tribble(
  ~model_id, ~model_label, ~adjustment_set,
  "model_1", "Model 1", "Rurality + time",
  "model_2", "Model 2", "SVI + time",
  "model_3", "Model 3", "Rurality + SVI + time",
  "model_4", "Model 4", "Model 3 + Medicaid expansion",
  "model_5", "Model 5", "Model 4 + CVD physician density",
  "model_6", "Model 6 (primary)", "Model 5 + Medicare FFS HF/IHD, diabetes and CKD prevalence",
  "model_7", "Model 7 (region-adjusted)", "Model 6 + Census region"
)

primary_rows <- main_coefficients |>
  dplyr::mutate(model_id = "model_6")

region_rows <- readr::read_csv(region_key_file, show_col_types = FALSE) |>
  dplyr::mutate(model_id = "model_7")

sequential_key_results <- dplyr::bind_rows(
  dplyr::select(sequential_coefficients, model_id, term, irr, conf_low, conf_high, p_value, se_type),
  dplyr::select(primary_rows, model_id, term, irr, conf_low, conf_high, p_value, se_type),
  dplyr::select(region_rows, model_id, term, irr, conf_low, conf_high, p_value, se_type)
) |>
  dplyr::inner_join(key_lookup, by = "term") |>
  dplyr::inner_join(model_order, by = "model_id") |>
  dplyr::mutate(
    model_id = factor(model_id, levels = model_order$model_id),
    term = factor(term, levels = key_lookup$term)
  ) |>
  dplyr::arrange(model_id, term) |>
  dplyr::mutate(model_id = as.character(model_id), term = as.character(term)) |>
  dplyr::select(model_id, model_label, adjustment_set, exposure, comparison_or_unit, term, irr, conf_low, conf_high, p_value, se_type)

safe_write_csv(sequential_key_results, file.path(tables_dir, "sequential_models_key_results.csv"))

update_model_diagnostics(purrr::map_dfr(sequential_results, "diagnostics"))

cat(
  "",
  "## Sequential Adjustment Series",
  "",
  "- Models 1-5 fitted in `scripts/09_model_sequential_series.R`; Model 6 is the primary model (script 06) and Model 7 the region-adjusted model (script 08).",
  "- All models: negative binomial, log mean monthly Medicaid enrolment offset, categorical year and quarter, state-clustered robust standard errors.",
  "- Output: `for_analysis/model_outputs/tables/sequential_models_key_results.csv` and `sequential_models_cluster_robust_coefficients.csv`.",
  "",
  "```",
  capture.output(print(tibble::as_tibble(sequential_key_results), n = Inf, width = Inf)),
  "```",
  sep = "\n",
  file = log_file,
  append = TRUE
)

message("Wrote sequential model series tables and diagnostics.")
