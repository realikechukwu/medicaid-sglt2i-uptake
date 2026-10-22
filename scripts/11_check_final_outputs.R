if (!requireNamespace("here", quietly = TRUE)) {
  stop("Install the `here` package before running this script.", call. = FALSE)
}
source(here::here("scripts", "00_setup.R"))

final_outputs <- c(
  project_path("for_analysis", "master", "master_state_quarter_sglt2_covariates.csv"),
  project_path("for_analysis", "master", "master_state_quarter_sglt2_covariates_with_sensitivity_outcomes.csv"),
  project_path("for_analysis", "model_outputs", "tables", "main_model_key_results.csv"),
  project_path("for_analysis", "model_outputs", "tables", "main_model_full_coefficients.csv"),
  project_path("for_analysis", "model_outputs", "tables", "main_model_full_cluster_robust_coefficients.csv"),
  project_path("for_analysis", "model_outputs", "tables", "sensitivity_outcome_comparison_key_results.csv"),
  project_path("for_analysis", "model_outputs", "tables", "region_adjusted_key_results.csv"),
  project_path("for_analysis", "model_outputs", "tables", "region_adjusted_vs_main_key_results.csv"),
  project_path("for_analysis", "model_outputs", "tables", "descriptive_national_quarterly_trend.csv"),
  project_path("for_analysis", "model_outputs", "tables", "descriptive_rurality_quarterly_trend.csv"),
  project_path("for_analysis", "model_outputs", "tables", "descriptive_svi_quarterly_trend.csv"),
  project_path("for_analysis", "model_outputs", "tables", "descriptive_state_summary.csv"),
  project_path("for_analysis", "model_outputs", "tables", "sequential_models_key_results.csv"),
  project_path("for_analysis", "model_outputs", "tables", "sequential_models_cluster_robust_coefficients.csv"),
  project_path("for_analysis", "manuscript_tables", "table1_svi_quintile_summary.csv"),
  project_path("for_analysis", "manuscript_tables", "table_s1_state_characteristics.csv"),
  project_path("for_analysis", "manuscript_tables", "table2_primary_model.csv"),
  project_path("for_analysis", "manuscript_tables", "table3_primary_vs_region_adjusted.csv"),
  project_path("for_analysis", "manuscript_tables", "table_s2_national_quarterly.csv"),
  project_path("for_analysis", "manuscript_tables", "table_s3_rurality_quintile_quarterly.csv"),
  project_path("for_analysis", "manuscript_tables", "table_s4_svi_quintile_quarterly.csv"),
  project_path("for_analysis", "manuscript_tables", "table_s5_sequential_models.csv"),
  project_path("for_analysis", "manuscript_tables", "supplementary_tables_S2_S5.xlsx"),
  project_path("for_analysis", "model_outputs", "diagnostics", "model_diagnostics_summary.csv"),
  project_path("for_analysis", "model_outputs", "diagnostics", "poisson_overdispersion_check.csv"),
  project_path("for_analysis", "model_outputs", "diagnostics", "master_missingness_report.csv"),
  project_path("for_analysis", "model_outputs", "diagnostics", "sdud_suppression_bound.csv"),
  project_path("for_analysis", "model_outputs", "figures", "fig1_national_quarterly_sglt2_rate.png"),
  project_path("for_analysis", "model_outputs", "figures", "fig2_rurality_quintile_quarterly_sglt2_rate.png"),
  project_path("for_analysis", "model_outputs", "figures", "fig3_svi_quintile_quarterly_sglt2_rate.png"),
  project_path("for_analysis", "model_outputs", "figures", "fig4_boxplot_rates_by_rurality_quintile.png"),
  project_path("for_analysis", "model_outputs", "figures", "fig5_scatter_svi_vs_state_mean_rate.png"),
  project_path("for_analysis", "model_outputs", "figures", "fig6_state_quarter_heatmap_sglt2_rate.png"),
  project_path("for_analysis", "model_outputs", "figures", "fig7_main_model_forest_plot.png"),
  project_path("for_analysis", "model_outputs", "figures", "fig8_sensitivity_outcome_comparison_forest_plot.png"),
  project_path("for_analysis", "model_outputs", "figures", "fig9_region_adjusted_forest_plot.png"),
  project_path("docs", "logs", "2026-05_master_table_log.md"),
  project_path("docs", "logs", "2026-05_modelling_log.md")
)

missing_outputs <- final_outputs[!file.exists(final_outputs)]
if (length(missing_outputs) > 0) {
  stop(
    "Missing final output(s):\n",
    paste(missing_outputs, collapse = "\n"),
    call. = FALSE
  )
}

master <- readr::read_csv(
  project_path("for_analysis", "master", "master_state_quarter_sglt2_covariates_with_sensitivity_outcomes.csv"),
  show_col_types = FALSE
) |>
  janitor::clean_names()

require_columns(
  master,
  c(
    "state",
    "year",
    "quarter",
    "medicaid_enrolment_quarter_avg",
    "sglt2_prescriptions_all_products",
    "sglt2_prescriptions_single_agent",
    "sglt2_prescriptions_empa_dapa",
    "sglt2_prescriptions_all_products_per_10000",
    "sglt2_prescriptions_single_agent_per_10000",
    "sglt2_prescriptions_empa_dapa_per_10000",
    "census_region"
  ),
  "final sensitivity master table"
)

assert_no_duplicate_keys(master, c("state", "year", "quarter"), "final sensitivity master table")
assert_analysis_exclusions(master, "final sensitivity master table")

if (length(intersect(c("medicaid_enrolment", "medicaid_enrolment_avg"), names(master))) > 0) {
  stop("Final sensitivity master contains forbidden Medicaid denominator aliases.", call. = FALSE)
}

message("Final output check passed.")
