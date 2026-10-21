# Shared setup for the Medicaid SDUD SGLT2 analysis.

required_packages <- c(
  "tidyverse",
  "here",
  "janitor",
  "readr",
  "readxl",
  "lubridate",
  "DBI",
  "duckdb",
  "glue",
  "MASS",
  "broom",
  "sandwich",
  "lmtest",
  "ggplot2",
  "scales",
  "forcats"
)

missing_packages <- required_packages[
  !vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)
]

if (length(missing_packages) > 0) {
  stop(
    "Install required R package(s) before running the analysis: ",
    paste(missing_packages, collapse = ", "),
    call. = FALSE
  )
}

suppressPackageStartupMessages({
  library(tidyverse)
  library(janitor)
  library(lubridate)
})

analysis_years <- c(2015:2019, 2021:2025)
valid_50dc <- c(state.abb, "DC")

project_path <- function(...) {
  here::here(...)
}

# Repository-relative form of a project path, for logs that are committed.
relative_project_path <- function(path) {
  root <- paste0(here::here(), "/")
  ifelse(startsWith(path, root), substring(path, nchar(root) + 1), path)
}

ensure_dir <- function(path) {
  dir.create(path, recursive = TRUE, showWarnings = FALSE)
  invisible(path)
}

safe_write_csv <- function(data, path) {
  ensure_dir(dirname(path))
  readr::write_csv(data, path)
  invisible(path)
}

require_files <- function(paths, label = "required file") {
  missing <- paths[!file.exists(paths)]
  if (length(missing) > 0) {
    stop(
      "Missing ",
      label,
      "(s):\n",
      paste(missing, collapse = "\n"),
      call. = FALSE
    )
  }
  invisible(paths)
}

require_columns <- function(data, required, data_label) {
  missing <- setdiff(required, names(data))
  if (length(missing) > 0) {
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
    print(duplicate_rows, n = Inf)
    stop(data_label, " contains duplicate key rows.", call. = FALSE)
  }

  invisible(data)
}

assert_valid_states <- function(data, data_label, require_all = TRUE) {
  invalid <- setdiff(unique(data$state), valid_50dc)
  if (length(invalid) > 0) {
    stop(
      data_label,
      " contains state codes outside 50 states + DC: ",
      paste(sort(invalid), collapse = ", "),
      call. = FALSE
    )
  }

  if (require_all) {
    missing <- setdiff(valid_50dc, unique(data$state))
    if (length(missing) > 0) {
      stop(
        data_label,
        " is missing state codes: ",
        paste(sort(missing), collapse = ", "),
        call. = FALSE
      )
    }
  }

  invisible(data)
}

assert_analysis_exclusions <- function(data, data_label) {
  if (any(data$year == 2020, na.rm = TRUE)) {
    stop(data_label, " contains 2020 rows.", call. = FALSE)
  }

  if (any(data$state %in% c("PR", "XX"), na.rm = TRUE)) {
    stop(data_label, " contains PR or XX rows.", call. = FALSE)
  }

  invisible(data)
}

quarter_from_month <- function(month) {
  dplyr::case_when(
    month %in% 1:3 ~ 1L,
    month %in% 4:6 ~ 2L,
    month %in% 7:9 ~ 3L,
    month %in% 10:12 ~ 4L,
    TRUE ~ NA_integer_
  )
}

quarter_start_date <- function(year, quarter) {
  month <- dplyr::case_when(
    quarter == 1 ~ 1L,
    quarter == 2 ~ 4L,
    quarter == 3 ~ 7L,
    quarter == 4 ~ 10L,
    TRUE ~ NA_integer_
  )

  if (any(is.na(month))) {
    stop("quarter must be coded 1, 2, 3, or 4.", call. = FALSE)
  }

  lubridate::make_date(year = year, month = month, day = 1)
}

parse_bool_strict <- function(x, label) {
  if (is.logical(x)) {
    return(x)
  }

  if (is.numeric(x)) {
    valid <- is.na(x) | x %in% c(0, 1)
    if (!all(valid)) {
      stop(label, " numeric values must be 0, 1, or NA.", call. = FALSE)
    }
    return(dplyr::case_when(is.na(x) ~ NA, x == 1 ~ TRUE, x == 0 ~ FALSE))
  }

  x_chr <- stringr::str_squish(stringr::str_to_lower(as.character(x)))
  x_chr[x_chr %in% c("", "na", "n/a", "missing", "unknown")] <- NA_character_
  true_values <- c("true", "t", "yes", "y", "1", "adopted", "expanded")
  false_values <- c("false", "f", "no", "n", "0", "not adopted", "not expanded")
  valid <- is.na(x_chr) | x_chr %in% c(true_values, false_values)

  if (!all(valid)) {
    stop(
      label,
      " contains unsupported TRUE/FALSE values: ",
      paste(sort(unique(x_chr[!valid])), collapse = ", "),
      call. = FALSE
    )
  }

  dplyr::case_when(
    is.na(x_chr) ~ NA,
    x_chr %in% true_values ~ TRUE,
    x_chr %in% false_values ~ FALSE
  )
}

parse_date_strict <- function(x, label) {
  if (inherits(x, "Date")) {
    return(x)
  }

  x_chr <- stringr::str_squish(as.character(x))
  x_chr[x_chr %in% c("", "NA", "N/A", "na", "n/a", "missing", "unknown")] <- NA_character_
  parsed <- suppressWarnings(lubridate::ymd(x_chr))

  if (any(is.na(parsed) & !is.na(x_chr))) {
    stop(label, " contains unparseable dates. Use YYYY-MM-DD.", call. = FALSE)
  }

  as.Date(parsed)
}

census_region_lookup <- function() {
  tibble::tribble(
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
  )
}

coefficient_table_model_based <- function(model) {
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

coefficient_table_cluster_robust <- function(model, data) {
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
}

fit_nb_model <- function(data, formula, model_id, model_name) {
  warnings_seen <- character()
  fit <- tryCatch(
    withCallingHandlers(
      MASS::glm.nb(formula, data = data, control = glm.control(maxit = 100)),
      warning = function(w) {
        warnings_seen <<- c(warnings_seen, conditionMessage(w))
        invokeRestart("muffleWarning")
      }
    ),
    error = function(e) {
      stop("Model failed for ", model_id, ": ", conditionMessage(e), call. = FALSE)
    }
  )

  model_based <- coefficient_table_model_based(fit)
  robust <- tryCatch(
    coefficient_table_cluster_robust(fit, data),
    error = function(e) {
      warning(
        "Cluster-robust SE failed for ",
        model_id,
        "; using model-based SE for preferred table. Error: ",
        conditionMessage(e),
        call. = FALSE
      )
      NULL
    }
  )

  diagnostics <- tibble::tibble(
    model_id = model_id,
    model_name = model_name,
    status = "succeeded",
    n_observations = stats::nobs(fit),
    aic = stats::AIC(fit),
    residual_deviance = fit$deviance,
    residual_df = fit$df.residual,
    theta = fit$theta,
    converged = isTRUE(fit$converged),
    robust_se_status = if (is.null(robust)) "model_based_fallback" else "cluster_robust_state",
    warnings = paste(unique(warnings_seen), collapse = " | "),
    error = NA_character_,
    formula = paste(deparse(formula), collapse = " ")
  )

  list(
    model = fit,
    model_based = model_based,
    robust = robust,
    preferred = robust %||% model_based,
    diagnostics = diagnostics
  )
}

`%||%` <- function(x, y) {
  if (is.null(x) || length(x) == 0) y else x
}

update_model_diagnostics <- function(new_rows) {
  path <- project_path("for_analysis", "model_outputs", "diagnostics", "model_diagnostics_summary.csv")
  ensure_dir(dirname(path))

  existing <- if (file.exists(path)) {
    readr::read_csv(path, show_col_types = FALSE)
  } else {
    tibble::tibble()
  }

  if (nrow(existing) > 0 && "model_id" %in% names(existing)) {
    existing <- existing |>
      dplyr::filter(!model_id %in% new_rows$model_id)
  }

  readr::write_csv(dplyr::bind_rows(existing, new_rows), path)
  invisible(path)
}
