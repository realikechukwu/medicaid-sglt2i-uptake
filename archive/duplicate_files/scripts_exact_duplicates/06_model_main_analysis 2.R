if (!requireNamespace("here", quietly = TRUE)) {
  stop("Install the `here` package before running this script.", call. = FALSE)
}
source(here::here("scripts", "00_setup.R"))

master_file <- project_path("for_analysis", "master", "master_state_quarter_sglt2_covariates.csv")
tables_dir <- project_path("for_analysis", "model_outputs", "tables")
figures_dir <- project_path("for_analysis", "model_outputs", "figures")
diagnostics_dir <- project_path("for_analysis", "model_outputs", "diagnostics")
log_file <- project_path("docs", "logs", "2026-05_modelling_log.md")

ensure_dir(tables_dir)
ensure_dir(figures_dir)
ensure_dir(diagnostics_dir)
require_files(master_file, "final master table")

master <- readr::read_csv(master_file, show_col_types = FALSE) |>
  janitor::clean_names() |>
  dplyr::mutate(
    state = stringr::str_to_upper(state),
    year = as.integer(year),
    quarter = as.integer(quarter)
  )

required_model_cols <- c(
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
  "cvd_physicians_per_100k_2023",
  "medicare_ffs_hf_ihd_prevalence_2023",
  "medicare_ffs_diabetes_prevalence_2023",
  "medicare_ffs_ckd_prevalence_2023",
  "census_region"
)

require_columns(master, required_model_cols, "final master table")
assert_no_duplicate_keys(master, c("state", "year", "quarter"), "final master table")
assert_analysis_exclusions(master, "final master table")

forbidden_denominator_cols <- intersect(c("medicaid_enrolment", "medicaid_enrolment_avg"), names(master))
if (length(forbidden_denominator_cols) > 0) {
  stop(
    "Final master table must only contain `medicaid_enrolment_quarter_avg`; remove: ",
    paste(forbidden_denominator_cols, collapse = ", "),
    call. = FALSE
  )
}

model_data <- master |>
  dplyr::filter(
    state %in% valid_50dc,
    !is.na(medicaid_enrolment_quarter_avg),
    medicaid_enrolment_quarter_avg > 0
  ) |>
  dplyr::mutate(
    year_quarter = paste0(year, " Q", quarter),
    time_index = dplyr::dense_rank(year * 10 + quarter),
    rurality_quintile = factor(rurality_quintile, levels = c(5, 4, 3, 2, 1)),
    rurality_quintile_label = factor(
      rurality_quintile_label,
      levels = c("Q5 most urban", "Q4", "Q3", "Q2", "Q1 most rural")
    ),
    census_region = factor(census_region, levels = c("Northeast", "Midwest", "South", "West")),
    log_medicaid_enrolment = log(medicaid_enrolment_quarter_avg),
    rucc_nonmetro_population_share_per_10pct = rucc_nonmetro_population_share_2023 / 0.10
  )

missing_required <- model_data |>
  dplyr::summarise(dplyr::across(dplyr::all_of(required_model_cols), ~ sum(is.na(.x)))) |>
  tidyr::pivot_longer(dplyr::everything(), names_to = "variable", values_to = "n_missing") |>
  dplyr::filter(n_missing > 0)

if (nrow(missing_required) > 0) {
  print(missing_required, n = Inf)
  stop("Required modelling variables must be complete; covariates and enrolment are not zero-filled.", call. = FALSE)
}

svi_state_quintiles <- model_data |>
  dplyr::distinct(state, svi_2022) |>
  dplyr::arrange(svi_2022, state) |>
  dplyr::mutate(
    svi_quintile = dplyr::ntile(svi_2022, 5),
    svi_quintile_label = dplyr::case_when(
      svi_quintile == 1 ~ "Q1 lowest SVI",
      svi_quintile == 2 ~ "Q2",
      svi_quintile == 3 ~ "Q3",
      svi_quintile == 4 ~ "Q4",
      svi_quintile == 5 ~ "Q5 highest SVI"
    )
  )

model_data <- model_data |>
  dplyr::left_join(svi_state_quintiles, by = c("state", "svi_2022"))

year_quarter_levels <- model_data |>
  dplyr::distinct(year, quarter, year_quarter, time_index) |>
  dplyr::arrange(time_index) |>
  dplyr::pull(year_quarter)

x_breaks <- model_data |>
  dplyr::distinct(year, quarter, year_quarter, time_index) |>
  dplyr::filter(quarter == 1) |>
  dplyr::arrange(time_index) |>
  dplyr::pull(year_quarter)

national_trend <- model_data |>
  dplyr::group_by(year, quarter, year_quarter, time_index) |>
  dplyr::summarise(
    total_sglt2_prescriptions = sum(sglt2_prescriptions_all_products, na.rm = TRUE),
    total_medicaid_enrolment = sum(medicaid_enrolment_quarter_avg, na.rm = TRUE),
    national_prescriptions_per_10000 = total_sglt2_prescriptions / total_medicaid_enrolment * 10000,
    n_states = dplyr::n_distinct(state),
    .groups = "drop"
  ) |>
  dplyr::arrange(time_index)

rurality_trend <- model_data |>
  dplyr::group_by(rurality_quintile, rurality_quintile_label, year, quarter, year_quarter, time_index) |>
  dplyr::summarise(
    total_sglt2_prescriptions = sum(sglt2_prescriptions_all_products, na.rm = TRUE),
    total_medicaid_enrolment = sum(medicaid_enrolment_quarter_avg, na.rm = TRUE),
    prescriptions_per_10000 = total_sglt2_prescriptions / total_medicaid_enrolment * 10000,
    n_states = dplyr::n_distinct(state),
    .groups = "drop"
  ) |>
  dplyr::arrange(rurality_quintile, time_index)

svi_trend <- model_data |>
  dplyr::group_by(svi_quintile, svi_quintile_label, year, quarter, year_quarter, time_index) |>
  dplyr::summarise(
    total_sglt2_prescriptions = sum(sglt2_prescriptions_all_products, na.rm = TRUE),
    total_medicaid_enrolment = sum(medicaid_enrolment_quarter_avg, na.rm = TRUE),
    prescriptions_per_10000 = total_sglt2_prescriptions / total_medicaid_enrolment * 10000,
    n_states = dplyr::n_distinct(state),
    .groups = "drop"
  ) |>
  dplyr::arrange(svi_quintile, time_index)

state_summary <- model_data |>
  dplyr::group_by(state) |>
  dplyr::summarise(
    mean_prescriptions_per_10000 = mean(sglt2_prescriptions_all_products_per_10000, na.rm = TRUE),
    median_prescriptions_per_10000 = median(sglt2_prescriptions_all_products_per_10000, na.rm = TRUE),
    min_prescriptions_per_10000 = min(sglt2_prescriptions_all_products_per_10000, na.rm = TRUE),
    max_prescriptions_per_10000 = max(sglt2_prescriptions_all_products_per_10000, na.rm = TRUE),
    total_prescriptions = sum(sglt2_prescriptions_all_products, na.rm = TRUE),
    mean_medicaid_enrolment = mean(medicaid_enrolment_quarter_avg, na.rm = TRUE),
    rurality_quintile = dplyr::first(rurality_quintile),
    rurality_quintile_label = dplyr::first(rurality_quintile_label),
    svi_2022 = dplyr::first(svi_2022),
    .groups = "drop"
  ) |>
  dplyr::arrange(state)

safe_write_csv(national_trend, file.path(tables_dir, "descriptive_national_quarterly_trend.csv"))
safe_write_csv(rurality_trend, file.path(tables_dir, "descriptive_rurality_quarterly_trend.csv"))
safe_write_csv(svi_trend, file.path(tables_dir, "descriptive_svi_quarterly_trend.csv"))
safe_write_csv(state_summary, file.path(tables_dir, "descriptive_state_summary.csv"))

fig1 <- ggplot2::ggplot(national_trend, ggplot2::aes(x = factor(year_quarter, levels = year_quarter_levels), y = national_prescriptions_per_10000, group = 1)) +
  ggplot2::geom_line(linewidth = 0.8, color = "#1f5f8b") +
  ggplot2::geom_point(size = 1.8, color = "#1f5f8b") +
  ggplot2::scale_x_discrete(breaks = x_breaks) +
  ggplot2::labs(x = "Quarter", y = "Prescriptions per 10,000 Medicaid enrollees", title = "National Quarterly Medicaid SGLT2 Prescribing Rate") +
  ggplot2::theme_minimal(base_size = 12) +
  ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 45, hjust = 1), plot.title = ggplot2::element_text(face = "bold"))
ggplot2::ggsave(file.path(figures_dir, "fig1_national_quarterly_sglt2_rate.png"), fig1, width = 10, height = 5.5, dpi = 300)

fig2 <- ggplot2::ggplot(rurality_trend, ggplot2::aes(x = factor(year_quarter, levels = year_quarter_levels), y = prescriptions_per_10000, color = rurality_quintile_label, group = rurality_quintile_label)) +
  ggplot2::geom_line(linewidth = 0.8) +
  ggplot2::scale_x_discrete(breaks = x_breaks) +
  ggplot2::labs(x = "Quarter", y = "Prescriptions per 10,000", color = "Rurality", title = "Quarterly SGLT2 Prescribing Rate by Rurality Quintile") +
  ggplot2::theme_minimal(base_size = 12) +
  ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 45, hjust = 1), legend.position = "bottom", plot.title = ggplot2::element_text(face = "bold"))
ggplot2::ggsave(file.path(figures_dir, "fig2_rurality_quintile_quarterly_sglt2_rate.png"), fig2, width = 10.5, height = 6, dpi = 300)

fig3 <- ggplot2::ggplot(svi_trend, ggplot2::aes(x = factor(year_quarter, levels = year_quarter_levels), y = prescriptions_per_10000, color = svi_quintile_label, group = svi_quintile_label)) +
  ggplot2::geom_line(linewidth = 0.8) +
  ggplot2::scale_x_discrete(breaks = x_breaks) +
  ggplot2::labs(x = "Quarter", y = "Prescriptions per 10,000", color = "SVI", title = "Quarterly SGLT2 Prescribing Rate by State SVI Quintile") +
  ggplot2::theme_minimal(base_size = 12) +
  ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 45, hjust = 1), legend.position = "bottom", plot.title = ggplot2::element_text(face = "bold"))
ggplot2::ggsave(file.path(figures_dir, "fig3_svi_quintile_quarterly_sglt2_rate.png"), fig3, width = 10.5, height = 6, dpi = 300)

fig4 <- ggplot2::ggplot(model_data, ggplot2::aes(x = rurality_quintile_label, y = sglt2_prescriptions_all_products_per_10000, fill = rurality_quintile_label)) +
  ggplot2::geom_boxplot(outlier.alpha = 0.35) +
  ggplot2::labs(x = "Rurality quintile", y = "Prescriptions per 10,000", title = "State-Quarter SGLT2 Rates by Rurality Quintile") +
  ggplot2::theme_minimal(base_size = 12) +
  ggplot2::theme(legend.position = "none", plot.title = ggplot2::element_text(face = "bold"))
ggplot2::ggsave(file.path(figures_dir, "fig4_boxplot_rates_by_rurality_quintile.png"), fig4, width = 8.5, height = 5.5, dpi = 300)

fig5_data <- model_data |>
  dplyr::group_by(state, svi_2022) |>
  dplyr::summarise(mean_rate = mean(sglt2_prescriptions_all_products_per_10000, na.rm = TRUE), .groups = "drop")

fig5 <- ggplot2::ggplot(fig5_data, ggplot2::aes(x = svi_2022, y = mean_rate)) +
  ggplot2::geom_point(size = 2.2, color = "#2f5f8f") +
  ggplot2::geom_smooth(method = "lm", se = TRUE, color = "#333333", linewidth = 0.7) +
  ggplot2::labs(x = "State SVI, 2022", y = "Mean prescriptions per 10,000", title = "State SVI vs Mean SGLT2 Prescribing Rate") +
  ggplot2::theme_minimal(base_size = 12) +
  ggplot2::theme(plot.title = ggplot2::element_text(face = "bold"))
ggplot2::ggsave(file.path(figures_dir, "fig5_scatter_svi_vs_state_mean_rate.png"), fig5, width = 8.5, height = 5.8, dpi = 300)

heatmap_data <- model_data |>
  dplyr::mutate(
    year_quarter_f = factor(year_quarter, levels = year_quarter_levels),
    state_ordered = forcats::fct_reorder(state, sglt2_prescriptions_all_products_per_10000, .fun = mean, .desc = FALSE)
  )

fig6 <- ggplot2::ggplot(heatmap_data, ggplot2::aes(x = year_quarter_f, y = state_ordered, fill = sglt2_prescriptions_all_products_per_10000)) +
  ggplot2::geom_tile() +
  ggplot2::scale_x_discrete(breaks = x_breaks) +
  ggplot2::scale_fill_viridis_c(option = "C", name = "Rate") +
  ggplot2::labs(x = "Quarter", y = "State", title = "State-Quarter Medicaid SGLT2 Prescribing Rates") +
  ggplot2::theme_minimal(base_size = 10) +
  ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 45, hjust = 1), panel.grid = ggplot2::element_blank(), plot.title = ggplot2::element_text(face = "bold"))
ggplot2::ggsave(file.path(figures_dir, "fig6_state_quarter_heatmap_sglt2_rate.png"), fig6, width = 12, height = 9.5, dpi = 300)

main_formula <- sglt2_prescriptions_all_products ~
  rurality_quintile +
  svi_2022_per_0_1 +
  medicaid_expansion_active +
  cvd_physicians_per_100k_2023 +
  medicare_ffs_hf_ihd_prevalence_2023 +
  medicare_ffs_diabetes_prevalence_2023 +
  medicare_ffs_ckd_prevalence_2023 +
  factor(year) +
  factor(quarter) +
  offset(log_medicaid_enrolment)

main_result <- fit_nb_model(
  data = model_data,
  formula = main_formula,
  model_id = "main_full",
  model_name = "Main fully adjusted negative binomial model"
)

safe_write_csv(main_result$model_based, file.path(tables_dir, "main_model_full_coefficients.csv"))
safe_write_csv(main_result$preferred, file.path(tables_dir, "main_model_full_cluster_robust_coefficients.csv"))

continuous_formula <- sglt2_prescriptions_all_products ~
  rucc_nonmetro_population_share_per_10pct +
  svi_2022_per_0_1 +
  medicaid_expansion_active +
  cvd_physicians_per_100k_2023 +
  medicare_ffs_hf_ihd_prevalence_2023 +
  medicare_ffs_diabetes_prevalence_2023 +
  medicare_ffs_ckd_prevalence_2023 +
  factor(year) +
  factor(quarter) +
  offset(log_medicaid_enrolment)

continuous_result <- fit_nb_model(
  data = model_data,
  formula = continuous_formula,
  model_id = "sensitivity_continuous_rurality",
  model_name = "Sensitivity model with continuous rurality per 10 percentage points"
)

key_lookup <- tibble::tribble(
  ~term, ~exposure, ~comparison_or_unit, ~interpretation,
  "rurality_quintile1", "Rurality", "Q1 most rural vs Q5 most urban", "Q5 most urban is the reference; IRR below 1 indicates lower prescribing.",
  "rurality_quintile2", "Rurality", "Q2 vs Q5 most urban", "Q5 most urban is the reference.",
  "rurality_quintile3", "Rurality", "Q3 vs Q5 most urban", "Q5 most urban is the reference.",
  "rurality_quintile4", "Rurality", "Q4 vs Q5 most urban", "Q5 most urban is the reference.",
  "svi_2022_per_0_1", "SVI", "Per 0.1 increase", "IRR for each 0.1 higher state-level SVI.",
  "medicaid_expansion_active", "Medicaid expansion", "Active vs not active", "IRR comparing active expansion state-quarters with non-active state-quarters.",
  "cvd_physicians_per_100k_2023", "CVD physician density", "Per 1 CVD physician per 100k", "IRR for each additional CVD physician per 100,000 population.",
  "medicare_ffs_hf_ihd_prevalence_2023", "Disease burden", "HF/IHD prevalence", "Medicare FFS state-level prevalence proxy.",
  "medicare_ffs_diabetes_prevalence_2023", "Disease burden", "Diabetes prevalence", "Medicare FFS state-level prevalence proxy.",
  "medicare_ffs_ckd_prevalence_2023", "Disease burden", "CKD prevalence", "Medicare FFS state-level prevalence proxy."
)

main_key <- main_result$preferred |>
  dplyr::inner_join(key_lookup, by = "term") |>
  dplyr::mutate(model_id = "main_full", model_name = "Main fully adjusted model") |>
  dplyr::select(model_id, model_name, exposure, comparison_or_unit, term, irr, conf_low, conf_high, p_value, se_type, interpretation)

continuous_key <- continuous_result$preferred |>
  dplyr::filter(term == "rucc_nonmetro_population_share_per_10pct") |>
  dplyr::transmute(
    model_id = "sensitivity_continuous_rurality",
    model_name = "Continuous rurality sensitivity",
    exposure = "Continuous rurality",
    comparison_or_unit = "Per 10 percentage-point higher nonmetro population share",
    term,
    irr,
    conf_low,
    conf_high,
    p_value,
    se_type,
    interpretation = "Sensitivity model replacing rurality quintile with continuous nonmetro population share."
  )

main_key_results <- dplyr::bind_rows(main_key, continuous_key)
safe_write_csv(main_key_results, file.path(tables_dir, "main_model_key_results.csv"))

forest_terms <- main_result$preferred |>
  dplyr::filter(term %in% key_lookup$term) |>
  dplyr::inner_join(key_lookup, by = "term") |>
  dplyr::mutate(label = factor(comparison_or_unit, levels = rev(comparison_or_unit)))

fig7 <- ggplot2::ggplot(forest_terms, ggplot2::aes(x = irr, y = label)) +
  ggplot2::geom_vline(xintercept = 1, linetype = "dashed", color = "grey45", linewidth = 0.5) +
  ggplot2::geom_segment(ggplot2::aes(x = conf_low, xend = conf_high, yend = label), linewidth = 0.7, color = "#2f5f8f") +
  ggplot2::geom_point(size = 2.5, color = "#123b5d") +
  ggplot2::scale_x_log10(labels = scales::number_format(accuracy = 0.01)) +
  ggplot2::labs(x = "Incidence rate ratio, log scale", y = NULL, title = "Adjusted IRRs from Main Model") +
  ggplot2::theme_minimal(base_size = 12) +
  ggplot2::theme(panel.grid.minor = ggplot2::element_blank(), plot.title = ggplot2::element_text(face = "bold"))
ggplot2::ggsave(file.path(figures_dir, "fig7_main_model_forest_plot.png"), fig7, width = 9.5, height = 6.5, dpi = 300)

poisson_model <- stats::glm(
  sglt2_prescriptions_all_products ~
    rurality_quintile +
    factor(year) +
    factor(quarter) +
    offset(log_medicaid_enrolment),
  family = poisson(),
  data = model_data
)

poisson_overdispersion <- tibble::tibble(
  model = "Poisson comparison: rurality + year + quarter",
  n_observations = stats::nobs(poisson_model),
  residual_deviance = poisson_model$deviance,
  residual_df = poisson_model$df.residual,
  dispersion_ratio = poisson_model$deviance / poisson_model$df.residual,
  warnings = NA_character_,
  error = NA_character_
)

safe_write_csv(poisson_overdispersion, file.path(diagnostics_dir, "poisson_overdispersion_check.csv"))
update_model_diagnostics(dplyr::bind_rows(main_result$diagnostics, continuous_result$diagnostics))

log_lines <- c(
  "# Modelling Log",
  "",
  "Date: 2026-05-04",
  "",
  "## Main Analysis",
  "",
  "- Outcome: `sglt2_prescriptions_all_products`.",
  "- Offset: `log_medicaid_enrolment = log(medicaid_enrolment_quarter_avg)`.",
  "- Model: negative binomial regression.",
  "- Standard errors: state-clustered robust standard errors when available.",
  "- Covariates: rurality quintile, SVI per 0.1, Medicaid expansion active, CVD physician density, Medicare FFS HF/IHD, diabetes, CKD prevalence, year fixed effects, quarter fixed effects.",
  "",
  "## Outputs",
  "",
  "- `for_analysis/model_outputs/tables/main_model_key_results.csv`",
  "- `for_analysis/model_outputs/tables/main_model_full_coefficients.csv`",
  "- `for_analysis/model_outputs/tables/main_model_full_cluster_robust_coefficients.csv`",
  "- `for_analysis/model_outputs/diagnostics/model_diagnostics_summary.csv`",
  "- `for_analysis/model_outputs/diagnostics/poisson_overdispersion_check.csv`",
  "- `for_analysis/model_outputs/figures/fig1_national_quarterly_sglt2_rate.png` through `fig7_main_model_forest_plot.png`",
  "",
  "## Key Results",
  "",
  "```",
  capture.output(print(tibble::as_tibble(main_key_results), n = Inf, width = Inf)),
  "```"
)

writeLines(log_lines, log_file)

message("Wrote main model tables, diagnostics, figures, and modelling log.")
