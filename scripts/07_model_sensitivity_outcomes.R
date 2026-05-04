if (!requireNamespace("here", quietly = TRUE)) {
  stop("Install the `here` package before running this script.", call. = FALSE)
}
source(here::here("scripts", "00_setup.R"))

master_file <- project_path("for_analysis", "master", "master_state_quarter_sglt2_covariates.csv")
sensitivity_master_file <- project_path(
  "for_analysis",
  "master",
  "master_state_quarter_sglt2_covariates_with_sensitivity_outcomes.csv"
)
single_agent_file <- project_path("data_processed", "sdud_extracts", "sglt2_state_quarter_single_agent_2015_2025.csv")
empa_dapa_file <- project_path("data_processed", "sdud_extracts", "sglt2_state_quarter_empa_dapa_2015_2025.csv")
tables_dir <- project_path("for_analysis", "model_outputs", "tables")
figures_dir <- project_path("for_analysis", "model_outputs", "figures")
log_file <- project_path("docs", "logs", "2026-05_modelling_log.md")

require_files(c(master_file, single_agent_file, empa_dapa_file), "sensitivity input file")
ensure_dir(tables_dir)
ensure_dir(figures_dir)

read_clean_csv <- function(path, label) {
  readr::read_csv(path, show_col_types = FALSE) |>
    janitor::clean_names()
}

make_sensitivity_outcome <- function(path, suffix, label) {
  raw <- read_clean_csv(path, label) |>
    dplyr::mutate(
      state = stringr::str_to_upper(state),
      year = as.integer(year),
      quarter = as.integer(quarter)
    ) |>
    dplyr::filter(year %in% analysis_years, year != 2020, state %in% valid_50dc)

  require_columns(
    raw,
    c("state", "year", "quarter", "sglt2_prescriptions", "sglt2_units"),
    label
  )
  assert_no_duplicate_keys(raw, c("state", "year", "quarter"), label)
  assert_analysis_exclusions(raw, label)

  raw |>
    dplyr::transmute(
      state,
      year,
      quarter,
      "sglt2_prescriptions_{suffix}" := sglt2_prescriptions,
      "sglt2_units_{suffix}" := sglt2_units
    )
}

master <- read_clean_csv(master_file, "final master table") |>
  dplyr::mutate(
    state = stringr::str_to_upper(state),
    year = as.integer(year),
    quarter = as.integer(quarter)
  )

required_master_cols <- c(
  "state",
  "year",
  "quarter",
  "sglt2_prescriptions_all_products",
  "sglt2_prescriptions_all_products_per_10000",
  "medicaid_enrolment_quarter_avg",
  "rurality_quintile",
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

require_columns(master, required_master_cols, "final master table")
assert_no_duplicate_keys(master, c("state", "year", "quarter"), "final master table")

single_agent <- make_sensitivity_outcome(single_agent_file, "single_agent", "single-agent SGLT2 state-quarter file")
empa_dapa <- make_sensitivity_outcome(empa_dapa_file, "empa_dapa", "empagliflozin/dapagliflozin state-quarter file")

sensitivity_master <- master |>
  dplyr::left_join(single_agent, by = c("state", "year", "quarter")) |>
  dplyr::left_join(empa_dapa, by = c("state", "year", "quarter")) |>
  dplyr::mutate(
    has_valid_medicaid_enrolment =
      !is.na(medicaid_enrolment_quarter_avg) & medicaid_enrolment_quarter_avg > 0,
    dplyr::across(
      dplyr::all_of(c(
        "sglt2_prescriptions_single_agent",
        "sglt2_units_single_agent",
        "sglt2_prescriptions_empa_dapa",
        "sglt2_units_empa_dapa"
      )),
      ~ dplyr::if_else(has_valid_medicaid_enrolment & is.na(.x), 0, .x)
    ),
    sglt2_prescriptions_single_agent_per_10000 =
      dplyr::if_else(
        has_valid_medicaid_enrolment,
        sglt2_prescriptions_single_agent / medicaid_enrolment_quarter_avg * 10000,
        NA_real_
      ),
    sglt2_prescriptions_empa_dapa_per_10000 =
      dplyr::if_else(
        has_valid_medicaid_enrolment,
        sglt2_prescriptions_empa_dapa / medicaid_enrolment_quarter_avg * 10000,
        NA_real_
      )
  ) |>
  dplyr::select(-has_valid_medicaid_enrolment)

require_columns(
  sensitivity_master,
  c(
    "sglt2_prescriptions_single_agent",
    "sglt2_prescriptions_empa_dapa",
    "sglt2_prescriptions_single_agent_per_10000",
    "sglt2_prescriptions_empa_dapa_per_10000"
  ),
  "sensitivity master table"
)
assert_no_duplicate_keys(sensitivity_master, c("state", "year", "quarter"), "sensitivity master table")
assert_analysis_exclusions(sensitivity_master, "sensitivity master table")

safe_write_csv(sensitivity_master, sensitivity_master_file)

model_data <- sensitivity_master |>
  dplyr::filter(
    state %in% valid_50dc,
    !is.na(medicaid_enrolment_quarter_avg),
    medicaid_enrolment_quarter_avg > 0
  ) |>
  dplyr::mutate(
    rurality_quintile = factor(rurality_quintile, levels = c(5, 4, 3, 2, 1)),
    census_region = factor(census_region, levels = c("Northeast", "Midwest", "South", "West")),
    log_medicaid_enrolment = log(medicaid_enrolment_quarter_avg)
  )

complete_cols <- c(
  "sglt2_prescriptions_all_products",
  "sglt2_prescriptions_single_agent",
  "sglt2_prescriptions_empa_dapa",
  "medicaid_enrolment_quarter_avg",
  "rurality_quintile",
  "svi_2022_per_0_1",
  "medicaid_expansion_active",
  "cvd_physicians_per_100k_2023",
  "medicare_ffs_hf_ihd_prevalence_2023",
  "medicare_ffs_diabetes_prevalence_2023",
  "medicare_ffs_ckd_prevalence_2023"
)

missing_complete <- model_data |>
  dplyr::summarise(dplyr::across(dplyr::all_of(complete_cols), ~ sum(is.na(.x)))) |>
  tidyr::pivot_longer(dplyr::everything(), names_to = "variable", values_to = "n_missing") |>
  dplyr::filter(n_missing > 0)

if (nrow(missing_complete) > 0) {
  print(missing_complete, n = Inf)
  stop("Sensitivity models require complete outcomes, enrolment, and covariates.", call. = FALSE)
}

fit_sensitivity_model <- function(outcome, label, model_id) {
  formula <- stats::as.formula(paste0(
    outcome,
    " ~ rurality_quintile + svi_2022_per_0_1 + medicaid_expansion_active + ",
    "cvd_physicians_per_100k_2023 + medicare_ffs_hf_ihd_prevalence_2023 + ",
    "medicare_ffs_diabetes_prevalence_2023 + medicare_ffs_ckd_prevalence_2023 + ",
    "factor(year) + factor(quarter) + offset(log_medicaid_enrolment)"
  ))

  result <- fit_nb_model(
    data = model_data,
    formula = formula,
    model_id = model_id,
    model_name = paste0("Sensitivity outcome model: ", label)
  )

  result$preferred |>
    dplyr::mutate(outcome = label, model_id = model_id)
}

model_outputs <- list(
  all_products = fit_sensitivity_model(
    "sglt2_prescriptions_all_products",
    "All products",
    "sensitivity_outcome_all_products"
  ),
  single_agent = fit_sensitivity_model(
    "sglt2_prescriptions_single_agent",
    "Single-agent SGLT2 inhibitors",
    "sensitivity_outcome_single_agent"
  ),
  empa_dapa = fit_sensitivity_model(
    "sglt2_prescriptions_empa_dapa",
    "Empagliflozin/dapagliflozin",
    "sensitivity_outcome_empa_dapa"
  )
)

diagnostics <- purrr::imap_dfr(
  list(
    all_products = "sglt2_prescriptions_all_products",
    single_agent = "sglt2_prescriptions_single_agent",
    empa_dapa = "sglt2_prescriptions_empa_dapa"
  ),
  function(outcome, key) {
    formula <- stats::as.formula(paste0(
      outcome,
      " ~ rurality_quintile + svi_2022_per_0_1 + medicaid_expansion_active + ",
      "cvd_physicians_per_100k_2023 + medicare_ffs_hf_ihd_prevalence_2023 + ",
      "medicare_ffs_diabetes_prevalence_2023 + medicare_ffs_ckd_prevalence_2023 + ",
      "factor(year) + factor(quarter) + offset(log_medicaid_enrolment)"
    ))
    fit_nb_model(
      data = model_data,
      formula = formula,
      model_id = paste0("sensitivity_diagnostics_", key),
      model_name = paste0("Sensitivity diagnostics: ", key)
    )$diagnostics
  }
)
update_model_diagnostics(diagnostics)

key_terms <- tibble::tribble(
  ~term, ~exposure, ~comparison_or_unit,
  "rurality_quintile1", "Rurality", "Q1 most rural vs Q5 most urban",
  "svi_2022_per_0_1", "SVI", "Per 0.1 increase",
  "medicaid_expansion_active", "Medicaid expansion", "Active vs not active",
  "cvd_physicians_per_100k_2023", "CVD physician density", "Per 1 CVD physician per 100k"
)

key_results <- dplyr::bind_rows(model_outputs) |>
  dplyr::inner_join(key_terms, by = "term") |>
  dplyr::transmute(
    outcome,
    exposure,
    comparison_or_unit,
    term,
    irr,
    conf_low,
    conf_high,
    p_value,
    se_type
  ) |>
  dplyr::mutate(
    outcome = factor(
      outcome,
      levels = c("All products", "Single-agent SGLT2 inhibitors", "Empagliflozin/dapagliflozin")
    ),
    exposure = factor(exposure, levels = c("Rurality", "SVI", "Medicaid expansion", "CVD physician density"))
  ) |>
  dplyr::arrange(outcome, exposure)

safe_write_csv(
  key_results,
  file.path(tables_dir, "sensitivity_outcome_comparison_key_results.csv")
)

plot_data <- key_results |>
  dplyr::mutate(
    exposure_label = dplyr::case_when(
      exposure == "Rurality" ~ "Q1 most rural vs Q5 most urban",
      exposure == "SVI" ~ "SVI per 0.1 increase",
      exposure == "Medicaid expansion" ~ "Medicaid expansion active",
      exposure == "CVD physician density" ~ "CVD physicians per 100k"
    ),
    exposure_label = factor(
      exposure_label,
      levels = rev(c(
        "Q1 most rural vs Q5 most urban",
        "SVI per 0.1 increase",
        "Medicaid expansion active",
        "CVD physicians per 100k"
      ))
    )
  )

fig8 <- ggplot2::ggplot(plot_data, ggplot2::aes(x = irr, y = exposure_label, color = outcome)) +
  ggplot2::geom_vline(xintercept = 1, linetype = "dashed", color = "grey45", linewidth = 0.5) +
  ggplot2::geom_errorbarh(
    ggplot2::aes(xmin = conf_low, xmax = conf_high),
    position = ggplot2::position_dodge(width = 0.55),
    height = 0.18,
    linewidth = 0.65
  ) +
  ggplot2::geom_point(position = ggplot2::position_dodge(width = 0.55), size = 2.4) +
  ggplot2::scale_x_log10(labels = scales::number_format(accuracy = 0.01)) +
  ggplot2::scale_color_brewer(palette = "Dark2", name = "Outcome") +
  ggplot2::labs(
    title = "Fully Adjusted IRRs Across SGLT2 Sensitivity Outcomes",
    x = "Incidence rate ratio, log scale",
    y = NULL
  ) +
  ggplot2::theme_minimal(base_size = 12) +
  ggplot2::theme(
    panel.grid.minor = ggplot2::element_blank(),
    legend.position = "bottom",
    plot.title = ggplot2::element_text(face = "bold")
  )

ggplot2::ggsave(
  file.path(figures_dir, "fig8_sensitivity_outcome_comparison_forest_plot.png"),
  fig8,
  width = 9.5,
  height = 5.8,
  dpi = 300
)

log_section <- c(
  "",
  "## Sensitivity Outcome Models",
  "",
  "- Built `for_analysis/master/master_state_quarter_sglt2_covariates_with_sensitivity_outcomes.csv`.",
  "- Outcomes: all products, single-agent SGLT2 inhibitors, and empagliflozin/dapagliflozin.",
  "- Model specification matches the fully adjusted main model.",
  "- Sensitivity outcome counts are zero-filled only where Medicaid enrolment is valid.",
  "",
  "```",
  capture.output(print(tibble::as_tibble(key_results), n = Inf, width = Inf)),
  "```"
)

write(log_section, file = log_file, append = TRUE)

message("Wrote sensitivity master, key table, forest plot, and diagnostics.")
