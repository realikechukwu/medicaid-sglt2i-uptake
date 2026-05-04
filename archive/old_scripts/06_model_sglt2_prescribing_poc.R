# Proof-of-concept modelling for Medicaid SGLT2 prescribing.

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

input_file <- "master_state_quarter_sglt2_covariates_poc.csv"

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

`%||%` <- function(x, y) {
  if (is.null(x) || length(x) == 0) y else x
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

fmt_num <- function(x, digits = 3) {
  ifelse(is.na(x), "NA", format(round(x, digits), nsmall = digits, trim = TRUE))
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

standard_coefficient_table <- function(model) {
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

cluster_robust_coefficient_table <- function(model, data) {
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
          dplyr::mutate(
            irr = exp(estimate),
            conf_low = exp(estimate - 1.96 * robust_se),
            conf_high = exp(estimate + 1.96 * robust_se),
            se_type = "cluster_robust_state"
          ) |>
          dplyr::select(
            term,
            estimate,
            robust_se,
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

write_model_summary <- function(model, spec, summary_path, fit_warnings, robust_status, robust_error) {
  summary_lines <- capture.output({
    cat(spec$model_name, "\n")
    cat("Purpose: ", spec$purpose, "\n", sep = "")
    cat("Formula: ", paste(deparse(spec$formula), collapse = " "), "\n", sep = "")
    cat("Data rows supplied: ", nrow(spec$data), "\n", sep = "")
    cat("Model warnings: ", ifelse(length(fit_warnings) == 0, "None", paste(fit_warnings, collapse = " | ")), "\n", sep = "")
    cat("Cluster-robust SE status: ", robust_status, "\n", sep = "")
    if (!is.na(robust_error) && nzchar(robust_error)) {
      cat("Cluster-robust SE error: ", robust_error, "\n", sep = "")
    }
    cat("\n")
    print(summary(model))
  })

  writeLines(summary_lines, summary_path)
}

fit_and_save_nb_model <- function(spec) {
  coefficient_path <- path_out(spec$coefficient_file)
  robust_path <- path_out(stringr::str_replace(
    spec$coefficient_file,
    "_coefficients\\.csv$",
    "_cluster_robust_coefficients.csv"
  ))
  summary_path <- path_out(stringr::str_replace(
    spec$coefficient_file,
    "_coefficients\\.csv$",
    "_summary.txt"
  ))

  message("Fitting ", spec$model_name)

  fit_attempt <- fit_with_warnings(
    MASS::glm.nb(
      formula = spec$formula,
      data = spec$data,
      control = glm.control(maxit = 100)
    )
  )

  if (!is.null(fit_attempt$error)) {
    failure_table <- tibble(
      model_id = spec$model_id,
      model_name = spec$model_name,
      status = "failed",
      error = fit_attempt$error
    )
    readr::write_csv(failure_table, coefficient_path)
    readr::write_csv(
      tibble(
        model_id = spec$model_id,
        model_name = spec$model_name,
        status = "not_attempted_model_failed",
        error = fit_attempt$error
      ),
      robust_path
    )
    writeLines(
      c(
        spec$model_name,
        paste0("Purpose: ", spec$purpose),
        paste0("Formula: ", paste(deparse(spec$formula), collapse = " ")),
        paste0("Model failed: ", fit_attempt$error),
        paste0(
          "Warnings: ",
          ifelse(length(fit_attempt$warnings) == 0, "None", paste(fit_attempt$warnings, collapse = " | "))
        )
      ),
      summary_path
    )

    diagnostics <- tibble(
      model_id = spec$model_id,
      model_name = spec$model_name,
      status = "failed",
      n_observations = NA_integer_,
      aic = NA_real_,
      residual_deviance = NA_real_,
      residual_df = NA_real_,
      theta = NA_real_,
      converged = NA,
      robust_se_status = "not_attempted_model_failed",
      warnings = paste(fit_attempt$warnings, collapse = " | "),
      error = fit_attempt$error,
      formula = paste(deparse(spec$formula), collapse = " ")
    )

    return(list(
      spec = spec,
      model = NULL,
      ordinary = failure_table,
      robust = NULL,
      preferred = NULL,
      diagnostics = diagnostics
    ))
  }

  model <- fit_attempt$result
  ordinary_table <- standard_coefficient_table(model)
  readr::write_csv(ordinary_table, coefficient_path)

  robust_attempt <- cluster_robust_coefficient_table(model, spec$data)
  robust_status <- if (is.null(robust_attempt$table)) "failed" else "succeeded"
  robust_error <- robust_attempt$error %||% NA_character_

  if (is.null(robust_attempt$table)) {
    readr::write_csv(
      tibble(
        model_id = spec$model_id,
        model_name = spec$model_name,
        status = "failed",
        error = robust_error
      ),
      robust_path
    )
  } else {
    readr::write_csv(robust_attempt$table, robust_path)
  }

  write_model_summary(
    model = model,
    spec = spec,
    summary_path = summary_path,
    fit_warnings = fit_attempt$warnings,
    robust_status = robust_status,
    robust_error = robust_error
  )

  preferred_table <- if (!is.null(robust_attempt$table)) {
    robust_attempt$table |>
      dplyr::rename(std_error = robust_se)
  } else {
    ordinary_table
  }

  diagnostics <- tibble(
    model_id = spec$model_id,
    model_name = spec$model_name,
    status = "succeeded",
    n_observations = stats::nobs(model),
    aic = stats::AIC(model),
    residual_deviance = model$deviance %||% NA_real_,
    residual_df = model$df.residual %||% NA_real_,
    theta = model$theta %||% NA_real_,
    converged = isTRUE(model$converged),
    robust_se_status = robust_status,
    warnings = paste(unique(c(fit_attempt$warnings, robust_attempt$warnings)), collapse = " | "),
    error = NA_character_,
    formula = paste(deparse(spec$formula), collapse = " ")
  )

  list(
    spec = spec,
    model = model,
    ordinary = ordinary_table,
    robust = robust_attempt$table,
    preferred = preferred_table,
    diagnostics = diagnostics
  )
}

extract_result_row <- function(results, model_id, term, exposure, comparison_or_unit, interpretation) {
  result <- results[[model_id]]

  if (is.null(result) || is.null(result$preferred)) {
    model_name <- if (!is.null(result)) result$spec$model_name else model_id
    return(tibble(
      model_name = model_name,
      exposure = exposure,
      comparison_or_unit = comparison_or_unit,
      irr = NA_real_,
      conf_low = NA_real_,
      conf_high = NA_real_,
      p_value = NA_real_,
      interpretation = paste("Not available.", interpretation)
    ))
  }

  row <- result$preferred |>
    dplyr::filter(.data$term == !!term)

  if (nrow(row) == 0) {
    return(tibble(
      model_name = result$spec$model_name,
      exposure = exposure,
      comparison_or_unit = comparison_or_unit,
      irr = NA_real_,
      conf_low = NA_real_,
      conf_high = NA_real_,
      p_value = NA_real_,
      interpretation = paste("Term not estimated.", interpretation)
    ))
  }

  tibble(
    model_name = result$spec$model_name,
    exposure = exposure,
    comparison_or_unit = comparison_or_unit,
    irr = row$irr[1],
    conf_low = row$conf_low[1],
    conf_high = row$conf_high[1],
    p_value = row$p_value[1],
    interpretation = interpretation
  )
}

make_forest_plot <- function(result, output_file, title) {
  if (is.null(result) || is.null(result$preferred)) {
    warning("Cannot create forest plot for missing model result: ", output_file)
    return(invisible(NULL))
  }

  forest_terms <- tibble::tribble(
    ~term, ~label,
    "rurality_quintile4", "Rurality Q4 vs Q5 most urban",
    "rurality_quintile3", "Rurality Q3 vs Q5 most urban",
    "rurality_quintile2", "Rurality Q2 vs Q5 most urban",
    "rurality_quintile1", "Rurality Q1 most rural vs Q5 most urban",
    "svi_2022_per_0_1", "SVI per 0.1 increase",
    "medicaid_expansion_active", "Medicaid expansion active",
    "cvd_physicians_per_100k_2023", "CVD physicians per 100k",
    "medicare_ffs_hf_ihd_prevalence_2023", "Medicare FFS HF/IHD prevalence",
    "medicare_ffs_diabetes_prevalence_2023", "Medicare FFS diabetes prevalence",
    "medicare_ffs_ckd_prevalence_2023", "Medicare FFS CKD prevalence"
  )

  plot_data <- result$preferred |>
    dplyr::inner_join(forest_terms, by = "term") |>
    dplyr::mutate(label = factor(label, levels = rev(forest_terms$label)))

  if (nrow(plot_data) == 0) {
    warning("No requested forest-plot terms found for: ", output_file)
    return(invisible(NULL))
  }

  p <- ggplot(plot_data, aes(y = label)) +
    geom_vline(xintercept = 1, linetype = "dashed", color = "grey45", linewidth = 0.5) +
    geom_segment(aes(x = conf_low, xend = conf_high, yend = label), linewidth = 0.7, color = "#2f5f8f") +
    geom_point(aes(x = irr), size = 2.6, color = "#123b5d") +
    scale_x_log10(labels = scales::number_format(accuracy = 0.01)) +
    labs(
      title = title,
      x = "Incidence rate ratio, log scale",
      y = NULL
    ) +
    theme_minimal(base_size = 12) +
    theme(
      panel.grid.minor = element_blank(),
      plot.title = element_text(face = "bold"),
      axis.text.y = element_text(size = 10)
    )

  ggsave(output_file, p, width = 9.5, height = 6.5, dpi = 300)
  invisible(p)
}

# ------------------------------------------------------------
# 1. Load and inspect data
# ------------------------------------------------------------

print_section("1. Load and inspect data")

master_path <- path_in(input_file)
if (!file.exists(master_path)) {
  stop("Missing input file: ", master_path, call. = FALSE)
}

raw <- readr::read_csv(master_path, show_col_types = FALSE) |>
  janitor::clean_names()

message("Input dimensions:")
print(dim(raw))

message("Column names:")
print(names(raw))

required_columns <- c(
  "state",
  "year",
  "quarter",
  "sglt2_prescriptions",
  "sglt2_prescriptions_per_10000",
  "medicaid_enrolment_quarter_avg",
  "rurality_quintile",
  "rurality_quintile_label",
  "rucc_nonmetro_population_share_2023",
  "census_region",
  "svi_2022",
  "medicaid_expansion_active",
  "cvd_physicians_per_100k_2023",
  "medicare_ffs_hf_ihd_prevalence_2023",
  "medicare_ffs_diabetes_prevalence_2023",
  "medicare_ffs_ckd_prevalence_2023"
)

require_columns(raw, required_columns, "master analysis table")

forbidden_denominator_cols <- intersect(
  c("medicaid_enrolment", "medicaid_enrolment_avg"),
  names(raw)
)

if (length(forbidden_denominator_cols) > 0) {
  stop(
    "Master analysis table must contain only `medicaid_enrolment_quarter_avg` as the Medicaid denominator. Remove: ",
    paste(forbidden_denominator_cols, collapse = ", "),
    call. = FALSE
  )
}

message("Using Medicaid enrolment denominator column: medicaid_enrolment_quarter_avg")

message("Years:")
print(sort(unique(raw$year)))

message("Quarters:")
print(sort(unique(raw$quarter)))

message("Number of states:")
print(dplyr::n_distinct(raw$state))

message("Rows per year-quarter:")
print(raw |> dplyr::count(year, quarter, name = "n_rows") |> dplyr::arrange(year, quarter), n = Inf)

message("Summary of SGLT2 prescriptions:")
print(summary(raw$sglt2_prescriptions))

message("Summary of Medicaid enrolment denominator:")
print(summary(raw$medicaid_enrolment_quarter_avg))

if ("sglt2_prescriptions_per_10000" %in% names(raw)) {
  message("Summary of SGLT2 prescriptions per 10,000:")
  print(summary(raw$sglt2_prescriptions_per_10000))
}

message("Rurality quintile distribution:")
print(raw |> dplyr::count(rurality_quintile, rurality_quintile_label, name = "n") |> dplyr::arrange(rurality_quintile), n = Inf)

message("SVI summary:")
print(summary(raw$svi_2022))

missingness_summary <- purrr::map_dfr(
  names(raw),
  function(var) {
    tibble(
      variable = var,
      n_missing = sum(is.na(raw[[var]])),
      pct_missing = 100 * mean(is.na(raw[[var]]))
    )
  }
) |>
  dplyr::arrange(desc(n_missing), variable)

message("Missingness summary:")
print(missingness_summary, n = Inf, width = Inf)

raw <- raw |>
  dplyr::mutate(
    state = stringr::str_to_upper(state)
  )

raw <- raw |>
  dplyr::filter(
    year != 2020,
    !(state %in% c("PR", "XX")),
    state %in% valid_50dc
  )

assert_valid_states(raw, "filtered modelling input")

zero_fill_cols <- intersect(
  c(
    "sglt2_prescriptions",
    "sglt2_units",
    "sglt2_medicaid_reimbursed",
    "sglt2_total_reimbursed",
    "n_rows",
    "n_ndcs"
  ),
  names(raw)
)

zero_fill_report <- purrr::map_dfr(
  zero_fill_cols,
  function(var) {
    tibble(
      variable = var,
      n_missing_before = sum(is.na(raw[[var]])),
      n_missing_with_valid_enrolment = sum(
        is.na(raw[[var]]) &
          !is.na(raw$medicaid_enrolment_quarter_avg) &
          raw$medicaid_enrolment_quarter_avg > 0
      )
    )
  }
)

message("Zero-prescribing correction check before modelling:")
print(zero_fill_report, n = Inf, width = Inf)

raw <- raw |>
  dplyr::mutate(
    dplyr::across(
      dplyr::all_of(zero_fill_cols),
      ~ dplyr::if_else(
        !is.na(medicaid_enrolment_quarter_avg) & medicaid_enrolment_quarter_avg > 0 & is.na(.x),
        0,
        .x
      )
    )
  )

if (all(c("sglt2_prescriptions", "medicaid_enrolment_quarter_avg") %in% names(raw))) {
  raw <- raw |>
    dplyr::mutate(
      sglt2_prescriptions_per_10000 =
        sglt2_prescriptions / medicaid_enrolment_quarter_avg * 10000
    )
}

if (all(c("sglt2_units", "medicaid_enrolment_quarter_avg") %in% names(raw))) {
  raw <- raw |>
    dplyr::mutate(
      sglt2_units_per_10000 =
        sglt2_units / medicaid_enrolment_quarter_avg * 10000
    )
}

if (all(c("sglt2_medicaid_reimbursed", "medicaid_enrolment_quarter_avg") %in% names(raw))) {
  raw <- raw |>
    dplyr::mutate(
      sglt2_medicaid_reimbursed_per_10000 =
        sglt2_medicaid_reimbursed / medicaid_enrolment_quarter_avg * 10000
    )
}

if (all(c("sglt2_medicaid_reimbursed", "sglt2_prescriptions") %in% names(raw))) {
  raw <- raw |>
    dplyr::mutate(
      sglt2_reimbursement_per_prescription = dplyr::case_when(
        is.na(sglt2_prescriptions) ~ NA_real_,
        sglt2_prescriptions == 0 ~ NA_real_,
        TRUE ~ sglt2_medicaid_reimbursed / sglt2_prescriptions
      )
    )
}

model_input <- raw |>
  dplyr::filter(
    !is.na(medicaid_enrolment_quarter_avg),
    medicaid_enrolment_quarter_avg > 0
  ) |>
  dplyr::mutate(
    year_quarter = paste0(year, " Q", quarter),
    time_index = dplyr::dense_rank(year * 10 + quarter),
    calendar_quarter = factor(quarter),
    year_factor = factor(year),
    rurality_quintile = factor(rurality_quintile, levels = c(5, 4, 3, 2, 1)),
    rurality_quintile_label = forcats::fct_relevel(
      factor(rurality_quintile_label),
      "Q5 most urban",
      "Q4",
      "Q3",
      "Q2",
      "Q1 most rural"
    ),
    svi_2022_per_0_1 = svi_2022 / 0.1,
    census_region = factor(
      census_region,
      levels = c("Northeast", "Midwest", "South", "West")
    ),
    log_medicaid_enrolment = log(medicaid_enrolment_quarter_avg),
    rucc_nonmetro_population_share_per_10pct =
      rucc_nonmetro_population_share_2023 / 0.10
  )

svi_state_quintiles <- model_input |>
  dplyr::distinct(state, svi_2022) |>
  dplyr::arrange(svi_2022, state) |>
  dplyr::mutate(
    svi_quintile = dplyr::ntile(svi_2022, 5),
    svi_quintile = factor(svi_quintile, levels = 1:5),
    svi_quintile_label = dplyr::case_when(
      svi_quintile == "1" ~ "Q1 lowest SVI",
      svi_quintile == "2" ~ "Q2",
      svi_quintile == "3" ~ "Q3",
      svi_quintile == "4" ~ "Q4",
      svi_quintile == "5" ~ "Q5 highest SVI",
      TRUE ~ NA_character_
    ),
    svi_quintile_label = factor(
      svi_quintile_label,
      levels = c("Q1 lowest SVI", "Q2", "Q3", "Q4", "Q5 highest SVI")
    )
  )

model_input <- model_input |>
  dplyr::left_join(
    svi_state_quintiles |> dplyr::select(state, svi_quintile, svi_quintile_label),
    by = "state"
  )

require_columns(
  model_input,
  c(
    "sglt2_prescriptions_per_10000",
    "medicaid_enrolment_quarter_avg",
    "log_medicaid_enrolment"
  ),
  "cleaned modelling input"
)

model_required_complete_cols <- c(
  "sglt2_prescriptions",
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

missing_model_required <- model_input |>
  dplyr::summarise(
    dplyr::across(
      dplyr::all_of(model_required_complete_cols),
      ~ sum(is.na(.x))
    )
  ) |>
  tidyr::pivot_longer(
    dplyr::everything(),
    names_to = "variable",
    values_to = "n_missing"
  ) |>
  dplyr::filter(n_missing > 0)

if (nrow(missing_model_required) > 0) {
  message("Missing values in required modelling variables:")
  print(missing_model_required, n = Inf)
  stop("Required modelling variables must be complete; covariates and enrolment are not zero-filled.", call. = FALSE)
}

readr::write_csv(
  model_input,
  path_out("model_input_cleaned_all_products.csv")
)

# ------------------------------------------------------------
# 2. Exploratory summaries
# ------------------------------------------------------------

print_section("2. Exploratory summaries")

year_quarter_levels <- model_input |>
  dplyr::distinct(year, quarter, year_quarter, time_index) |>
  dplyr::arrange(time_index) |>
  dplyr::pull(year_quarter)

x_breaks <- model_input |>
  dplyr::distinct(year, quarter, year_quarter, time_index) |>
  dplyr::arrange(time_index) |>
  dplyr::filter(quarter == 1) |>
  dplyr::pull(year_quarter)

national_trend <- model_input |>
  dplyr::group_by(year, quarter, year_quarter, time_index) |>
  dplyr::summarise(
    total_sglt2_prescriptions = sum(sglt2_prescriptions, na.rm = TRUE),
    total_medicaid_enrolment = sum(medicaid_enrolment_quarter_avg, na.rm = TRUE),
    national_prescriptions_per_10000 =
      total_sglt2_prescriptions / total_medicaid_enrolment * 10000,
    n_states = dplyr::n_distinct(state),
    .groups = "drop"
  ) |>
  dplyr::arrange(time_index)

readr::write_csv(
  national_trend,
  path_out("descriptive_national_quarterly_trend.csv")
)

state_summary <- model_input |>
  dplyr::group_by(state) |>
  dplyr::summarise(
    mean_prescriptions_per_10000 = mean(sglt2_prescriptions_per_10000, na.rm = TRUE),
    median_prescriptions_per_10000 = median(sglt2_prescriptions_per_10000, na.rm = TRUE),
    min_prescriptions_per_10000 = min(sglt2_prescriptions_per_10000, na.rm = TRUE),
    max_prescriptions_per_10000 = max(sglt2_prescriptions_per_10000, na.rm = TRUE),
    total_prescriptions = sum(sglt2_prescriptions, na.rm = TRUE),
    mean_medicaid_enrolment = mean(medicaid_enrolment_quarter_avg, na.rm = TRUE),
    rurality_quintile = dplyr::first(rurality_quintile),
    rurality_quintile_label = dplyr::first(rurality_quintile_label),
    svi_2022 = dplyr::first(svi_2022),
    .groups = "drop"
  ) |>
  dplyr::arrange(rurality_quintile, state)

readr::write_csv(
  state_summary,
  path_out("descriptive_state_summary.csv")
)

rurality_trend <- model_input |>
  dplyr::group_by(rurality_quintile, rurality_quintile_label, year, quarter, year_quarter, time_index) |>
  dplyr::summarise(
    total_sglt2_prescriptions = sum(sglt2_prescriptions, na.rm = TRUE),
    total_medicaid_enrolment = sum(medicaid_enrolment_quarter_avg, na.rm = TRUE),
    prescriptions_per_10000 =
      total_sglt2_prescriptions / total_medicaid_enrolment * 10000,
    n_states = dplyr::n_distinct(state),
    .groups = "drop"
  ) |>
  dplyr::arrange(rurality_quintile, time_index)

readr::write_csv(
  rurality_trend,
  path_out("descriptive_rurality_quarterly_trend.csv")
)

svi_trend <- model_input |>
  dplyr::group_by(svi_quintile, svi_quintile_label, year, quarter, year_quarter, time_index) |>
  dplyr::summarise(
    total_sglt2_prescriptions = sum(sglt2_prescriptions, na.rm = TRUE),
    total_medicaid_enrolment = sum(medicaid_enrolment_quarter_avg, na.rm = TRUE),
    prescriptions_per_10000 =
      total_sglt2_prescriptions / total_medicaid_enrolment * 10000,
    n_states = dplyr::n_distinct(state),
    .groups = "drop"
  ) |>
  dplyr::arrange(svi_quintile, time_index)

readr::write_csv(
  svi_trend,
  path_out("descriptive_svi_quarterly_trend.csv")
)

rurality_membership <- model_input |>
  dplyr::distinct(
    state,
    rurality_quintile,
    rurality_quintile_label,
    rucc_nonmetro_population_share_2023,
    svi_2022
  ) |>
  dplyr::left_join(
    state_summary |> dplyr::select(state, mean_prescriptions_per_10000),
    by = "state"
  ) |>
  dplyr::arrange(rurality_quintile, dplyr::desc(rucc_nonmetro_population_share_2023), state)

readr::write_csv(
  rurality_membership,
  path_out("rurality_quintile_state_membership.csv")
)

# ------------------------------------------------------------
# 3. Exploratory figures
# ------------------------------------------------------------

print_section("3. Exploratory figures")

national_plot_data <- national_trend |>
  dplyr::mutate(year_quarter_f = factor(year_quarter, levels = year_quarter_levels))

fig1 <- ggplot(national_plot_data, aes(x = year_quarter_f, y = national_prescriptions_per_10000, group = 1)) +
  geom_line(color = "#164a7a", linewidth = 0.8) +
  geom_point(color = "#164a7a", size = 1.8) +
  scale_x_discrete(breaks = x_breaks) +
  scale_y_continuous(labels = scales::number_format(accuracy = 1)) +
  labs(
    title = "National Quarterly Medicaid SGLT2 Prescribing Rate",
    x = "Quarter",
    y = "Prescriptions per 10,000 Medicaid beneficiaries"
  ) +
  theme_minimal(base_size = 12) +
  theme(
    axis.text.x = element_text(angle = 45, hjust = 1),
    panel.grid.minor = element_blank(),
    plot.title = element_text(face = "bold")
  )

ggsave(plot_out("fig1_national_quarterly_sglt2_rate.png"), fig1, width = 10, height = 5.5, dpi = 300)

rurality_plot_data <- rurality_trend |>
  dplyr::mutate(year_quarter_f = factor(year_quarter, levels = year_quarter_levels))

fig2 <- ggplot(
  rurality_plot_data,
  aes(x = year_quarter_f, y = prescriptions_per_10000, color = rurality_quintile_label, group = rurality_quintile_label)
) +
  geom_line(linewidth = 0.75) +
  scale_x_discrete(breaks = x_breaks) +
  scale_y_continuous(labels = scales::number_format(accuracy = 1)) +
  scale_color_brewer(palette = "Dark2", name = "Rurality") +
  labs(
    title = "Quarterly Medicaid SGLT2 Prescribing Rate by Rurality Quintile",
    x = "Quarter",
    y = "Prescriptions per 10,000 Medicaid beneficiaries"
  ) +
  theme_minimal(base_size = 12) +
  theme(
    axis.text.x = element_text(angle = 45, hjust = 1),
    panel.grid.minor = element_blank(),
    legend.position = "bottom",
    plot.title = element_text(face = "bold")
  )

ggsave(plot_out("fig2_rurality_quintile_quarterly_sglt2_rate.png"), fig2, width = 10.5, height = 6, dpi = 300)

svi_plot_data <- svi_trend |>
  dplyr::mutate(year_quarter_f = factor(year_quarter, levels = year_quarter_levels))

fig3 <- ggplot(
  svi_plot_data,
  aes(x = year_quarter_f, y = prescriptions_per_10000, color = svi_quintile_label, group = svi_quintile_label)
) +
  geom_line(linewidth = 0.75) +
  scale_x_discrete(breaks = x_breaks) +
  scale_y_continuous(labels = scales::number_format(accuracy = 1)) +
  scale_color_brewer(palette = "Set1", name = "SVI quintile") +
  labs(
    title = "Quarterly Medicaid SGLT2 Prescribing Rate by State SVI Quintile",
    x = "Quarter",
    y = "Prescriptions per 10,000 Medicaid beneficiaries"
  ) +
  theme_minimal(base_size = 12) +
  theme(
    axis.text.x = element_text(angle = 45, hjust = 1),
    panel.grid.minor = element_blank(),
    legend.position = "bottom",
    plot.title = element_text(face = "bold")
  )

ggsave(plot_out("fig3_svi_quintile_quarterly_sglt2_rate.png"), fig3, width = 10.5, height = 6, dpi = 300)

fig4 <- ggplot(model_input, aes(x = rurality_quintile_label, y = sglt2_prescriptions_per_10000, fill = rurality_quintile_label)) +
  geom_boxplot(outlier.alpha = 0.3, linewidth = 0.4) +
  scale_y_continuous(labels = scales::number_format(accuracy = 1)) +
  scale_fill_brewer(palette = "Dark2", guide = "none") +
  labs(
    title = "State-Quarter SGLT2 Prescribing Rates by Rurality Quintile",
    x = "Rurality quintile",
    y = "Prescriptions per 10,000 Medicaid beneficiaries"
  ) +
  theme_minimal(base_size = 12) +
  theme(
    axis.text.x = element_text(angle = 25, hjust = 1),
    panel.grid.minor = element_blank(),
    plot.title = element_text(face = "bold")
  )

ggsave(plot_out("fig4_boxplot_rates_by_rurality_quintile.png"), fig4, width = 8.5, height = 5.5, dpi = 300)

fig5 <- ggplot(state_summary, aes(x = svi_2022, y = mean_prescriptions_per_10000, color = rurality_quintile_label)) +
  geom_point(size = 2.5, alpha = 0.9) +
  geom_smooth(method = "lm", se = FALSE, color = "grey25", linewidth = 0.6) +
  scale_x_continuous(labels = scales::number_format(accuracy = 0.01)) +
  scale_y_continuous(labels = scales::number_format(accuracy = 1)) +
  scale_color_brewer(palette = "Dark2", name = "Rurality") +
  labs(
    title = "State SVI and Mean Medicaid SGLT2 Prescribing Rate",
    x = "State-level SVI, 2022",
    y = "Mean prescriptions per 10,000 Medicaid beneficiaries"
  ) +
  theme_minimal(base_size = 12) +
  theme(
    panel.grid.minor = element_blank(),
    legend.position = "bottom",
    plot.title = element_text(face = "bold")
  )

ggsave(plot_out("fig5_scatter_svi_vs_state_mean_rate.png"), fig5, width = 8.5, height = 5.8, dpi = 300)

state_order <- state_summary |>
  dplyr::mutate(rurality_numeric = as.integer(as.character(rurality_quintile))) |>
  dplyr::arrange(rurality_numeric, dplyr::desc(mean_prescriptions_per_10000), state) |>
  dplyr::pull(state)

heatmap_data <- model_input |>
  dplyr::mutate(
    year_quarter_f = factor(year_quarter, levels = year_quarter_levels),
    state_ordered = factor(state, levels = rev(state_order))
  )

fig6 <- ggplot(heatmap_data, aes(x = year_quarter_f, y = state_ordered, fill = sglt2_prescriptions_per_10000)) +
  geom_tile() +
  scale_x_discrete(breaks = x_breaks) +
  scale_fill_viridis_c(
    option = "C",
    labels = scales::number_format(accuracy = 1),
    name = "Rate per\n10,000"
  ) +
  labs(
    title = "State-Quarter Medicaid SGLT2 Prescribing Rates",
    x = "Quarter",
    y = "State"
  ) +
  theme_minimal(base_size = 10) +
  theme(
    axis.text.x = element_text(angle = 45, hjust = 1),
    panel.grid = element_blank(),
    plot.title = element_text(face = "bold")
  )

ggsave(plot_out("fig6_state_quarter_heatmap_sglt2_rate.png"), fig6, width = 12, height = 9.5, dpi = 300)

# ------------------------------------------------------------
# 4-6. Main negative binomial model sequence
# ------------------------------------------------------------

print_section("4-6. Negative binomial model sequence")

model_specs <- list(
  list(
    model_id = "model_0",
    model_name = "Model 0: Time trend only",
    purpose = "Estimate overall change in prescribing over time.",
    formula = as.formula("sglt2_prescriptions ~ time_index + offset(log_medicaid_enrolment)"),
    coefficient_file = "model_0_time_trend_coefficients.csv",
    data = model_input
  ),
  list(
    model_id = "model_1",
    model_name = "Model 1: Rurality + time",
    purpose = "Estimate temporally adjusted association between rurality quintile and prescribing.",
    formula = as.formula("sglt2_prescriptions ~ rurality_quintile + factor(year) + factor(quarter) + offset(log_medicaid_enrolment)"),
    coefficient_file = "model_1_rurality_time_coefficients.csv",
    data = model_input
  ),
  list(
    model_id = "model_2",
    model_name = "Model 2: SVI + time",
    purpose = "Estimate association per 0.1 increase in SVI.",
    formula = as.formula("sglt2_prescriptions ~ svi_2022_per_0_1 + factor(year) + factor(quarter) + offset(log_medicaid_enrolment)"),
    coefficient_file = "model_2_svi_time_coefficients.csv",
    data = model_input
  ),
  list(
    model_id = "model_3",
    model_name = "Model 3: Rurality + SVI + time",
    purpose = "Assess whether rurality association persists after accounting for SVI, and vice versa.",
    formula = as.formula("sglt2_prescriptions ~ rurality_quintile + svi_2022_per_0_1 + factor(year) + factor(quarter) + offset(log_medicaid_enrolment)"),
    coefficient_file = "model_3_rurality_svi_time_coefficients.csv",
    data = model_input
  ),
  list(
    model_id = "model_4",
    model_name = "Model 4: Add Medicaid expansion",
    purpose = "Assess whether rurality/SVI associations persist after Medicaid expansion adjustment.",
    formula = as.formula("sglt2_prescriptions ~ rurality_quintile + svi_2022_per_0_1 + medicaid_expansion_active + factor(year) + factor(quarter) + offset(log_medicaid_enrolment)"),
    coefficient_file = "model_4_add_medicaid_expansion_coefficients.csv",
    data = model_input
  ),
  list(
    model_id = "model_5",
    model_name = "Model 5: Add CVD physician density",
    purpose = "Assess whether specialist physician density explains associations.",
    formula = as.formula("sglt2_prescriptions ~ rurality_quintile + svi_2022_per_0_1 + medicaid_expansion_active + cvd_physicians_per_100k_2023 + factor(year) + factor(quarter) + offset(log_medicaid_enrolment)"),
    coefficient_file = "model_5_add_cvd_physician_density_coefficients.csv",
    data = model_input
  ),
  list(
    model_id = "model_6",
    model_name = "Model 6: Full model with disease burden",
    purpose = "Fully adjusted planned model.",
    formula = as.formula("sglt2_prescriptions ~ rurality_quintile + svi_2022_per_0_1 + medicaid_expansion_active + cvd_physicians_per_100k_2023 + medicare_ffs_hf_ihd_prevalence_2023 + medicare_ffs_diabetes_prevalence_2023 + medicare_ffs_ckd_prevalence_2023 + factor(year) + factor(quarter) + offset(log_medicaid_enrolment)"),
    coefficient_file = "model_6_full_covariate_coefficients.csv",
    data = model_input
  )
)

model_specs <- append(
  model_specs,
  list(
    list(
      model_id = "model_7",
      model_name = "Model 7: Region-adjusted full model",
      purpose = "Region-adjusted planned full model.",
      formula = as.formula("sglt2_prescriptions ~ rurality_quintile + svi_2022_per_0_1 + medicaid_expansion_active + census_region + cvd_physicians_per_100k_2023 + medicare_ffs_hf_ihd_prevalence_2023 + medicare_ffs_diabetes_prevalence_2023 + medicare_ffs_ckd_prevalence_2023 + factor(year) + factor(quarter) + offset(log_medicaid_enrolment)"),
      coefficient_file = "model_7_region_adjusted_full_coefficients.csv",
      data = model_input
    ),
    list(
      model_id = "model_s1",
      model_name = "Model S1: Continuous rurality sensitivity",
      purpose = "Sensitivity model using continuous nonmetro population share per 10 percentage points.",
      formula = as.formula("sglt2_prescriptions ~ rucc_nonmetro_population_share_per_10pct + svi_2022_per_0_1 + medicaid_expansion_active + cvd_physicians_per_100k_2023 + medicare_ffs_hf_ihd_prevalence_2023 + medicare_ffs_diabetes_prevalence_2023 + medicare_ffs_ckd_prevalence_2023 + factor(year) + factor(quarter) + offset(log_medicaid_enrolment)"),
      coefficient_file = "model_s1_continuous_rurality_coefficients.csv",
      data = model_input
    )
  )
)

model_specs <- append(
  model_specs,
  list(list(
    model_id = "model_s2",
    model_name = "Model S2: Complete years through 2024",
    purpose = "Sensitivity model repeating Model 6 after filtering to complete years through 2024.",
    formula = as.formula("sglt2_prescriptions ~ rurality_quintile + svi_2022_per_0_1 + medicaid_expansion_active + cvd_physicians_per_100k_2023 + medicare_ffs_hf_ihd_prevalence_2023 + medicare_ffs_diabetes_prevalence_2023 + medicare_ffs_ckd_prevalence_2023 + factor(year) + factor(quarter) + offset(log_medicaid_enrolment)"),
    coefficient_file = "model_s2_complete_years_through_2024_coefficients.csv",
    data = model_input |> dplyr::filter(year <= 2024)
  ))
)

# Future sensitivity analyses:
# - Single-agent SGLT2 inhibitors only.
# - Empagliflozin/dapagliflozin only.
# - Primary care physicians per 100k instead of CVD physicians per 100k.
# - Total physicians per 100k instead of CVD physicians per 100k.

model_results <- purrr::map(model_specs, fit_and_save_nb_model)
names(model_results) <- purrr::map_chr(model_specs, "model_id")

diagnostics_summary <- purrr::map_dfr(model_results, "diagnostics")
readr::write_csv(
  diagnostics_summary,
  path_out("model_diagnostics_summary.csv")
)

# ------------------------------------------------------------
# 7. Key extracted results
# ------------------------------------------------------------

print_section("7. Key extracted results")

rurality_interpretation <- "For rurality, Q5 most urban is the reference; IRR < 1 indicates lower prescribing rate than Q5."
svi_interpretation <- "For SVI, IRR corresponds to each 0.1 higher state-level SVI."
expansion_interpretation <- "IRR compares active Medicaid expansion state-quarters with non-active state-quarters."
cvd_interpretation <- "IRR corresponds to each additional CVD physician per 100,000 population."

key_results <- dplyr::bind_rows(
  purrr::map_dfr(
    c("model_1", "model_3", "model_4", "model_5", "model_6", "model_7"),
    ~ extract_result_row(
      model_results,
      .x,
      "rurality_quintile1",
      "Rurality",
      "Q1 most rural vs Q5 most urban",
      rurality_interpretation
    )
  ),
  purrr::map_dfr(
    c("rurality_quintile2", "rurality_quintile3", "rurality_quintile4"),
    ~ extract_result_row(
      model_results,
      "model_6",
      .x,
      "Rurality",
      dplyr::case_when(
        .x == "rurality_quintile2" ~ "Q2 vs Q5 most urban",
        .x == "rurality_quintile3" ~ "Q3 vs Q5 most urban",
        .x == "rurality_quintile4" ~ "Q4 vs Q5 most urban"
      ),
      rurality_interpretation
    )
  ),
  purrr::map_dfr(
    c("model_2", "model_3", "model_4", "model_5", "model_6", "model_7"),
    ~ extract_result_row(
      model_results,
      .x,
      "svi_2022_per_0_1",
      "SVI",
      "Per 0.1 increase",
      svi_interpretation
    )
  ),
  purrr::map_dfr(
    c("model_4", "model_5", "model_6", "model_7"),
    ~ extract_result_row(
      model_results,
      .x,
      "medicaid_expansion_active",
      "Medicaid expansion",
      "Active vs not active",
      expansion_interpretation
    )
  ),
  purrr::map_dfr(
    c("model_5", "model_6", "model_7"),
    ~ extract_result_row(
      model_results,
      .x,
      "cvd_physicians_per_100k_2023",
      "CVD physician density",
      "Per 1 CVD physician per 100k",
      cvd_interpretation
    )
  )
) |>
  dplyr::filter(!stringr::str_detect(model_name, "^model_7$|Not available")) |>
  dplyr::filter(!(stringr::str_detect(model_name, "model_7") & is.na(irr)))

if (!"model_7" %in% names(model_results)) {
  key_results <- key_results |>
    dplyr::filter(model_name != "model_7")
}

readr::write_csv(
  key_results,
  path_out("key_results_summary.csv")
)

message("Key results summary:")
print(key_results, n = Inf, width = Inf)

# ------------------------------------------------------------
# 8. Forest plot of model results
# ------------------------------------------------------------

print_section("8. Forest plots")

make_forest_plot(
  result = model_results[["model_6"]],
  output_file = plot_out("fig7_forest_plot_full_model_irrs.png"),
  title = "Adjusted IRRs from Full Model"
)

if ("model_7" %in% names(model_results)) {
  make_forest_plot(
    result = model_results[["model_7"]],
    output_file = plot_out("fig8_forest_plot_region_adjusted_full_model_irrs.png"),
    title = "Adjusted IRRs from Region-Adjusted Full Model"
  )
}

# ------------------------------------------------------------
# 9. Diagnostics and overdispersion check
# ------------------------------------------------------------

print_section("9. Diagnostics and checks")

poisson_attempt <- fit_with_warnings(
  stats::glm(
    sglt2_prescriptions ~ rurality_quintile + factor(year) + factor(quarter) + offset(log_medicaid_enrolment),
    family = poisson(),
    data = model_input
  )
)

poisson_overdispersion <- if (is.null(poisson_attempt$error)) {
  poisson_model <- poisson_attempt$result
  tibble(
    model = "Poisson comparison: rurality + year + quarter",
    n_observations = stats::nobs(poisson_model),
    residual_deviance = poisson_model$deviance,
    residual_df = poisson_model$df.residual,
    dispersion_ratio = poisson_model$deviance / poisson_model$df.residual,
    warnings = paste(poisson_attempt$warnings, collapse = " | "),
    error = NA_character_
  )
} else {
  tibble(
    model = "Poisson comparison: rurality + year + quarter",
    n_observations = NA_integer_,
    residual_deviance = NA_real_,
    residual_df = NA_real_,
    dispersion_ratio = NA_real_,
    warnings = paste(poisson_attempt$warnings, collapse = " | "),
    error = poisson_attempt$error
  )
}

readr::write_csv(
  poisson_overdispersion,
  path_out("poisson_overdispersion_check.csv")
)

message("Poisson overdispersion check:")
print(poisson_overdispersion, width = Inf)

# ------------------------------------------------------------
# 11. Write modelling log
# ------------------------------------------------------------

print_section("11. Write modelling log")

log_path <- doc_out("2026-05-03_modelling_poc_log.md")

model_status_md <- capture.output(
  diagnostics_summary |>
    dplyr::select(
      model_name,
      status,
      n_observations,
      aic,
      theta,
      converged,
      robust_se_status,
      warnings,
      error
    ) |>
    print(n = Inf, width = Inf)
)

missingness_md <- capture.output(
  missingness_summary |>
    dplyr::filter(n_missing > 0) |>
    dplyr::mutate(pct_missing = round(pct_missing, 2)) |>
    print(n = Inf, width = Inf)
)

if (length(missingness_md) == 0 || all(stringr::str_detect(missingness_md, "^# A tibble: 0"))) {
  missingness_md <- "No missing values were detected in the raw master table."
}

key_results_md <- capture.output(
  key_results |>
    dplyr::mutate(
      irr = round(irr, 3),
      conf_low = round(conf_low, 3),
      conf_high = round(conf_high, 3),
      p_value = signif(p_value, 3)
    ) |>
    print(n = Inf, width = Inf)
)

q1_results <- key_results |>
  dplyr::filter(exposure == "Rurality", comparison_or_unit == "Q1 most rural vs Q5 most urban")

svi_results <- key_results |>
  dplyr::filter(exposure == "SVI")

model6_q1 <- q1_results |> dplyr::filter(stringr::str_detect(model_name, "Model 6")) |> dplyr::slice(1)
model6_svi <- svi_results |> dplyr::filter(stringr::str_detect(model_name, "Model 6")) |> dplyr::slice(1)

model3_q1 <- q1_results |> dplyr::filter(stringr::str_detect(model_name, "Model 3")) |> dplyr::slice(1)
model3_svi <- svi_results |> dplyr::filter(stringr::str_detect(model_name, "Model 3")) |> dplyr::slice(1)

model6_expansion <- key_results |>
  dplyr::filter(exposure == "Medicaid expansion", stringr::str_detect(model_name, "Model 6")) |>
  dplyr::slice(1)

model6_cvd <- key_results |>
  dplyr::filter(exposure == "CVD physician density", stringr::str_detect(model_name, "Model 6")) |>
  dplyr::slice(1)

rurality_result_sentence <- if (nrow(model6_q1) == 1) {
  paste0(
    "In Model 6, Q1 most rural versus Q5 most urban had IRR ",
    fmt_num(model6_q1$irr),
    " (95% CI ",
    fmt_num(model6_q1$conf_low),
    "-",
    fmt_num(model6_q1$conf_high),
    ")."
  )
} else {
  "Model 6 rurality result was not available."
}

svi_result_sentence <- if (nrow(model6_svi) == 1) {
  paste0(
    "In Model 6, each 0.1 higher SVI had IRR ",
    fmt_num(model6_svi$irr),
    " (95% CI ",
    fmt_num(model6_svi$conf_low),
    "-",
    fmt_num(model6_svi$conf_high),
    ")."
  )
} else {
  "Model 6 SVI result was not available."
}

covariate_change_sentence <- paste(
  if (nrow(model3_q1) == 1 && nrow(model6_q1) == 1) {
    paste0(
      "The Q1 rurality IRR changed from ",
      fmt_num(model3_q1$irr),
      " in Model 3 to ",
      fmt_num(model6_q1$irr),
      " in Model 6."
    )
  } else {
    "The rurality estimate change from Model 3 to Model 6 could not be summarised."
  },
  if (nrow(model3_svi) == 1 && nrow(model6_svi) == 1) {
    paste0(
      "The SVI IRR changed from ",
      fmt_num(model3_svi$irr),
      " in Model 3 to ",
      fmt_num(model6_svi$irr),
      " in Model 6."
    )
  } else {
    "The SVI estimate change from Model 3 to Model 6 could not be summarised."
  }
)

expansion_sentence <- if (nrow(model6_expansion) == 1) {
  paste0(
    "In Model 6, Medicaid expansion active had IRR ",
    fmt_num(model6_expansion$irr),
    " (95% CI ",
    fmt_num(model6_expansion$conf_low),
    "-",
    fmt_num(model6_expansion$conf_high),
    ")."
  )
} else {
  "Model 6 Medicaid expansion result was not available."
}

cvd_sentence <- if (nrow(model6_cvd) == 1) {
  paste0(
    "In Model 6, each additional CVD physician per 100k had IRR ",
    fmt_num(model6_cvd$irr),
    " (95% CI ",
    fmt_num(model6_cvd$conf_low),
    "-",
    fmt_num(model6_cvd$conf_high),
    ")."
  )
} else {
  "Model 6 CVD physician density result was not available."
}

log_lines <- c(
  "# SGLT2 Prescribing Modelling Log",
  "",
  "Date: 2026-05-03",
  "",
  "## Purpose",
  "",
  "Fit descriptive summaries, plots, and negative binomial regression models for Medicaid SGLT2 inhibitor prescribing across state-quarters.",
  "",
  "## Input File",
  "",
  paste0("- `for_analysis/", input_file, "`"),
  "",
  "## Cleaning Before Modelling",
  "",
  "- The modelling script requires `medicaid_enrolment_quarter_avg` as the only Medicaid denominator column.",
  "- Rows were restricted to 50 states plus DC, excluded 2020, excluded PR/XX, and required positive non-missing Medicaid enrolment.",
  "- The script checks for missing SGLT2 outcome/count/reimbursement values with valid Medicaid enrolment and treats them as zero in the modelling input only. Medicaid enrolment and covariates are not zero-filled.",
  "- SGLT2 prescribing rates per 10,000 are recalculated after this correction and are used only for descriptive summaries and plots.",
  "- `sglt2_reimbursement_per_prescription` is set to NA when `sglt2_prescriptions == 0`.",
  "",
  "## Outcome and Offset",
  "",
  "- Main regression outcome: `sglt2_prescriptions`.",
  "- Offset: `log_medicaid_enrolment = log(medicaid_enrolment_quarter_avg)`.",
  "- This specification estimates prescribing rate ratios rather than modelling the pre-calculated prescribing rate as the primary outcome.",
  "",
  "## Why Negative Binomial Regression",
  "",
  "The outcome is a count and the Poisson comparison showed overdispersion. Negative binomial regression was used to estimate incidence rate ratios while allowing extra-Poisson variation.",
  "",
  "## Exploratory Trend Analyses",
  "",
  "- National quarterly prescribing trends were summarised from total prescriptions and total Medicaid enrolment.",
  "- Rurality-quintile and SVI-quintile trends were summarised using aggregated prescriptions and enrolment within each quarter.",
  "- State-level mean prescribing rates were used for rurality membership and SVI scatter plots.",
  "",
  "## Model Sequence",
  "",
  "- Model 0: Time trend only.",
  "- Model 1: Rurality plus year and quarter.",
  "- Model 2: SVI plus year and quarter.",
  "- Model 3: Rurality plus SVI plus year and quarter.",
  "- Model 4: Adds Medicaid expansion.",
  "- Model 5: Adds CVD physician density.",
  "- Model 6: Adds cardiometabolic disease burden.",
  "- Model 7: Adds Census region.",
  "- Model S1: Continuous rurality sensitivity.",
  "- Model S2: Complete years through 2024 sensitivity.",
  "",
  "## Interpretation of IRRs",
  "",
  "- IRR < 1 indicates a lower SGLT2 prescribing rate relative to the reference group or per-unit comparison.",
  "- For rurality, Q5 most urban is the reference group.",
  "- For SVI, the IRR corresponds to each 0.1 higher state-level SVI.",
  "- Key result confidence intervals and p-values use state-clustered robust standard errors when available.",
  "",
  "## Key Rurality Results",
  "",
  rurality_result_sentence,
  "",
  "## Key SVI Results",
  "",
  svi_result_sentence,
  "",
  "## Covariate Adjustment",
  "",
  covariate_change_sentence,
  expansion_sentence,
  cvd_sentence,
  "",
  "## Key Results Table",
  "",
  "```",
  key_results_md,
  "```",
  "",
  "## Missingness and Convergence",
  "",
  "Raw missingness with nonzero missing counts:",
  "",
  "```",
  missingness_md,
  "```",
  "",
  "Model diagnostics:",
  "",
  "```",
  model_status_md,
  "```",
  "",
  "Poisson overdispersion check:",
  "",
  "```",
  capture.output(print(poisson_overdispersion, width = Inf)),
  "```",
  "",
  "## Residual Limitations",
  "",
  "- State-level structural covariates are time-invariant in this analysis.",
  "- Disease burden variables are Medicare FFS-based proxies and are not Medicaid-specific prevalence estimates.",
  "- Medicaid expansion timing is included, but other time-varying state policies are not yet modelled.",
  "- Cluster-robust standard errors address repeated observations by state, but the models remain ecological state-quarter analyses.",
  "",
  "## Recommended Next Steps",
  "",
  "- Review source definitions and covariate validity before final modelling.",
  "- Consider state fixed effects or random effects depending on the estimand.",
  "- Evaluate product-specific outcomes, including single-agent SGLT2 inhibitors and empagliflozin/dapagliflozin.",
  "- Compare CVD physician density with primary care and total physician density specifications.",
  "- Add region or other geographic controls if available and analytically justified.",
  "- Pre-specify the final estimand and sensitivity analysis set before manuscript modelling.",
  "",
  "## Outputs",
  "",
  "- `for_analysis/model_outputs/model_input_cleaned_all_products.csv`",
  "- `for_analysis/model_outputs/key_results_summary.csv`",
  "- `for_analysis/model_outputs/model_diagnostics_summary.csv`",
  "- `for_analysis/model_outputs/poisson_overdispersion_check.csv`",
  "- `for_analysis/model_outputs/plots/`"
)

writeLines(log_lines, log_path)

# ------------------------------------------------------------
# 12. Outputs summary
# ------------------------------------------------------------

print_section("12. Outputs summary")

message("Number of rows analysed: ", nrow(model_input))
message("Number of states: ", dplyr::n_distinct(model_input$state))
message("Years included: ", paste(sort(unique(model_input$year)), collapse = ", "))
message("Quarters included: ", paste(sort(unique(model_input$quarter)), collapse = ", "))
message("Key results summary: ", path_out("key_results_summary.csv"))
message("Modelling log: ", log_path)
message("Plots folder: ", plot_dir)

print_section("Complete")
