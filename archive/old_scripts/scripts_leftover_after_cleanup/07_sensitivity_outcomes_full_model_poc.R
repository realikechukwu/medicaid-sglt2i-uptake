# Add sensitivity SGLT2 outcomes and fit only fully adjusted models.

suppressPackageStartupMessages({
  library(MASS)
  library(tidyverse)
  library(janitor)
  library(here)
  library(broom)
  library(sandwich)
  library(lmtest)
  library(ggplot2)
  library(readr)
  library(scales)
  library(forcats)
})

valid_50dc <- c(state.abb, "DC")

input_files <- c(
  master = "master_state_quarter_sglt2_covariates_poc.csv",
  single_agent = "sglt2_state_quarter_rates_single_agent_50dc_excluding_2020.csv",
  empa_dapa = "sglt2_state_quarter_rates_empa_dapa_50dc_excluding_2020.csv"
)

for_analysis_dir <- here("for_analysis")
model_output_dir <- here("for_analysis", "model_outputs")
plot_dir <- here("for_analysis", "model_outputs", "plots")
docs_dir <- here("docs")

dir.create(model_output_dir, showWarnings = FALSE, recursive = TRUE)
dir.create(plot_dir, showWarnings = FALSE, recursive = TRUE)
dir.create(docs_dir, showWarnings = FALSE, recursive = TRUE)

path_in <- function(file) here("for_analysis", file)
path_out <- function(file) here("for_analysis", "model_outputs", file)
plot_out <- function(file) here("for_analysis", "model_outputs", "plots", file)
doc_out <- function(file) here("docs", file)

print_section <- function(label) {
  message("\n# ------------------------------------------------------------")
  message("# ", label)
  message("# ------------------------------------------------------------")
}

require_columns <- function(data, required, data_label) {
  missing <- setdiff(required, names(data))
  if (length(missing) > 0) {
    message("Available columns in ", data_label, ":")
    print(names(data))
    stop(
      data_label,
      " is missing required column(s): ",
      paste(missing, collapse = ", "),
      call. = FALSE
    )
  }
  invisible(data)
}

assert_no_duplicate_keys <- function(data, keys, data_label) {
  duplicate_rows <- data |>
    count(across(all_of(keys)), name = "n") |>
    filter(n > 1)

  if (nrow(duplicate_rows) > 0) {
    message("Duplicate key rows in ", data_label, ":")
    print(duplicate_rows, n = Inf)
    stop(data_label, " contains duplicate key rows.", call. = FALSE)
  }

  invisible(data)
}

assert_valid_states <- function(data, data_label) {
  invalid <- setdiff(unique(data$state), valid_50dc)
  if (length(invalid) > 0) {
    stop(
      data_label,
      " contains state codes outside 50 states + DC: ",
      paste(sort(invalid), collapse = ", "),
      call. = FALSE
    )
  }
  invisible(data)
}

read_clean_csv <- function(file, data_label) {
  full_path <- path_in(file)
  if (!file.exists(full_path)) {
    stop("Missing input file: ", full_path, call. = FALSE)
  }

  readr::read_csv(full_path, show_col_types = FALSE) |>
    janitor::clean_names()
}

make_sensitivity_outcome_table <- function(file, suffix, data_label) {
  raw <- read_clean_csv(file, data_label) |>
    mutate(
      state = stringr::str_to_upper(state),
      year = as.integer(year),
      quarter = as.integer(quarter)
    )

  required <- c(
    "state",
    "year",
    "quarter",
    "sglt2_prescriptions",
    "sglt2_units",
    "sglt2_prescriptions_per_10000"
  )

  require_columns(raw, required, data_label)
  assert_no_duplicate_keys(raw, c("state", "year", "quarter"), data_label)
  assert_valid_states(raw, data_label)

  raw |>
    transmute(
      state,
      year,
      quarter,
      "sglt2_prescriptions_{suffix}" := sglt2_prescriptions,
      "sglt2_units_{suffix}" := sglt2_units,
      "sglt2_prescriptions_{suffix}_per_10000" := sglt2_prescriptions_per_10000
    )
}

fit_with_warnings <- function(expr) {
  warnings <- character()
  error <- NULL
  result <- tryCatch(
    withCallingHandlers(
      expr,
      warning = function(w) {
        warnings <<- c(warnings, conditionMessage(w))
        invokeRestart("muffleWarning")
      }
    ),
    error = function(e) {
      error <<- conditionMessage(e)
      NULL
    }
  )

  list(result = result, warnings = unique(warnings), error = error)
}

coefficient_table_model_based <- function(model) {
  broom::tidy(model) |>
    transmute(
      term,
      estimate,
      std_error = std.error,
      statistic,
      p_value = p.value,
      irr = exp(estimate),
      conf_low = exp(estimate - 1.96 * std.error),
      conf_high = exp(estimate + 1.96 * std.error),
      se_type = "model_based"
    )
}

coefficient_table_cluster_robust <- function(model, data) {
  robust_warnings <- character()
  robust_error <- NULL

  robust_table <- tryCatch(
    withCallingHandlers(
      {
        robust_vcov <- sandwich::vcovCL(model, cluster = data$state)
        robust_test <- lmtest::coeftest(model, vcov. = robust_vcov)
        robust_df <- as.data.frame(unclass(robust_test))
        robust_df <- tibble::rownames_to_column(robust_df, "term")
        names(robust_df)[2:5] <- c("estimate", "robust_se", "statistic", "p_value")

        robust_df |>
          mutate(
            irr = exp(estimate),
            conf_low = exp(estimate - 1.96 * robust_se),
            conf_high = exp(estimate + 1.96 * robust_se),
            se_type = "cluster_robust_state"
          ) |>
          select(
            term,
            estimate,
            std_error = robust_se,
            statistic,
            p_value,
            irr,
            conf_low,
            conf_high,
            se_type
          )
      },
      warning = function(w) {
        robust_warnings <<- c(robust_warnings, conditionMessage(w))
        invokeRestart("muffleWarning")
      }
    ),
    error = function(e) {
      robust_error <<- conditionMessage(e)
      NULL
    }
  )

  list(
    table = robust_table,
    warnings = unique(robust_warnings),
    error = robust_error
  )
}

fit_full_model <- function(data, outcome, output_file, outcome_label) {
  formula_text <- paste0(
    outcome,
    " ~ rurality_quintile + svi_2022_per_0_1 + medicaid_expansion_active + ",
    "cvd_physicians_per_100k_2023 + medicare_ffs_hf_ihd_prevalence_2023 + ",
    "medicare_ffs_diabetes_prevalence_2023 + medicare_ffs_ckd_prevalence_2023 + ",
    "factor(year) + factor(quarter) + offset(log_medicaid_enrolment)"
  )

  message("Fitting fully adjusted NB model for ", outcome_label)

  fit_attempt <- fit_with_warnings(
    MASS::glm.nb(
      as.formula(formula_text),
      data = data,
      control = glm.control(maxit = 100)
    )
  )

  if (!is.null(fit_attempt$error)) {
    failure <- tibble(
      outcome = outcome_label,
      term = NA_character_,
      estimate = NA_real_,
      std_error = NA_real_,
      statistic = NA_real_,
      p_value = NA_real_,
      irr = NA_real_,
      conf_low = NA_real_,
      conf_high = NA_real_,
      se_type = "model_failed",
      model_status = "failed",
      model_error = fit_attempt$error,
      model_warnings = paste(fit_attempt$warnings, collapse = " | "),
      n_observations = NA_integer_,
      aic = NA_real_,
      theta = NA_real_,
      converged = NA
    )
    readr::write_csv(failure, path_out(output_file))
    return(list(
      outcome = outcome_label,
      model = NULL,
      table = failure,
      diagnostics = failure |>
        select(outcome, model_status, model_error, model_warnings, n_observations, aic, theta, converged)
    ))
  }

  model <- fit_attempt$result
  ordinary <- coefficient_table_model_based(model)
  robust_attempt <- coefficient_table_cluster_robust(model, data)

  preferred <- if (!is.null(robust_attempt$table)) {
    robust_attempt$table
  } else {
    warning(
      "Cluster-robust SE failed for ",
      outcome_label,
      ": ",
      robust_attempt$error,
      ". Falling back to model-based SE."
    )
    ordinary
  }

  output <- preferred |>
    mutate(
      outcome = outcome_label,
      model_status = "succeeded",
      model_error = NA_character_,
      model_warnings = paste(unique(c(fit_attempt$warnings, robust_attempt$warnings)), collapse = " | "),
      n_observations = stats::nobs(model),
      aic = stats::AIC(model),
      theta = model$theta,
      converged = isTRUE(model$converged)
    ) |>
    select(
      outcome,
      term,
      estimate,
      std_error,
      statistic,
      p_value,
      irr,
      conf_low,
      conf_high,
      se_type,
      model_status,
      model_error,
      model_warnings,
      n_observations,
      aic,
      theta,
      converged
    )

  readr::write_csv(output, path_out(output_file))

  list(
    outcome = outcome_label,
    model = model,
    table = output,
    diagnostics = output |>
      distinct(outcome, model_status, model_error, model_warnings, n_observations, aic, theta, converged, se_type)
  )
}

extract_key_terms <- function(model_output) {
  key_terms <- tibble::tribble(
    ~term, ~exposure, ~comparison_or_unit,
    "rurality_quintile1", "Rurality", "Q1 most rural vs Q5 most urban",
    "svi_2022_per_0_1", "SVI", "Per 0.1 increase",
    "medicaid_expansion_active", "Medicaid expansion", "Active vs not active",
    "cvd_physicians_per_100k_2023", "CVD physician density", "Per 1 CVD physician per 100k"
  )

  model_output$table |>
    inner_join(key_terms, by = "term") |>
    transmute(
      outcome,
      exposure,
      comparison_or_unit,
      term,
      irr,
      conf_low,
      conf_high,
      p_value,
      se_type,
      model_status
    )
}

# ------------------------------------------------------------
# 1. Build sensitivity-outcome master table
# ------------------------------------------------------------

print_section("1. Build sensitivity-outcome master table")

master <- read_clean_csv(input_files[["master"]], "master table") |>
  mutate(
    state = stringr::str_to_upper(state),
    year = as.integer(year),
    quarter = as.integer(quarter)
  )

required_master <- c(
  "state",
  "year",
  "quarter",
  "sglt2_prescriptions",
  "sglt2_units",
  "sglt2_prescriptions_per_10000",
  "medicaid_enrolment_quarter_avg",
  "rurality_quintile",
  "rucc_nonmetro_population_share_2023",
  "census_region",
  "svi_2022",
  "medicaid_expansion_active",
  "cvd_physicians_per_100k_2023",
  "medicare_ffs_hf_ihd_prevalence_2023",
  "medicare_ffs_diabetes_prevalence_2023",
  "medicare_ffs_ckd_prevalence_2023"
)

require_columns(master, required_master, "master table")

forbidden_denominator_cols <- intersect(
  c("medicaid_enrolment", "medicaid_enrolment_avg"),
  names(master)
)

if (length(forbidden_denominator_cols) > 0) {
  stop(
    "Master table must contain only `medicaid_enrolment_quarter_avg` as the Medicaid denominator. Remove: ",
    paste(forbidden_denominator_cols, collapse = ", "),
    call. = FALSE
  )
}

assert_no_duplicate_keys(master, c("state", "year", "quarter"), "master table")
assert_valid_states(master, "master table")

master_renamed <- master |>
  rename(
    sglt2_prescriptions_all_products = sglt2_prescriptions,
    sglt2_units_all_products = sglt2_units,
    sglt2_prescriptions_all_products_per_10000 = sglt2_prescriptions_per_10000
  )

single_agent <- make_sensitivity_outcome_table(
  input_files[["single_agent"]],
  "single_agent",
  "single-agent SGLT2 rates file"
)

empa_dapa <- make_sensitivity_outcome_table(
  input_files[["empa_dapa"]],
  "empa_dapa",
  "empagliflozin/dapagliflozin rates file"
)

updated_master <- master_renamed |>
  left_join(single_agent, by = c("state", "year", "quarter")) |>
  left_join(empa_dapa, by = c("state", "year", "quarter")) |>
  mutate(
    has_valid_medicaid_enrolment =
      !is.na(medicaid_enrolment_quarter_avg) & medicaid_enrolment_quarter_avg > 0,
    across(
      all_of(c(
        "sglt2_prescriptions_single_agent",
        "sglt2_units_single_agent",
        "sglt2_prescriptions_empa_dapa",
        "sglt2_units_empa_dapa"
      )),
      ~ if_else(has_valid_medicaid_enrolment & is.na(.x), 0, .x)
    ),
    sglt2_prescriptions_single_agent_per_10000 = if_else(
      has_valid_medicaid_enrolment,
      sglt2_prescriptions_single_agent / medicaid_enrolment_quarter_avg * 10000,
      NA_real_
    ),
    sglt2_prescriptions_empa_dapa_per_10000 = if_else(
      has_valid_medicaid_enrolment,
      sglt2_prescriptions_empa_dapa / medicaid_enrolment_quarter_avg * 10000,
      NA_real_
    )
  ) |>
  select(-has_valid_medicaid_enrolment)

assert_no_duplicate_keys(updated_master, c("state", "year", "quarter"), "updated sensitivity master table")

zero_fill_check <- updated_master |>
  summarise(
    missing_single_agent_rx = sum(is.na(sglt2_prescriptions_single_agent)),
    missing_single_agent_units = sum(is.na(sglt2_units_single_agent)),
    missing_empa_dapa_rx = sum(is.na(sglt2_prescriptions_empa_dapa)),
    missing_empa_dapa_units = sum(is.na(sglt2_units_empa_dapa)),
    missing_medicaid_enrolment = sum(is.na(medicaid_enrolment_quarter_avg)),
    missing_key_covariates = sum(is.na(pick(
      rurality_quintile,
      rucc_nonmetro_population_share_2023,
      census_region,
      svi_2022,
      medicaid_expansion_active,
      cvd_physicians_per_100k_2023,
      medicare_ffs_hf_ihd_prevalence_2023,
      medicare_ffs_diabetes_prevalence_2023,
      medicare_ffs_ckd_prevalence_2023
    )))
  )

message("Sensitivity outcome missingness after join and zero-fill:")
print(zero_fill_check, width = Inf)

updated_master_path <- path_in("master_state_quarter_sglt2_covariates_with_sensitivity_outcomes_poc.csv")
readr::write_csv(updated_master, updated_master_path)
message("Wrote updated sensitivity master table: ", updated_master_path)

# ------------------------------------------------------------
# 2. Fit only fully adjusted models
# ------------------------------------------------------------

print_section("2. Fit only fully adjusted models")

model_data <- updated_master |>
  filter(
    year != 2020,
    !(state %in% c("PR", "XX")),
    state %in% valid_50dc,
    !is.na(medicaid_enrolment_quarter_avg),
    medicaid_enrolment_quarter_avg > 0
  ) |>
  mutate(
    rurality_quintile = factor(rurality_quintile, levels = c(5, 4, 3, 2, 1)),
    svi_2022_per_0_1 = svi_2022 / 0.1,
    census_region = factor(
      census_region,
      levels = c("Northeast", "Midwest", "South", "West")
    ),
    log_medicaid_enrolment = log(medicaid_enrolment_quarter_avg)
  )

require_columns(
  model_data,
  c(
    "sglt2_prescriptions_all_products",
    "sglt2_prescriptions_single_agent",
    "sglt2_prescriptions_empa_dapa",
    "medicaid_enrolment_quarter_avg",
    "rucc_nonmetro_population_share_2023",
    "census_region",
    "sglt2_prescriptions_all_products_per_10000",
    "log_medicaid_enrolment"
  ),
  "sensitivity modelling data"
)

required_complete_cols <- c(
  "sglt2_prescriptions_all_products",
  "sglt2_prescriptions_single_agent",
  "sglt2_prescriptions_empa_dapa",
  "medicaid_enrolment_quarter_avg",
  "rurality_quintile",
  "rucc_nonmetro_population_share_2023",
  "census_region",
  "svi_2022",
  "medicaid_expansion_active",
  "cvd_physicians_per_100k_2023",
  "medicare_ffs_hf_ihd_prevalence_2023",
  "medicare_ffs_diabetes_prevalence_2023",
  "medicare_ffs_ckd_prevalence_2023"
)

missing_required_complete <- model_data |>
  summarise(
    across(
      all_of(required_complete_cols),
      ~ sum(is.na(.x))
    )
  ) |>
  pivot_longer(everything(), names_to = "variable", values_to = "n_missing") |>
  filter(n_missing > 0)

if (nrow(missing_required_complete) > 0) {
  message("Missing values in required sensitivity modelling variables:")
  print(missing_required_complete, n = Inf)
  stop("Required modelling variables must be complete; covariates and enrolment are not zero-filled.", call. = FALSE)
}

model_outputs <- list(
  all_products = fit_full_model(
    data = model_data,
    outcome = "sglt2_prescriptions_all_products",
    output_file = "sensitivity_full_model_all_products.csv",
    outcome_label = "All products"
  ),
  single_agent = fit_full_model(
    data = model_data,
    outcome = "sglt2_prescriptions_single_agent",
    output_file = "sensitivity_full_model_single_agent.csv",
    outcome_label = "Single-agent SGLT2 inhibitors"
  ),
  empa_dapa = fit_full_model(
    data = model_data,
    outcome = "sglt2_prescriptions_empa_dapa",
    output_file = "sensitivity_full_model_empa_dapa.csv",
    outcome_label = "Empagliflozin/dapagliflozin"
  )
)

key_results <- map_dfr(model_outputs, extract_key_terms) |>
  mutate(
    outcome = factor(
      outcome,
      levels = c("All products", "Single-agent SGLT2 inhibitors", "Empagliflozin/dapagliflozin")
    ),
    exposure = factor(
      exposure,
      levels = c("Rurality", "SVI", "Medicaid expansion", "CVD physician density")
    )
  ) |>
  arrange(outcome, exposure) |>
  tibble::as_tibble()

key_results_path <- path_out("sensitivity_outcome_comparison_key_results.csv")
readr::write_csv(key_results, key_results_path)
message("Wrote sensitivity key comparison table: ", key_results_path)

message("Sensitivity key results:")
print(key_results, n = Inf, width = Inf)

# ------------------------------------------------------------
# 3. Forest plot
# ------------------------------------------------------------

print_section("3. Forest plot")

plot_data <- key_results |>
  mutate(
    exposure_label = case_when(
      exposure == "Rurality" ~ "Q1 most rural vs Q5 most urban",
      exposure == "SVI" ~ "SVI per 0.1 increase",
      exposure == "Medicaid expansion" ~ "Medicaid expansion active",
      exposure == "CVD physician density" ~ "CVD physicians per 100k",
      TRUE ~ as.character(exposure)
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

forest_plot <- ggplot(
  plot_data,
  aes(x = irr, y = exposure_label, color = outcome)
) +
  geom_vline(xintercept = 1, linetype = "dashed", color = "grey45", linewidth = 0.5) +
  geom_errorbarh(
    aes(xmin = conf_low, xmax = conf_high),
    position = position_dodge(width = 0.55),
    height = 0.18,
    linewidth = 0.65
  ) +
  geom_point(position = position_dodge(width = 0.55), size = 2.4) +
  scale_x_log10(labels = scales::number_format(accuracy = 0.01)) +
  scale_color_brewer(palette = "Dark2", name = "Outcome") +
  labs(
    title = "Fully Adjusted IRRs Across SGLT2 Sensitivity Outcomes",
    x = "Incidence rate ratio, log scale",
    y = NULL
  ) +
  theme_minimal(base_size = 12) +
  theme(
    panel.grid.minor = element_blank(),
    legend.position = "bottom",
    plot.title = element_text(face = "bold")
  )

forest_plot_path <- plot_out("sensitivity_outcome_comparison_forest_plot.png")
ggsave(forest_plot_path, forest_plot, width = 9.5, height = 5.8, dpi = 300)
message("Wrote sensitivity forest plot: ", forest_plot_path)

# ------------------------------------------------------------
# 4. Append modelling log section
# ------------------------------------------------------------

print_section("4. Append modelling log")

log_path <- doc_out("2026-05-03_modelling_poc_log.md")

key_results_md <- capture.output(
  key_results |>
    mutate(
      irr = round(irr, 3),
      conf_low = round(conf_low, 3),
      conf_high = round(conf_high, 3),
      p_value = signif(p_value, 3)
    ) |>
    print(n = Inf, width = Inf)
)

diagnostics_md <- capture.output(
  map_dfr(model_outputs, "diagnostics") |>
    tibble::as_tibble() |>
    print(n = Inf, width = Inf)
)

section_title <- "## Sensitivity analyses using single-agent and empagliflozin/dapagliflozin outcomes"

existing_log <- if (file.exists(log_path)) readLines(log_path, warn = FALSE) else character()
if (any(existing_log == section_title)) {
  first_idx <- which(existing_log == section_title)[1]
  existing_log <- existing_log[seq_len(first_idx - 1)]
}

log_section <- c(
  "",
  section_title,
  "",
  "A narrow sensitivity workflow joined single-agent SGLT2 and empagliflozin/dapagliflozin state-quarter prescribing outcomes onto the existing master table by `state`, `year`, and `quarter`.",
  "",
  paste0("- Updated sensitivity master table: `for_analysis/", basename(updated_master_path), "`."),
  "- Existing all-product outcome columns were renamed in the updated master table to `sglt2_prescriptions_all_products`, `sglt2_units_all_products`, and `sglt2_prescriptions_all_products_per_10000`.",
  "- Missing sensitivity prescribing and unit counts after the join were set to 0 only when valid Medicaid enrolment was present.",
  "- Sensitivity prescribing rates per 10,000 were recalculated using the master-table `medicaid_enrolment_quarter_avg` denominator.",
  "- Medicaid enrolment and covariates were not zero-filled.",
  "- Only the fully adjusted negative binomial model was fit for each outcome; the staged model sequence was not rerun for sensitivity outcomes.",
  "- Q5 most urban remained the rurality reference group, and SVI was scaled per 0.1 increase.",
  "- State-clustered robust standard errors were used when available.",
  "",
  "Key sensitivity results:",
  "",
  "```",
  key_results_md,
  "```",
  "",
  "Model diagnostics:",
  "",
  "```",
  diagnostics_md,
  "```",
  "",
  "Sensitivity outputs:",
  "",
  "- `for_analysis/model_outputs/sensitivity_full_model_all_products.csv`",
  "- `for_analysis/model_outputs/sensitivity_full_model_single_agent.csv`",
  "- `for_analysis/model_outputs/sensitivity_full_model_empa_dapa.csv`",
  "- `for_analysis/model_outputs/sensitivity_outcome_comparison_key_results.csv`",
  "- `for_analysis/model_outputs/plots/sensitivity_outcome_comparison_forest_plot.png`"
)

writeLines(c(existing_log, log_section), log_path)
message("Updated modelling log: ", log_path)

print_section("Complete")
message("Rows analysed: ", nrow(model_data))
message("States: ", n_distinct(model_data$state))
message("Updated master table: ", updated_master_path)
message("Key comparison table: ", key_results_path)
message("Forest plot: ", forest_plot_path)
