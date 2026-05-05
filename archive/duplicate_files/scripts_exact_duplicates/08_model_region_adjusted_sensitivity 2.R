if (!requireNamespace("here", quietly = TRUE)) {
  stop("Install the `here` package before running this script.", call. = FALSE)
}
source(here::here("scripts", "00_setup.R"))

sensitivity_master_file <- project_path(
  "for_analysis",
  "master",
  "master_state_quarter_sglt2_covariates_with_sensitivity_outcomes.csv"
)
main_key_file <- project_path("for_analysis", "model_outputs", "tables", "main_model_key_results.csv")
tables_dir <- project_path("for_analysis", "model_outputs", "tables")
figures_dir <- project_path("for_analysis", "model_outputs", "figures")
log_file <- project_path("docs", "logs", "2026-05_modelling_log.md")

require_files(c(sensitivity_master_file, main_key_file), "region-adjusted input file")
ensure_dir(tables_dir)
ensure_dir(figures_dir)

master <- readr::read_csv(sensitivity_master_file, show_col_types = FALSE) |>
  janitor::clean_names() |>
  dplyr::mutate(
    state = stringr::str_to_upper(state),
    year = as.integer(year),
    quarter = as.integer(quarter)
  )

required_cols <- c(
  "state",
  "year",
  "quarter",
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
  "medicare_ffs_ckd_prevalence_2023",
  "census_region",
  "census_division"
)

require_columns(master, required_cols, "sensitivity master table")
assert_no_duplicate_keys(master, c("state", "year", "quarter"), "sensitivity master table")
assert_analysis_exclusions(master, "sensitivity master table")

expected_region <- census_region_lookup()
region_check <- master |>
  dplyr::distinct(state, census_region, census_division) |>
  dplyr::left_join(
    expected_region |>
      dplyr::rename(
        expected_census_region = census_region,
        expected_census_division = census_division
      ),
    by = "state"
  ) |>
  dplyr::filter(
    as.character(census_region) != as.character(expected_census_region) |
      as.character(census_division) != as.character(expected_census_division)
  )

if (nrow(region_check) > 0) {
  print(region_check, n = Inf)
  stop("Census region/division values do not match the fixed 50 state + DC lookup.", call. = FALSE)
}

model_data <- master |>
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

fit_region_model <- function(outcome, label, model_id) {
  formula <- stats::as.formula(paste0(
    outcome,
    " ~ rurality_quintile + svi_2022_per_0_1 + medicaid_expansion_active + ",
    "census_region + cvd_physicians_per_100k_2023 + ",
    "medicare_ffs_hf_ihd_prevalence_2023 + medicare_ffs_diabetes_prevalence_2023 + ",
    "medicare_ffs_ckd_prevalence_2023 + factor(year) + factor(quarter) + ",
    "offset(log_medicaid_enrolment)"
  ))

  result <- fit_nb_model(
    data = model_data,
    formula = formula,
    model_id = model_id,
    model_name = paste0("Region-adjusted model: ", label)
  )

  list(
    label = label,
    result = result,
    table = result$preferred |> dplyr::mutate(outcome = label, model_id = model_id)
  )
}

region_models <- list(
  all_products = fit_region_model(
    "sglt2_prescriptions_all_products",
    "All products",
    "region_adjusted_all_products"
  ),
  single_agent = fit_region_model(
    "sglt2_prescriptions_single_agent",
    "Single-agent SGLT2 inhibitors",
    "region_adjusted_single_agent"
  ),
  empa_dapa = fit_region_model(
    "sglt2_prescriptions_empa_dapa",
    "Empagliflozin/dapagliflozin",
    "region_adjusted_empa_dapa"
  )
)

update_model_diagnostics(purrr::map_dfr(region_models, ~ .x$result$diagnostics))

key_terms <- tibble::tribble(
  ~term, ~exposure, ~comparison_or_unit, ~interpretation,
  "rurality_quintile1", "Rurality", "Q1 most rural vs Q5 most urban", "Q5 most urban is the reference.",
  "rurality_quintile2", "Rurality", "Q2 vs Q5 most urban", "Q5 most urban is the reference.",
  "rurality_quintile3", "Rurality", "Q3 vs Q5 most urban", "Q5 most urban is the reference.",
  "rurality_quintile4", "Rurality", "Q4 vs Q5 most urban", "Q5 most urban is the reference.",
  "svi_2022_per_0_1", "SVI", "Per 0.1 increase", "IRR for each 0.1 higher SVI.",
  "medicaid_expansion_active", "Medicaid expansion", "Active vs not active", "IRR comparing active expansion state-quarters with non-active state-quarters.",
  "cvd_physicians_per_100k_2023", "CVD physician density", "Per 1 CVD physician per 100k", "IRR for each additional CVD physician per 100,000 population."
)

extract_region_keys <- function(model_table) {
  region_terms <- model_table |>
    dplyr::filter(stringr::str_starts(term, "census_region")) |>
    dplyr::transmute(
      term,
      exposure = "Census region",
      comparison_or_unit = paste0(stringr::str_remove(term, "^census_region"), " vs Northeast"),
      interpretation = "Northeast is the Census region reference."
    )

  dplyr::bind_rows(key_terms, region_terms) |>
    dplyr::inner_join(model_table, by = "term") |>
    dplyr::transmute(
      outcome,
      exposure,
      comparison_or_unit,
      term,
      irr,
      conf_low,
      conf_high,
      p_value,
      se_type,
      interpretation
    )
}

all_products_keys <- extract_region_keys(region_models$all_products$table)
safe_write_csv(
  all_products_keys |> dplyr::select(-outcome),
  file.path(tables_dir, "region_adjusted_key_results.csv")
)

sensitivity_region_keys <- purrr::map_dfr(region_models, ~ extract_region_keys(.x$table))

main_key <- readr::read_csv(main_key_file, show_col_types = FALSE) |>
  janitor::clean_names()

compare_terms <- c(
  "rurality_quintile1",
  "svi_2022_per_0_1",
  "medicaid_expansion_active",
  "cvd_physicians_per_100k_2023"
)

region_compare <- all_products_keys |>
  dplyr::filter(term %in% compare_terms) |>
  dplyr::transmute(
    term,
    exposure,
    region_adjusted_model_irr = irr,
    region_adjusted_model_ci = paste0(round(irr, 3), " (", round(conf_low, 3), "-", round(conf_high, 3), ")")
  )

main_compare <- main_key |>
  dplyr::filter(model_id == "main_full", term %in% compare_terms) |>
  dplyr::transmute(
    term,
    main_model_irr = irr,
    main_model_ci = paste0(round(irr, 3), " (", round(conf_low, 3), "-", round(conf_high, 3), ")")
  )

comparison <- region_compare |>
  dplyr::left_join(main_compare, by = "term") |>
  dplyr::mutate(
    interpretation_change = dplyr::case_when(
      is.na(main_model_irr) | is.na(region_adjusted_model_irr) ~ "Unable to compare.",
      abs(log(region_adjusted_model_irr) - log(main_model_irr)) < log(1.10) ~ "Little material change in point estimate.",
      region_adjusted_model_irr < main_model_irr ~ "Region adjustment moved the point estimate downward.",
      region_adjusted_model_irr > main_model_irr ~ "Region adjustment moved the point estimate upward.",
      TRUE ~ "No clear change."
    )
  ) |>
  dplyr::select(exposure, term, main_model_irr, main_model_ci, region_adjusted_model_irr, region_adjusted_model_ci, interpretation_change)

safe_write_csv(comparison, file.path(tables_dir, "region_adjusted_vs_main_key_results.csv"))

forest_data <- all_products_keys |>
  dplyr::filter(
    term %in% c(
      "rurality_quintile4",
      "rurality_quintile3",
      "rurality_quintile2",
      "rurality_quintile1",
      "svi_2022_per_0_1",
      "medicaid_expansion_active",
      "cvd_physicians_per_100k_2023",
      "medicare_ffs_hf_ihd_prevalence_2023",
      "medicare_ffs_diabetes_prevalence_2023",
      "medicare_ffs_ckd_prevalence_2023"
    ) | stringr::str_starts(term, "census_region")
  ) |>
  dplyr::mutate(
    label = dplyr::case_when(
      term == "rurality_quintile4" ~ "Rurality Q4 vs Q5",
      term == "rurality_quintile3" ~ "Rurality Q3 vs Q5",
      term == "rurality_quintile2" ~ "Rurality Q2 vs Q5",
      term == "rurality_quintile1" ~ "Rurality Q1 most rural vs Q5",
      term == "svi_2022_per_0_1" ~ "SVI per 0.1 increase",
      term == "medicaid_expansion_active" ~ "Medicaid expansion active",
      term == "cvd_physicians_per_100k_2023" ~ "CVD physicians per 100k",
      stringr::str_starts(term, "census_region") ~ paste0(stringr::str_remove(term, "^census_region"), " region vs Northeast"),
      TRUE ~ term
    ),
    label = factor(label, levels = rev(label))
  )

fig9 <- ggplot2::ggplot(forest_data, ggplot2::aes(x = irr, y = label)) +
  ggplot2::geom_vline(xintercept = 1, linetype = "dashed", color = "grey45", linewidth = 0.5) +
  ggplot2::geom_segment(ggplot2::aes(x = conf_low, xend = conf_high, yend = label), linewidth = 0.7, color = "#2f5f8f") +
  ggplot2::geom_point(size = 2.5, color = "#123b5d") +
  ggplot2::scale_x_log10(labels = scales::number_format(accuracy = 0.01)) +
  ggplot2::labs(
    title = "Region-Adjusted Fully Adjusted Model IRRs",
    x = "Incidence rate ratio, log scale",
    y = NULL
  ) +
  ggplot2::theme_minimal(base_size = 12) +
  ggplot2::theme(
    panel.grid.minor = ggplot2::element_blank(),
    plot.title = ggplot2::element_text(face = "bold"),
    axis.text.y = ggplot2::element_text(size = 10)
  )

ggplot2::ggsave(file.path(figures_dir, "fig9_region_adjusted_forest_plot.png"), fig9, width = 10, height = 7.3, dpi = 300)

log_section <- c(
  "",
  "## Region-Adjusted Sensitivity Models",
  "",
  "- Added Census region to the fully adjusted negative binomial model.",
  "- Ran region-adjusted models for all-products, single-agent, and empagliflozin/dapagliflozin outcomes.",
  "- Wrote final region-adjusted key and comparison tables.",
  "",
  "Region-adjusted all-products key results:",
  "",
  "```",
  capture.output(print(tibble::as_tibble(all_products_keys), n = Inf, width = Inf)),
  "```",
  "",
  "Region-adjusted sensitivity outcome key results:",
  "",
  "```",
  capture.output(print(tibble::as_tibble(sensitivity_region_keys), n = Inf, width = Inf)),
  "```"
)

write(log_section, file = log_file, append = TRUE)

message("Wrote region-adjusted tables, forest plot, diagnostics, and log section.")
