# Region-adjusted sensitivity model for Medicaid SGLT2 prescribing.

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

input_master_file <- "master_state_quarter_sglt2_covariates_with_sensitivity_outcomes_poc.csv"

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
    dplyr::count(dplyr::across(dplyr::all_of(keys)), name = "n") |>
    dplyr::filter(n > 1)

  if (nrow(duplicate_rows) > 0) {
    message("Duplicate key rows in ", data_label, ":")
    print(duplicate_rows, n = Inf)
    stop(data_label, " contains duplicate key rows.", call. = FALSE)
  }

  invisible(data)
}

assert_valid_states <- function(data, data_label) {
  invalid <- setdiff(unique(data$state), valid_50dc)
  missing <- setdiff(valid_50dc, unique(data$state))

  if (length(invalid) > 0) {
    stop(
      data_label,
      " contains state codes outside 50 states + DC: ",
      paste(sort(invalid), collapse = ", "),
      call. = FALSE
    )
  }

  if (length(missing) > 0) {
    stop(
      data_label,
      " is missing state codes: ",
      paste(sort(missing), collapse = ", "),
      call. = FALSE
    )
  }

  invisible(data)
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

model_based_table <- function(model) {
  broom::tidy(model) |>
    dplyr::transmute(
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

robust_table <- function(model, data) {
  robust_warnings <- character()
  robust_error <- NULL

  table <- tryCatch(
    withCallingHandlers(
      {
        robust_vcov <- sandwich::vcovCL(model, cluster = data$state)
        robust_test <- lmtest::coeftest(model, vcov. = robust_vcov)
        robust_df <- as.data.frame(unclass(robust_test))
        robust_df <- tibble::rownames_to_column(robust_df, "term")
        names(robust_df)[2:5] <- c("estimate", "std_error", "statistic", "p_value")

        robust_df |>
          dplyr::mutate(
            irr = exp(estimate),
            conf_low = exp(estimate - 1.96 * std_error),
            conf_high = exp(estimate + 1.96 * std_error),
            se_type = "cluster_robust_state"
          ) |>
          dplyr::select(term, estimate, std_error, statistic, p_value, irr, conf_low, conf_high, se_type)
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

  list(table = table, warnings = unique(robust_warnings), error = robust_error)
}

fit_region_adjusted_model <- function(data, outcome, outcome_label) {
  formula_text <- paste0(
    outcome,
    " ~ rurality_quintile + svi_2022_per_0_1 + medicaid_expansion_active + ",
    "census_region + cvd_physicians_per_100k_2023 + ",
    "medicare_ffs_hf_ihd_prevalence_2023 + medicare_ffs_diabetes_prevalence_2023 + ",
    "medicare_ffs_ckd_prevalence_2023 + factor(year) + factor(quarter) + ",
    "offset(log_medicaid_enrolment)"
  )

  message("Fitting region-adjusted model for ", outcome_label)

  fit_attempt <- fit_with_warnings(
    MASS::glm.nb(
      as.formula(formula_text),
      data = data,
      control = glm.control(maxit = 100)
    )
  )

  if (!is.null(fit_attempt$error)) {
    failure <- tibble::tibble(
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

    return(list(
      model = NULL,
      ordinary = failure,
      robust = failure,
      preferred = failure,
      diagnostics = failure |>
        dplyr::distinct(outcome, model_status, model_error, model_warnings, n_observations, aic, theta, converged, se_type),
      warnings = fit_attempt$warnings,
      error = fit_attempt$error
    ))
  }

  model <- fit_attempt$result
  ordinary <- model_based_table(model)
  robust_attempt <- robust_table(model, data)
  preferred <- if (!is.null(robust_attempt$table)) robust_attempt$table else ordinary
  se_status <- if (!is.null(robust_attempt$table)) "cluster_robust_state" else "model_based_fallback"

  add_model_meta <- function(tbl) {
    tbl |>
      dplyr::mutate(
        outcome = outcome_label,
        model_status = "succeeded",
        model_error = NA_character_,
        model_warnings = paste(unique(c(fit_attempt$warnings, robust_attempt$warnings)), collapse = " | "),
        n_observations = stats::nobs(model),
        aic = stats::AIC(model),
        theta = model$theta,
        converged = isTRUE(model$converged)
      ) |>
      dplyr::select(
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
  }

  list(
    model = model,
    ordinary = add_model_meta(ordinary),
    robust = if (!is.null(robust_attempt$table)) add_model_meta(robust_attempt$table) else NULL,
    preferred = add_model_meta(preferred),
    diagnostics = tibble::tibble(
      outcome = outcome_label,
      model_status = "succeeded",
      model_error = NA_character_,
      model_warnings = paste(unique(c(fit_attempt$warnings, robust_attempt$warnings)), collapse = " | "),
      n_observations = stats::nobs(model),
      aic = stats::AIC(model),
      theta = model$theta,
      converged = isTRUE(model$converged),
      se_type = se_status,
      formula = formula_text
    ),
    warnings = unique(c(fit_attempt$warnings, robust_attempt$warnings)),
    error = robust_attempt$error
  )
}

key_term_lookup <- tibble::tribble(
  ~term, ~exposure, ~comparison_or_unit, ~interpretation,
  "rurality_quintile1", "Rurality", "Q1 most rural vs Q5 most urban", "Q5 most urban is the reference; IRR < 1 indicates lower prescribing than Q5.",
  "rurality_quintile2", "Rurality", "Q2 vs Q5", "Q5 most urban is the reference; IRR < 1 indicates lower prescribing than Q5.",
  "rurality_quintile3", "Rurality", "Q3 vs Q5", "Q5 most urban is the reference; IRR < 1 indicates lower prescribing than Q5.",
  "rurality_quintile4", "Rurality", "Q4 vs Q5", "Q5 most urban is the reference; IRR < 1 indicates lower prescribing than Q5.",
  "svi_2022_per_0_1", "SVI", "Per 0.1 increase", "IRR corresponds to each 0.1 higher state-level SVI.",
  "medicaid_expansion_active", "Medicaid expansion", "Active vs not active", "IRR compares active Medicaid expansion state-quarters with non-active state-quarters.",
  "cvd_physicians_per_100k_2023", "CVD physician density", "Per 1 CVD physician per 100k", "IRR corresponds to each additional CVD physician per 100,000 population."
)

extract_key_results <- function(preferred_table) {
  region_lookup <- preferred_table |>
    dplyr::filter(stringr::str_starts(term, "census_region")) |>
    dplyr::transmute(
      term,
      exposure = "Census region",
      comparison_or_unit = paste0(stringr::str_remove(term, "^census_region"), " vs Northeast"),
      interpretation = "Northeast is the Census region reference group."
    )

  dplyr::bind_rows(key_term_lookup, region_lookup) |>
    dplyr::inner_join(preferred_table, by = "term") |>
    dplyr::transmute(
      term,
      exposure,
      comparison_or_unit,
      irr,
      conf_low,
      conf_high,
      p_value,
      interpretation
    )
}

read_original_full_model <- function() {
  candidates <- c(
    path_out("model_6_full_covariate_cluster_robust_coefficients.csv"),
    path_out("model_6_full_covariate_robust_coefficients.csv"),
    path_out("model_6_full_covariate_coefficients.csv")
  )

  original_path <- candidates[file.exists(candidates)][1]
  if (is.na(original_path)) {
    return(NULL)
  }

  readr::read_csv(original_path, show_col_types = FALSE) |>
    janitor::clean_names() |>
    dplyr::mutate(source_file = basename(original_path))
}

format_ci <- function(irr, low, high) {
  ifelse(
    is.na(irr) | is.na(low) | is.na(high),
    NA_character_,
    paste0(round(irr, 3), " (", round(low, 3), "-", round(high, 3), ")")
  )
}

# ------------------------------------------------------------
# Step 1. Validate Census region/division
# ------------------------------------------------------------

print_section("Step 1. Validate Census region/division")

message("Using input master: ", path_in(input_master_file))

if (!file.exists(path_in(input_master_file))) {
  stop(
    "Missing input master: ",
    path_in(input_master_file),
    ". Run scripts/07_sensitivity_outcomes_full_model_poc.R before this script.",
    call. = FALSE
  )
}

census_lookup <- tibble::tribble(
  ~state, ~census_region, ~census_division,
  "CT", "Northeast", "New England",
  "ME", "Northeast", "New England",
  "MA", "Northeast", "New England",
  "NH", "Northeast", "New England",
  "RI", "Northeast", "New England",
  "VT", "Northeast", "New England",
  "NJ", "Northeast", "Middle Atlantic",
  "NY", "Northeast", "Middle Atlantic",
  "PA", "Northeast", "Middle Atlantic",
  "IL", "Midwest", "East North Central",
  "IN", "Midwest", "East North Central",
  "MI", "Midwest", "East North Central",
  "OH", "Midwest", "East North Central",
  "WI", "Midwest", "East North Central",
  "IA", "Midwest", "West North Central",
  "KS", "Midwest", "West North Central",
  "MN", "Midwest", "West North Central",
  "MO", "Midwest", "West North Central",
  "NE", "Midwest", "West North Central",
  "ND", "Midwest", "West North Central",
  "SD", "Midwest", "West North Central",
  "DE", "South", "South Atlantic",
  "DC", "South", "South Atlantic",
  "FL", "South", "South Atlantic",
  "GA", "South", "South Atlantic",
  "MD", "South", "South Atlantic",
  "NC", "South", "South Atlantic",
  "SC", "South", "South Atlantic",
  "VA", "South", "South Atlantic",
  "WV", "South", "South Atlantic",
  "AL", "South", "East South Central",
  "KY", "South", "East South Central",
  "MS", "South", "East South Central",
  "TN", "South", "East South Central",
  "AR", "South", "West South Central",
  "LA", "South", "West South Central",
  "OK", "South", "West South Central",
  "TX", "South", "West South Central",
  "AZ", "West", "Mountain",
  "CO", "West", "Mountain",
  "ID", "West", "Mountain",
  "MT", "West", "Mountain",
  "NV", "West", "Mountain",
  "NM", "West", "Mountain",
  "UT", "West", "Mountain",
  "WY", "West", "Mountain",
  "AK", "West", "Pacific",
  "CA", "West", "Pacific",
  "HI", "West", "Pacific",
  "OR", "West", "Pacific",
  "WA", "West", "Pacific"
) |>
  dplyr::mutate(
    census_region = factor(census_region, levels = c("Northeast", "Midwest", "South", "West")),
    census_division = factor(
      census_division,
      levels = c(
        "New England",
        "Middle Atlantic",
        "East North Central",
        "West North Central",
        "South Atlantic",
        "East South Central",
        "West South Central",
        "Mountain",
        "Pacific"
      )
    )
  )

master <- readr::read_csv(path_in(input_master_file), show_col_types = FALSE) |>
  janitor::clean_names() |>
  dplyr::mutate(
    state = stringr::str_to_upper(state),
    year = as.integer(year),
    quarter = as.integer(quarter)
  )

require_columns(
  master,
  c("state", "year", "quarter", "census_region", "census_division"),
  "input master"
)
assert_no_duplicate_keys(master, c("state", "year", "quarter"), "input master")
assert_valid_states(master, "input master")

region_check <- master |>
  dplyr::distinct(state, census_region, census_division) |>
  dplyr::left_join(
    census_lookup |>
      dplyr::rename(
        expected_census_region = census_region,
        expected_census_division = census_division
      ),
    by = "state"
  ) |>
  dplyr::filter(
    is.na(expected_census_region) |
      as.character(census_region) != as.character(expected_census_region) |
      as.character(census_division) != as.character(expected_census_division)
  )

if (nrow(region_check) > 0) {
  message("Census region/division values that do not match the planned lookup:")
  print(region_check, n = Inf)
  stop("Input master has missing or unexpected Census region/division values.", call. = FALSE)
}

updated_master <- master |>
  dplyr::mutate(
    census_region = factor(
      census_region,
      levels = c("Northeast", "Midwest", "South", "West")
    ),
    census_division = factor(
      census_division,
      levels = levels(census_lookup$census_division)
    )
  )

if (any(updated_master$state %in% c("PR", "XX"))) {
  stop("PR or XX found in input master.", call. = FALSE)
}

assert_no_duplicate_keys(updated_master, c("state", "year", "quarter"), "region-augmented master")
assert_valid_states(updated_master, "region-augmented master")

region_master_path <- path_in("master_state_quarter_sglt2_covariates_with_region_poc.csv")
readr::write_csv(updated_master, region_master_path)
message("Wrote validated region master copy: ", region_master_path)

message("Census region/division state counts:")
print(
  updated_master |>
    dplyr::distinct(state, census_region, census_division) |>
    dplyr::count(census_region, census_division, name = "n_states"),
  n = Inf
)

# ------------------------------------------------------------
# Step 2. Prepare modelling data
# ------------------------------------------------------------

print_section("Step 2. Prepare modelling data")

outcome <- if ("sglt2_prescriptions_all_products" %in% names(updated_master)) {
  "sglt2_prescriptions_all_products"
} else {
  stop(
    "Region-adjusted sensitivity script requires `sglt2_prescriptions_all_products`. ",
    "Run script 07 first to create the sensitivity-outcome master table.",
    call. = FALSE
  )
}

forbidden_denominator_cols <- intersect(
  c("medicaid_enrolment", "medicaid_enrolment_avg"),
  names(updated_master)
)

if (length(forbidden_denominator_cols) > 0) {
  stop(
    "Region-augmented master must contain only `medicaid_enrolment_quarter_avg` as the Medicaid denominator. Remove: ",
    paste(forbidden_denominator_cols, collapse = ", "),
    call. = FALSE
  )
}

required_model_cols <- c(
  outcome,
  "medicaid_enrolment_quarter_avg",
  "sglt2_prescriptions_all_products_per_10000",
  "rurality_quintile",
  "rucc_nonmetro_population_share_2023",
  "svi_2022",
  "medicaid_expansion_active",
  "census_region",
  "cvd_physicians_per_100k_2023",
  "medicare_ffs_hf_ihd_prevalence_2023",
  "medicare_ffs_diabetes_prevalence_2023",
  "medicare_ffs_ckd_prevalence_2023"
)
require_columns(updated_master, required_model_cols, "region-augmented master")

model_data <- updated_master |>
  dplyr::filter(
    year != 2020,
    state %in% valid_50dc,
    !is.na(medicaid_enrolment_quarter_avg),
    medicaid_enrolment_quarter_avg > 0
  ) |>
  dplyr::mutate(
    "{outcome}" := dplyr::if_else(is.na(.data[[outcome]]), 0, .data[[outcome]]),
    rurality_quintile = factor(rurality_quintile, levels = c(5, 4, 3, 2, 1)),
    census_region = factor(census_region, levels = c("Northeast", "Midwest", "South", "West")),
    census_division = factor(census_division),
    svi_2022_per_0_1 = dplyr::if_else(is.na(svi_2022), NA_real_, svi_2022 / 0.1),
    log_medicaid_enrolment = log(medicaid_enrolment_quarter_avg)
  )

if ("sglt2_prescriptions_single_agent" %in% names(model_data)) {
  model_data <- model_data |>
    dplyr::mutate(
      sglt2_prescriptions_single_agent = dplyr::if_else(
        is.na(sglt2_prescriptions_single_agent),
        0,
        sglt2_prescriptions_single_agent
      )
    )
}

if ("sglt2_prescriptions_empa_dapa" %in% names(model_data)) {
  model_data <- model_data |>
    dplyr::mutate(
      sglt2_prescriptions_empa_dapa = dplyr::if_else(
        is.na(sglt2_prescriptions_empa_dapa),
        0,
        sglt2_prescriptions_empa_dapa
      )
    )
}

missing_model_covariates <- model_data |>
  dplyr::summarise(
    dplyr::across(
      dplyr::all_of(setdiff(required_model_cols, c(outcome, "medicaid_enrolment_quarter_avg"))),
      ~ sum(is.na(.x))
    )
  ) |>
  tidyr::pivot_longer(dplyr::everything(), names_to = "variable", values_to = "n_missing") |>
  dplyr::filter(n_missing > 0)

if (nrow(missing_model_covariates) > 0) {
  message("Missing covariates in modelling data:")
  print(missing_model_covariates, n = Inf)
  stop("Region-adjusted model requires complete covariates; missing covariates are not zero-filled.", call. = FALSE)
}

message("Primary outcome: ", outcome)
message("Medicaid enrolment denominator: medicaid_enrolment_quarter_avg")
message("Rows for model: ", nrow(model_data))
message("States for model: ", dplyr::n_distinct(model_data$state))

# ------------------------------------------------------------
# Step 3. Run region-adjusted full model
# ------------------------------------------------------------

print_section("Step 3. Run region-adjusted full model")

primary_result <- fit_region_adjusted_model(
  data = model_data,
  outcome = outcome,
  outcome_label = "All products"
)

readr::write_csv(primary_result$ordinary, path_out("region_adjusted_full_model_coefficients.csv"))
readr::write_csv(
  if (!is.null(primary_result$robust)) primary_result$robust else primary_result$preferred,
  path_out("region_adjusted_full_model_robust_coefficients.csv")
)

primary_key <- extract_key_results(primary_result$preferred)
readr::write_csv(primary_key, path_out("region_adjusted_key_results.csv"))

message("Region-adjusted key results:")
print(primary_key, n = Inf, width = Inf)

# ------------------------------------------------------------
# Step 4. Compare with current full model
# ------------------------------------------------------------

print_section("Step 4. Compare with current full model")

original_full <- read_original_full_model()

compare_terms <- tibble::tribble(
  ~term, ~exposure,
  "rurality_quintile1", "Q1 most rural vs Q5 most urban",
  "svi_2022_per_0_1", "SVI per 0.1 increase",
  "medicaid_expansion_active", "Medicaid expansion active",
  "cvd_physicians_per_100k_2023", "CVD physicians per 100k"
)

if (is.null(original_full)) {
  comparison <- compare_terms |>
    dplyr::mutate(
      original_full_model_irr = NA_real_,
      original_full_model_ci = NA_character_,
      region_adjusted_model_irr = NA_real_,
      region_adjusted_model_ci = NA_character_,
      interpretation_change = "Original full model output not found."
    )
} else {
  original_compare <- original_full |>
    dplyr::inner_join(compare_terms, by = "term") |>
    dplyr::transmute(
      exposure,
      original_full_model_irr = irr,
      original_full_model_ci = format_ci(irr, conf_low, conf_high)
    )

  region_compare <- primary_key |>
    dplyr::inner_join(
      compare_terms |> dplyr::rename(exposure_label = exposure),
      by = "term"
    ) |>
    dplyr::transmute(
      exposure = exposure_label,
      region_adjusted_model_irr = irr,
      region_adjusted_model_ci = format_ci(irr, conf_low, conf_high)
    )

  comparison <- compare_terms |>
    dplyr::select(exposure) |>
    dplyr::left_join(original_compare, by = "exposure") |>
    dplyr::left_join(region_compare, by = "exposure") |>
    dplyr::mutate(
      interpretation_change = dplyr::case_when(
        is.na(original_full_model_irr) | is.na(region_adjusted_model_irr) ~ "Unable to compare.",
        abs(log(region_adjusted_model_irr) - log(original_full_model_irr)) < log(1.10) ~ "Little material change in point estimate.",
        region_adjusted_model_irr < original_full_model_irr ~ "Region adjustment moved the point estimate downward.",
        region_adjusted_model_irr > original_full_model_irr ~ "Region adjustment moved the point estimate upward.",
        TRUE ~ "No clear change."
      )
    )
}

comparison_path <- path_out("region_adjusted_vs_original_key_results.csv")
readr::write_csv(comparison, comparison_path)

message("Original vs region-adjusted comparison:")
print(comparison, n = Inf, width = Inf)

# ------------------------------------------------------------
# Step 5. Optional sensitivity outcomes
# ------------------------------------------------------------

print_section("Step 5. Optional sensitivity outcomes")

sensitivity_results <- list()

if ("sglt2_prescriptions_single_agent" %in% names(model_data)) {
  sensitivity_results$single_agent <- fit_region_adjusted_model(
    data = model_data,
    outcome = "sglt2_prescriptions_single_agent",
    outcome_label = "Single-agent SGLT2 inhibitors"
  )
  readr::write_csv(
    sensitivity_results$single_agent$preferred,
    path_out("region_adjusted_single_agent_coefficients.csv")
  )
}

if ("sglt2_prescriptions_empa_dapa" %in% names(model_data)) {
  sensitivity_results$empa_dapa <- fit_region_adjusted_model(
    data = model_data,
    outcome = "sglt2_prescriptions_empa_dapa",
    outcome_label = "Empagliflozin/dapagliflozin"
  )
  readr::write_csv(
    sensitivity_results$empa_dapa$preferred,
    path_out("region_adjusted_empa_dapa_coefficients.csv")
  )
}

if (length(sensitivity_results) > 0) {
  sensitivity_comparison <- dplyr::bind_rows(
    extract_key_results(primary_result$preferred) |> dplyr::mutate(outcome = "All products"),
    purrr::map_dfr(
      sensitivity_results,
      ~ extract_key_results(.x$preferred) |> dplyr::mutate(outcome = .x$preferred$outcome[1])
    )
  ) |>
    dplyr::select(outcome, dplyr::everything())

  readr::write_csv(
    sensitivity_comparison,
    path_out("region_adjusted_sensitivity_outcome_comparison.csv")
  )
} else {
  sensitivity_comparison <- tibble::tibble(
    note = "Sensitivity outcome columns were not present, so no sensitivity outcome region-adjusted models were fit."
  )
  readr::write_csv(
    sensitivity_comparison,
    path_out("region_adjusted_sensitivity_outcome_comparison.csv")
  )
}

# ------------------------------------------------------------
# Step 6. Forest plot
# ------------------------------------------------------------

print_section("Step 6. Forest plot")

forest_terms <- primary_result$preferred |>
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
      term == "medicare_ffs_hf_ihd_prevalence_2023" ~ "Medicare FFS HF/IHD prevalence",
      term == "medicare_ffs_diabetes_prevalence_2023" ~ "Medicare FFS diabetes prevalence",
      term == "medicare_ffs_ckd_prevalence_2023" ~ "Medicare FFS CKD prevalence",
      stringr::str_starts(term, "census_region") ~ paste0(stringr::str_remove(term, "^census_region"), " region vs Northeast"),
      TRUE ~ term
    ),
    label = factor(label, levels = rev(label))
  )

forest_plot <- ggplot(forest_terms, aes(x = irr, y = label)) +
  geom_vline(xintercept = 1, linetype = "dashed", color = "grey45", linewidth = 0.5) +
  geom_segment(aes(x = conf_low, xend = conf_high, yend = label), linewidth = 0.7, color = "#2f5f8f") +
  geom_point(size = 2.5, color = "#123b5d") +
  scale_x_log10(labels = scales::number_format(accuracy = 0.01)) +
  labs(
    title = "Region-Adjusted Fully Adjusted Model IRRs",
    x = "Incidence rate ratio, log scale",
    y = NULL
  ) +
  theme_minimal(base_size = 12) +
  theme(
    panel.grid.minor = element_blank(),
    plot.title = element_text(face = "bold"),
    axis.text.y = element_text(size = 10)
  )

forest_plot_path <- plot_out("region_adjusted_full_model_forest_plot.png")
ggsave(forest_plot_path, forest_plot, width = 10, height = 7.3, dpi = 300)
message("Wrote forest plot: ", forest_plot_path)

# ------------------------------------------------------------
# Step 7. Append modelling log
# ------------------------------------------------------------

print_section("Step 7. Append modelling log")

log_path <- doc_out("2026-05-03_modelling_poc_log.md")

key_md <- capture.output(
  primary_key |>
    dplyr::mutate(
      irr = round(irr, 3),
      conf_low = round(conf_low, 3),
      conf_high = round(conf_high, 3),
      p_value = signif(p_value, 3)
    ) |>
    print(n = Inf, width = Inf)
)

comparison_md <- capture.output(
  comparison |>
    print(n = Inf, width = Inf)
)

diagnostics <- dplyr::bind_rows(
  primary_result$diagnostics,
  purrr::map_dfr(sensitivity_results, "diagnostics")
)

diagnostics_md <- capture.output(
  diagnostics |>
    print(n = Inf, width = Inf)
)

model_region_q1 <- primary_key |> dplyr::filter(term == "rurality_quintile1") |> dplyr::slice(1)
model_svi <- primary_key |> dplyr::filter(term == "svi_2022_per_0_1") |> dplyr::slice(1)
model_expansion <- primary_key |> dplyr::filter(term == "medicaid_expansion_active") |> dplyr::slice(1)

svi_sentence <- if (nrow(model_svi) == 1 && !is.na(model_svi$p_value)) {
  if (model_svi$p_value < 0.05) {
    paste0("SVI remained statistically significant in the region-adjusted model: IRR ", round(model_svi$irr, 3), " (95% CI ", round(model_svi$conf_low, 3), "-", round(model_svi$conf_high, 3), ").")
  } else {
    paste0("SVI was not statistically significant in the region-adjusted model: IRR ", round(model_svi$irr, 3), " (95% CI ", round(model_svi$conf_low, 3), "-", round(model_svi$conf_high, 3), ").")
  }
} else {
  "SVI result was unavailable in the region-adjusted model."
}

rurality_sentence <- if (nrow(model_region_q1) == 1) {
  paste0("The Q1 most rural vs Q5 most urban estimate in the region-adjusted model was IRR ", round(model_region_q1$irr, 3), " (95% CI ", round(model_region_q1$conf_low, 3), "-", round(model_region_q1$conf_high, 3), ").")
} else {
  "The Q1 rurality result was unavailable in the region-adjusted model."
}

expansion_sentence <- if (nrow(model_expansion) == 1) {
  paste0("The Medicaid expansion estimate in the region-adjusted model was IRR ", round(model_expansion$irr, 3), " (95% CI ", round(model_expansion$conf_low, 3), "-", round(model_expansion$conf_high, 3), ").")
} else {
  "The Medicaid expansion result was unavailable in the region-adjusted model."
}

region_match_sentence <- paste0(
  "All ",
  dplyr::n_distinct(updated_master$state),
  " states/DC matched to Census region and division; no PR or XX rows were present."
)

section_title <- "## Region-adjusted sensitivity analysis"

existing_log <- if (file.exists(log_path)) readLines(log_path, warn = FALSE) else character()
if (any(existing_log == section_title)) {
  first_idx <- which(existing_log == section_title)[1]
  existing_log <- existing_log[seq_len(first_idx - 1)]
}

log_section <- c(
  "",
  section_title,
  "",
  "Census region was used as a geographic sensitivity adjustment to assess whether the rurality and SVI associations were partly explained by broad regional differences in Medicaid policy environment, prescribing norms, or access patterns.",
  "",
  "- Source/mapping: standard U.S. Census Bureau four-region and nine-division classification. The input master table is required to contain matching `census_region` and `census_division` values.",
  paste0("- Input master table: `for_analysis/", input_master_file, "`."),
  "- Validated region master table copy: `for_analysis/master_state_quarter_sglt2_covariates_with_region_poc.csv`.",
  paste0("- ", region_match_sentence),
  "- The model used the same fully adjusted negative binomial specification as Model 6, with Census region added and Northeast as the region reference.",
  "- The staged modelling sequence was not rerun.",
  "",
  "Key findings:",
  "",
  paste0("- ", svi_sentence),
  paste0("- ", rurality_sentence),
  paste0("- ", expansion_sentence),
  "",
  "Original vs region-adjusted comparison:",
  "",
  "```",
  comparison_md,
  "```",
  "",
  "Region-adjusted key results:",
  "",
  "```",
  key_md,
  "```",
  "",
  "Convergence and missingness:",
  "",
  "```",
  diagnostics_md,
  "```",
  "",
  "Outputs:",
  "",
  "- `for_analysis/model_outputs/region_adjusted_full_model_coefficients.csv`",
  "- `for_analysis/model_outputs/region_adjusted_full_model_robust_coefficients.csv`",
  "- `for_analysis/model_outputs/region_adjusted_key_results.csv`",
  "- `for_analysis/model_outputs/region_adjusted_vs_original_key_results.csv`",
  "- `for_analysis/model_outputs/region_adjusted_sensitivity_outcome_comparison.csv`",
  "- `for_analysis/model_outputs/plots/region_adjusted_full_model_forest_plot.png`"
)

writeLines(c(existing_log, log_section), log_path)
message("Updated modelling log: ", log_path)

print_section("Complete")
message("Rows analysed: ", nrow(model_data))
message("States: ", dplyr::n_distinct(model_data$state))
message("Region master table: ", region_master_path)
message("Region-adjusted key results: ", path_out("region_adjusted_key_results.csv"))
message("Original comparison: ", comparison_path)
message("Forest plot: ", forest_plot_path)
