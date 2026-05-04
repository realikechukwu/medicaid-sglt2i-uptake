# Build state-quarter SGLT2 analysis table.

suppressPackageStartupMessages({
  library(tidyverse)
  library(janitor)
  library(lubridate)
  library(here)
  library(readr)
})

valid_50dc <- c(state.abb, "DC")

input_files <- c(
  base_sglt2 = "sglt2_state_quarter_rates_all_products_50dc_excluding_2020.csv",
  medicaid_expansion = "medicaid_expansion_status.csv",
  physician_density = "ahrf_physician_density_2023_50dc.csv",
  disease_burden = "mmd_disease_burden_2023_50dc.csv",
  svi = "svi_state_aggregates_by_source_year.csv",
  rucc = "Ruralurbancontinuumcodes2023.csv"
)

for_analysis_dir <- here("for_analysis")
scripts_dir <- here("scripts")
docs_dir <- here("docs")

dir.create(for_analysis_dir, showWarnings = FALSE, recursive = TRUE)
dir.create(scripts_dir, showWarnings = FALSE, recursive = TRUE)
dir.create(docs_dir, showWarnings = FALSE, recursive = TRUE)

path_in <- function(file) here("for_analysis", file)
path_out <- function(file) here("for_analysis", file)
doc_out <- function(file) here("docs", file)

message("For analysis directory: ", for_analysis_dir)

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

assert_valid_states <- function(data, data_label, require_all = TRUE) {
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

  if (require_all && length(missing) > 0) {
    stop(
      data_label,
      " is missing state codes: ",
      paste(sort(missing), collapse = ", "),
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

parse_bool_strict <- function(x, label) {
  if (is.logical(x)) {
    return(x)
  }

  if (is.numeric(x)) {
    valid <- is.na(x) | x %in% c(0, 1)
    if (!all(valid)) {
      stop(label, " numeric values must be 0, 1, or NA.", call. = FALSE)
    }
    return(case_when(
      is.na(x) ~ NA,
      x == 1 ~ TRUE,
      x == 0 ~ FALSE
    ))
  }

  x_chr <- str_squish(str_to_lower(as.character(x)))
  x_chr[x_chr %in% c("", "na", "n/a", "missing", "unknown")] <- NA_character_

  true_values <- c("true", "t", "yes", "y", "1", "adopted", "expanded")
  false_values <- c(
    "false", "f", "no", "n", "0", "not adopted", "not expanded",
    "non-expansion", "non expansion"
  )

  valid <- is.na(x_chr) | x_chr %in% c(true_values, false_values)
  if (!all(valid)) {
    stop(
      label,
      " contains unsupported TRUE/FALSE values: ",
      paste(sort(unique(x_chr[!valid])), collapse = ", "),
      call. = FALSE
    )
  }

  case_when(
    is.na(x_chr) ~ NA,
    x_chr %in% true_values ~ TRUE,
    x_chr %in% false_values ~ FALSE
  )
}

parse_date_strict <- function(x, label) {
  if (inherits(x, "Date")) {
    return(x)
  }

  if (inherits(x, "POSIXt")) {
    return(as.Date(x))
  }

  x_chr <- str_squish(as.character(x))
  x_chr[x_chr %in% c("", "NA", "N/A", "na", "n/a", "missing", "unknown")] <- NA_character_
  non_missing <- x_chr[!is.na(x_chr)]

  if (length(non_missing) == 0) {
    return(as.Date(rep(NA_character_, length(x_chr))))
  }

  if (all(str_detect(non_missing, "^\\d{4}-\\d{2}-\\d{2}$"))) {
    parsed <- suppressWarnings(lubridate::ymd(x_chr))
    if (any(is.na(parsed) & !is.na(x_chr))) {
      stop(label, " contains unparseable ISO dates.", call. = FALSE)
    }
    return(as.Date(parsed))
  }

  parsers <- list(
    ymd = function(z) suppressWarnings(lubridate::ymd(z)),
    mdy = function(z) suppressWarnings(lubridate::mdy(z)),
    dmy = function(z) suppressWarnings(lubridate::dmy(z))
  )

  parsed_options <- map(parsers, ~ as.Date(.x(x_chr)))
  parses_all <- map_lgl(
    parsed_options,
    ~ all(!is.na(.x[!is.na(x_chr)]))
  )

  usable <- names(parsed_options)[parses_all]
  if (length(usable) == 0) {
    stop(
      label,
      " contains dates that could not be parsed. Use ISO YYYY-MM-DD dates.",
      call. = FALSE
    )
  }

  if (length(usable) > 1) {
    candidate_values <- parsed_options[usable]
    all_same <- reduce(candidate_values[-1], ~ .x & (.y == candidate_values[[1]]), .init = TRUE)
    if (!all(all_same | is.na(x_chr))) {
      stop(
        label,
        " has ambiguous non-ISO dates. Use ISO YYYY-MM-DD dates.",
        call. = FALSE
      )
    }
  }

  parsed_options[[usable[1]]]
}

read_clean_csv <- function(file, data_label) {
  full_path <- path_in(file)
  if (!file.exists(full_path)) {
    stop("Missing input file: ", full_path, call. = FALSE)
  }

  readr::read_csv(full_path, show_col_types = FALSE) |>
    janitor::clean_names()
}

make_quarter_start <- function(year, quarter) {
  quarter_month <- case_when(
    quarter == 1 ~ 1L,
    quarter == 2 ~ 4L,
    quarter == 3 ~ 7L,
    quarter == 4 ~ 10L,
    TRUE ~ NA_integer_
  )

  if (any(is.na(quarter_month))) {
    stop("quarter must be coded 1, 2, 3, or 4.", call. = FALSE)
  }

  lubridate::make_date(year = year, month = quarter_month, day = 1)
}

format_percent <- function(x, digits = 1) {
  paste0(round(100 * x, digits), "%")
}

sglt2_zero_fill_cols <- c(
  "sglt2_prescriptions",
  "sglt2_units",
  "sglt2_medicaid_reimbursed",
  "sglt2_total_reimbursed",
  "n_rows",
  "n_ndcs"
)

sglt2_rate_cols <- c(
  "sglt2_prescriptions_per_10000",
  "sglt2_units_per_10000",
  "sglt2_medicaid_reimbursed_per_10000",
  "sglt2_reimbursement_per_prescription"
)

# ------------------------------------------------------------
# 1. Load base SGLT2 state-quarter file
# ------------------------------------------------------------

print_section("1. Load base SGLT2 state-quarter file")

base <- read_clean_csv(input_files[["base_sglt2"]], "base SGLT2 file") |>
  mutate(
    state = str_to_upper(state),
    year = as.integer(year),
    quarter = as.integer(quarter)
  )

require_columns(base, c("state", "year", "quarter"), "base SGLT2 file")
require_columns(
  base,
  c(sglt2_zero_fill_cols, sglt2_rate_cols, "medicaid_enrolment_quarter_avg"),
  "base SGLT2 file"
)
assert_valid_states(base, "base SGLT2 file", require_all = TRUE)
assert_no_duplicate_keys(base, c("state", "year", "quarter"), "base SGLT2 file")

denominator_alias_cols <- intersect(
  c("medicaid_enrolment", "medicaid_enrolment_avg"),
  names(base)
)

if (length(denominator_alias_cols) > 0) {
  message(
    "Dropping denominator alias column(s) from base table before final master construction: ",
    paste(denominator_alias_cols, collapse = ", ")
  )
}

base <- base |>
  select(-any_of(denominator_alias_cols))

base <- base |>
  mutate(
    has_valid_medicaid_enrolment =
      !is.na(medicaid_enrolment_quarter_avg) & medicaid_enrolment_quarter_avg > 0
  )

non_positive_enrolment <- base |>
  filter(!is.na(medicaid_enrolment_quarter_avg), medicaid_enrolment_quarter_avg <= 0) |>
  select(state, year, quarter, medicaid_enrolment_quarter_avg)

if (nrow(non_positive_enrolment) > 0) {
  warning("Some state-quarters have non-positive Medicaid enrolment. Rates will be NA for these rows.")
  print(non_positive_enrolment, n = Inf)
}

sglt2_zero_fill_report <- map_dfr(
  sglt2_zero_fill_cols,
  function(var) {
    tibble(
      variable = var,
      n_missing_before = sum(is.na(base[[var]])),
      n_missing_with_valid_enrolment = sum(is.na(base[[var]]) & base$has_valid_medicaid_enrolment),
      n_missing_without_valid_enrolment = sum(is.na(base[[var]]) & !base$has_valid_medicaid_enrolment)
    )
  }
)

message("Missing SGLT2 outcome/count/reimbursement values before zero-fill:")
print(sglt2_zero_fill_report, n = Inf, width = Inf)

base <- base |>
  mutate(
    across(
      all_of(sglt2_zero_fill_cols),
      ~ if_else(has_valid_medicaid_enrolment & is.na(.x), 0, .x)
    ),
    sglt2_prescriptions_per_10000 = if_else(
      has_valid_medicaid_enrolment,
      sglt2_prescriptions / medicaid_enrolment_quarter_avg * 10000,
      NA_real_
    ),
    sglt2_units_per_10000 = if_else(
      has_valid_medicaid_enrolment,
      sglt2_units / medicaid_enrolment_quarter_avg * 10000,
      NA_real_
    ),
    sglt2_medicaid_reimbursed_per_10000 = if_else(
      has_valid_medicaid_enrolment,
      sglt2_medicaid_reimbursed / medicaid_enrolment_quarter_avg * 10000,
      NA_real_
    ),
    sglt2_reimbursement_per_prescription = case_when(
      is.na(sglt2_prescriptions) ~ NA_real_,
      sglt2_prescriptions == 0 ~ NA_real_,
      TRUE ~ sglt2_medicaid_reimbursed / sglt2_prescriptions
    )
  )

sglt2_zero_fill_remaining <- map_dfr(
  c(sglt2_zero_fill_cols, sglt2_rate_cols),
  function(var) {
    tibble(
      variable = var,
      n_missing_after = sum(is.na(base[[var]]))
    )
  }
)

message("Missing SGLT2 outcome/count/rate values after zero-fill and rate recalculation:")
print(sglt2_zero_fill_remaining, n = Inf, width = Inf)

zero_prescription_rows <- base |>
  filter(has_valid_medicaid_enrolment, sglt2_prescriptions == 0)

if (nrow(zero_prescription_rows) > 0) {
  message(
    "Rows with valid enrolment and zero SGLT2 prescriptions after zero-fill: ",
    nrow(zero_prescription_rows),
    ". `sglt2_reimbursement_per_prescription` is intentionally NA for these rows."
  )
  print(
    zero_prescription_rows |>
      select(state, year, quarter, medicaid_enrolment_quarter_avg, all_of(sglt2_zero_fill_cols), all_of(sglt2_rate_cols)),
    n = Inf,
    width = Inf
  )
}

base <- base |>
  select(-has_valid_medicaid_enrolment)

message("Base dimensions:")
print(dim(base))

message("Base column names:")
print(names(base))

message("Years included:")
print(sort(unique(base$year)))

message("State codes included:")
print(sort(unique(base$state)))

state_counts_yq <- base |>
  count(year, quarter, name = "n_states") |>
  arrange(year, quarter)

message("Number of states per year-quarter:")
print(state_counts_yq, n = Inf)

if (any(base$year == 2020)) {
  stop("Validation failed: 2020 is present in the base file.", call. = FALSE)
}

if (any(base$state %in% c("PR", "XX"))) {
  stop("Validation failed: PR and/or XX are present in the base file.", call. = FALSE)
}

bad_non_2025_counts <- state_counts_yq |>
  filter(year != 2025, n_states != 51)

if (nrow(bad_non_2025_counts) > 0) {
  message("Non-2025 year-quarters without 51 states + DC:")
  print(bad_non_2025_counts, n = Inf)
  stop("Validation failed: expected 51 states in all non-2025 year-quarters.", call. = FALSE)
}

partial_2025_counts <- state_counts_yq |>
  filter(year == 2025, n_states != 51)

if (nrow(partial_2025_counts) > 0) {
  warning("2025 appears partial by state count. This is allowed if due to enrolment availability.")
  print(partial_2025_counts, n = Inf)
}

# ------------------------------------------------------------
# 2. Create quarter dates
# ------------------------------------------------------------

print_section("2. Create quarter dates")

base <- base |>
  mutate(
    quarter_start_date = make_quarter_start(year, quarter),
    quarter_end_date = quarter_start_date %m+% months(3) - days(1)
  )

message("Quarter date check:")
print(
  base |>
    distinct(year, quarter, quarter_start_date, quarter_end_date) |>
    arrange(year, quarter),
  n = 12
)

# ------------------------------------------------------------
# 3. Load and prepare Medicaid expansion status
# ------------------------------------------------------------

print_section("3. Load and prepare Medicaid expansion status")

expansion_raw <- read_clean_csv(input_files[["medicaid_expansion"]], "Medicaid expansion file")

message("Medicaid expansion column names:")
print(names(expansion_raw))

require_columns(
  expansion_raw,
  c("state", "expansion_adopted", "expansion_effective_date"),
  "Medicaid expansion file"
)

expansion_state <- expansion_raw |>
  transmute(
    state = str_to_upper(state),
    medicaid_expansion_ever_adopted = parse_bool_strict(
      expansion_adopted,
      "expansion_adopted"
    ),
    medicaid_expansion_effective_date = parse_date_strict(
      expansion_effective_date,
      "expansion_effective_date"
    )
  ) |>
  mutate(
    medicaid_expansion_ever_adopted = as.integer(medicaid_expansion_ever_adopted)
  )

require_columns(
  expansion_state,
  c(
    "state",
    "medicaid_expansion_ever_adopted",
    "medicaid_expansion_effective_date"
  ),
  "prepared Medicaid expansion table"
)
assert_valid_states(expansion_state, "prepared Medicaid expansion table", require_all = TRUE)
assert_no_duplicate_keys(expansion_state, "state", "prepared Medicaid expansion table")

adopted_missing_dates <- expansion_state |>
  filter(medicaid_expansion_ever_adopted == 1, is.na(medicaid_expansion_effective_date))

if (nrow(adopted_missing_dates) > 0) {
  warning(
    "Expansion adopted but effective date missing for: ",
    paste(adopted_missing_dates$state, collapse = ", "),
    ". Active expansion variables will be NA for affected state-quarters."
  )
}

message("Prepared Medicaid expansion table:")
print(expansion_state, n = Inf)

# ------------------------------------------------------------
# 4. Load and prepare physician density
# ------------------------------------------------------------

print_section("4. Load and prepare physician density")

physician_raw <- read_clean_csv(input_files[["physician_density"]], "AHRF physician density file")

message("AHRF physician density column names:")
print(names(physician_raw))

physician_required <- c(
  "state",
  "population",
  "number_physicians",
  "physicians_per_100k",
  "number_primary_care_physicians",
  "primary_care_physicians_per_100k",
  "number_cvd_physicians",
  "cvd_physicians_per_100k"
)

require_columns(physician_raw, physician_required, "AHRF physician density file")

physician_state <- physician_raw |>
  transmute(
    state = str_to_upper(state),
    population_2023_ahrf = population,
    number_physicians_2023 = number_physicians,
    physicians_per_100k_2023 = physicians_per_100k,
    number_primary_care_physicians_2023 = number_primary_care_physicians,
    primary_care_physicians_per_100k_2023 = primary_care_physicians_per_100k,
    number_cvd_physicians_2023 = number_cvd_physicians,
    cvd_physicians_per_100k_2023 = cvd_physicians_per_100k
  )

assert_valid_states(physician_state, "prepared AHRF physician density table", require_all = TRUE)
assert_no_duplicate_keys(physician_state, "state", "prepared AHRF physician density table")

# ------------------------------------------------------------
# 5. Load and prepare CMS MMD disease burden
# ------------------------------------------------------------

print_section("5. Load and prepare CMS MMD disease burden")

disease_raw <- read_clean_csv(input_files[["disease_burden"]], "CMS MMD disease burden file")

message("CMS MMD disease burden column names:")
print(names(disease_raw))

disease_required <- c(
  "state",
  "medicare_ffs_hf_ihd_prevalence_2023",
  "medicare_ffs_diabetes_prevalence_2023",
  "medicare_ffs_ckd_prevalence_2023"
)

require_columns(disease_raw, disease_required, "CMS MMD disease burden file")

disease_state <- disease_raw |>
  transmute(
    state = str_to_upper(state),
    medicare_ffs_hf_ihd_prevalence_2023,
    medicare_ffs_diabetes_prevalence_2023,
    medicare_ffs_ckd_prevalence_2023
  )

assert_valid_states(disease_state, "prepared CMS MMD disease burden table", require_all = TRUE)
assert_no_duplicate_keys(disease_state, "state", "prepared CMS MMD disease burden table")

# ------------------------------------------------------------
# 6. Load and prepare SVI
# ------------------------------------------------------------

print_section("6. Load and prepare SVI")

svi_raw <- read_clean_csv(input_files[["svi"]], "SVI state aggregate file")

message("SVI column names:")
print(names(svi_raw))

svi_required <- c(
  "state",
  "svi_state",
  "svi_counties_used",
  "svi_population_weight",
  "svi_source_year",
  "svi_source"
)

require_columns(svi_raw, svi_required, "SVI state aggregate file")

svi_state <- svi_raw |>
  filter(svi_source_year == 2022) |>
  transmute(
    state = str_to_upper(state),
    svi_2022 = svi_state,
    svi_counties_used_2022 = svi_counties_used,
    svi_population_weight_2022 = svi_population_weight,
    svi_source_year = 2022L
  )

assert_valid_states(svi_state, "prepared 2022 SVI table", require_all = TRUE)
assert_no_duplicate_keys(svi_state, "state", "prepared 2022 SVI table")

# ------------------------------------------------------------
# 7. Load and prepare RUCC/rurality
# ------------------------------------------------------------

print_section("7. Load and prepare RUCC/rurality")

rucc_raw <- read_clean_csv(input_files[["rucc"]], "RUCC county file")

message("RUCC column names:")
print(names(rucc_raw))

rucc_required <- c("fips", "state", "county_name", "attribute", "value")
require_columns(rucc_raw, rucc_required, "RUCC county file")

rucc_raw <- rucc_raw |>
  mutate(state = str_to_upper(state))

rucc_excluded_states <- setdiff(unique(rucc_raw$state), valid_50dc)

if (length(rucc_excluded_states) > 0) {
  message(
    "Excluding RUCC rows outside 50 states + DC: ",
    paste(sort(rucc_excluded_states), collapse = ", ")
  )
}

rucc_raw_50dc <- rucc_raw |>
  filter(state %in% valid_50dc)

rucc_duplicates <- rucc_raw_50dc |>
  count(fips, state, county_name, attribute, name = "n") |>
  filter(n > 1)

if (nrow(rucc_duplicates) > 0) {
  message("Duplicate RUCC long-format rows:")
  print(rucc_duplicates, n = Inf)
  stop("RUCC county file has duplicate county-attribute rows.", call. = FALSE)
}

rucc_county <- rucc_raw_50dc |>
  mutate(
    attribute = str_squish(attribute)
  ) |>
  pivot_wider(names_from = attribute, values_from = value) |>
  janitor::clean_names() |>
  rename(rucc_description = description) |>
  mutate(
    population_2020 = readr::parse_number(as.character(population_2020)),
    rucc_2023 = readr::parse_number(as.character(rucc_2023))
  )

require_columns(
  rucc_county,
  c("fips", "state", "county_name", "population_2020", "rucc_2023", "rucc_description"),
  "reshaped RUCC county file"
)

assert_valid_states(rucc_county, "reshaped RUCC county file", require_all = TRUE)

invalid_rucc_values <- rucc_county |>
  filter(!is.na(rucc_2023), !(rucc_2023 %in% 1:9))

if (nrow(invalid_rucc_values) > 0) {
  message("Invalid RUCC values:")
  print(invalid_rucc_values, n = Inf)
  stop("RUCC values must be 1 through 9.", call. = FALSE)
}

missing_rucc_counties <- rucc_county |>
  filter(is.na(rucc_2023) | is.na(population_2020)) |>
  select(fips, state, county_name, population_2020, rucc_2023)

if (nrow(missing_rucc_counties) > 0) {
  warning("Some counties have missing RUCC or population values. They are printed for audit.")
  print(missing_rucc_counties, n = Inf)
}

rucc_state_summary <- rucc_county |>
  group_by(state) |>
  summarise(
    rucc_population_2020_total = sum(population_2020, na.rm = TRUE),
    rucc_nonmetro_population_2020 = sum(
      if_else(rucc_2023 >= 4 & rucc_2023 <= 9, population_2020, 0),
      na.rm = TRUE
    ),
    rucc_counties_total_2023 = n_distinct(fips),
    rucc_nonmetro_counties_2023 = sum(rucc_2023 >= 4 & rucc_2023 <= 9, na.rm = TRUE),
    rucc_nonmetro_county_share_2023 = rucc_nonmetro_counties_2023 / rucc_counties_total_2023,
    .groups = "drop"
  ) |>
  mutate(
    rucc_nonmetro_population_share_2023 =
      rucc_nonmetro_population_2020 / rucc_population_2020_total
  ) |>
  arrange(desc(rucc_nonmetro_population_share_2023)) |>
  mutate(
    rurality_quintile = ntile(desc(rucc_nonmetro_population_share_2023), 5),
    rurality_quintile_label = case_when(
      rurality_quintile == 1 ~ "Q1 most rural",
      rurality_quintile == 2 ~ "Q2",
      rurality_quintile == 3 ~ "Q3",
      rurality_quintile == 4 ~ "Q4",
      rurality_quintile == 5 ~ "Q5 most urban",
      TRUE ~ NA_character_
    )
  )

assert_valid_states(rucc_state_summary, "RUCC state rurality summary", require_all = TRUE)
assert_no_duplicate_keys(rucc_state_summary, "state", "RUCC state rurality summary")

rurality_membership <- rucc_state_summary |>
  select(
    state,
    rucc_nonmetro_population_share_2023,
    rucc_nonmetro_county_share_2023,
    rurality_quintile,
    rurality_quintile_label
  ) |>
  arrange(rurality_quintile, desc(rucc_nonmetro_population_share_2023), state)

rurality_quintile_summary <- rurality_membership |>
  group_by(rurality_quintile, rurality_quintile_label) |>
  summarise(
    n_states = n(),
    states = paste(state, collapse = ", "),
    min_nonmetro_share = min(rucc_nonmetro_population_share_2023, na.rm = TRUE),
    max_nonmetro_share = max(rucc_nonmetro_population_share_2023, na.rm = TRUE),
    .groups = "drop"
  ) |>
  arrange(rurality_quintile)

message("States by rurality quintile:")
rurality_quintile_summary |>
  mutate(
    line = paste0(
      rurality_quintile_label,
      " (",
      n_states,
      " states; nonmetro share ",
      round(min_nonmetro_share, 4),
      "-",
      round(max_nonmetro_share, 4),
      "): ",
      states
    )
  ) |>
  pull(line) |>
  walk(message)

print(
  rurality_quintile_summary,
  n = Inf,
  width = Inf
)

quintile_ranges <- rurality_membership |>
  group_by(rurality_quintile) |>
  summarise(
    min_share = min(rucc_nonmetro_population_share_2023, na.rm = TRUE),
    max_share = max(rucc_nonmetro_population_share_2023, na.rm = TRUE),
    .groups = "drop"
  ) |>
  arrange(rurality_quintile)

if (!identical(sort(unique(rurality_membership$rurality_quintile)), 1:5)) {
  stop("Rurality quintile must contain values 1 through 5.", call. = FALSE)
}

direction_ok <- all(quintile_ranges$min_share[-nrow(quintile_ranges)] >= quintile_ranges$max_share[-1])

if (!direction_ok) {
  message("Rurality quintile ranges:")
  print(quintile_ranges, n = Inf)
  stop(
    "Rurality quintile direction looks reversed or inconsistent. Q1 must have the highest nonmetro share.",
    call. = FALSE
  )
}

message("Rurality direction check passed: Q1 has the highest nonmetro population shares and Q5 the lowest.")

rucc_model_state <- rucc_state_summary |>
  select(
    state,
    rucc_nonmetro_population_share_2023,
    rurality_quintile,
    rurality_quintile_label
  )

# ------------------------------------------------------------
# 8. Census region/division
# ------------------------------------------------------------

print_section("8. Add Census region/division")

census_region_lookup <- tribble(
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
  mutate(
    census_region = factor(
      census_region,
      levels = c("Northeast", "Midwest", "South", "West")
    ),
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

assert_valid_states(census_region_lookup, "Census region/division lookup", require_all = TRUE)
assert_no_duplicate_keys(census_region_lookup, "state", "Census region/division lookup")

message("Census region/division state counts:")
print(
  census_region_lookup |>
    count(census_region, census_division, name = "n_states"),
  n = Inf
)

# ------------------------------------------------------------
# 9. Build final master table
# ------------------------------------------------------------

print_section("9. Build final master table")

master <- base |>
  left_join(expansion_state, by = "state") |>
  mutate(
    medicaid_expansion_active = case_when(
      medicaid_expansion_ever_adopted == 0 ~ 0L,
      medicaid_expansion_ever_adopted == 1 &
        !is.na(medicaid_expansion_effective_date) &
        quarter_start_date >= medicaid_expansion_effective_date ~ 1L,
      medicaid_expansion_ever_adopted == 1 &
        !is.na(medicaid_expansion_effective_date) &
        quarter_start_date < medicaid_expansion_effective_date ~ 0L,
      TRUE ~ NA_integer_
    ),
    medicaid_expansion_active_any_part_quarter = case_when(
      medicaid_expansion_ever_adopted == 0 ~ 0L,
      medicaid_expansion_ever_adopted == 1 &
        !is.na(medicaid_expansion_effective_date) &
        quarter_end_date >= medicaid_expansion_effective_date ~ 1L,
      medicaid_expansion_ever_adopted == 1 &
        !is.na(medicaid_expansion_effective_date) &
        quarter_end_date < medicaid_expansion_effective_date ~ 0L,
      TRUE ~ NA_integer_
    )
  ) |>
  left_join(physician_state, by = "state") |>
  left_join(disease_state, by = "state") |>
  left_join(svi_state, by = "state") |>
  left_join(rucc_model_state, by = "state") |>
  left_join(census_region_lookup, by = "state")

base_nonkey_cols <- setdiff(names(base), c("state", "year", "quarter", "quarter_start_date", "quarter_end_date"))

expansion_cols <- c(
  "medicaid_expansion_ever_adopted",
  "medicaid_expansion_effective_date",
  "medicaid_expansion_active",
  "medicaid_expansion_active_any_part_quarter"
)

structural_covariate_cols <- c(
  "rurality_quintile",
  "rurality_quintile_label",
  "rucc_nonmetro_population_share_2023",
  "census_region",
  "census_division",
  "svi_2022",
  "svi_counties_used_2022",
  "svi_population_weight_2022",
  "svi_source_year",
  "population_2023_ahrf",
  "number_physicians_2023",
  "physicians_per_100k_2023",
  "number_primary_care_physicians_2023",
  "primary_care_physicians_per_100k_2023",
  "number_cvd_physicians_2023",
  "cvd_physicians_per_100k_2023",
  "medicare_ffs_hf_ihd_prevalence_2023",
  "medicare_ffs_diabetes_prevalence_2023",
  "medicare_ffs_ckd_prevalence_2023"
)

master <- master |>
  select(
    state,
    year,
    quarter,
    quarter_start_date,
    quarter_end_date,
    all_of(base_nonkey_cols),
    all_of(expansion_cols),
    all_of(structural_covariate_cols),
    everything()
  ) |>
  arrange(year, quarter, state)

assert_no_duplicate_keys(master, c("state", "year", "quarter"), "final master table")

# ------------------------------------------------------------
# 10. Validation checks
# ------------------------------------------------------------

print_section("10. Validation checks")

message("Final master dimensions:")
print(dim(master))

message("Final master column names:")
print(names(master))

if (any(master$year == 2020)) {
  stop("Validation failed: 2020 is present in final master table.", call. = FALSE)
}
message("Validation passed: 2020 is absent.")

if (any(master$state %in% c("PR", "XX"))) {
  stop("Validation failed: PR and/or XX are present in final master table.", call. = FALSE)
}
message("Validation passed: PR and XX are absent.")

assert_valid_states(master, "final master table", require_all = TRUE)
assert_no_duplicate_keys(master, c("state", "year", "quarter"), "final master table")
message("Validation passed: no duplicate state-year-quarter rows.")

planned_analysis_required_cols <- c(
  "medicaid_enrolment_quarter_avg",
  "rucc_nonmetro_population_share_2023",
  "census_region",
  "sglt2_prescriptions_per_10000"
)

require_columns(
  master,
  planned_analysis_required_cols,
  "final master table"
)
message("Validation passed: planned analysis columns are present.")

forbidden_denominator_cols <- intersect(
  c("medicaid_enrolment", "medicaid_enrolment_avg"),
  names(master)
)

if (length(forbidden_denominator_cols) > 0) {
  stop(
    "Final master table must contain only `medicaid_enrolment_quarter_avg` as the Medicaid denominator. Remove: ",
    paste(forbidden_denominator_cols, collapse = ", "),
    call. = FALSE
  )
}
message("Validation passed: final master table has a single Medicaid denominator column.")

final_state_counts_yq <- master |>
  count(year, quarter, name = "n_states") |>
  arrange(year, quarter)

message("Final state count per year-quarter:")
print(final_state_counts_yq, n = Inf)

bad_final_non_2025_counts <- final_state_counts_yq |>
  filter(year != 2025, n_states != 51)

if (nrow(bad_final_non_2025_counts) > 0) {
  print(bad_final_non_2025_counts, n = Inf)
  stop("Validation failed: final table has non-2025 year-quarters without 51 states.", call. = FALSE)
}

covariate_cols <- c(expansion_cols, structural_covariate_cols)

missingness_report <- map_dfr(
  covariate_cols,
  function(var) {
    tibble(
      variable = var,
      n_missing = sum(is.na(master[[var]])),
      n_non_missing = sum(!is.na(master[[var]])),
      pct_missing = 100 * mean(is.na(master[[var]]))
    )
  }
) |>
  arrange(desc(n_missing), variable)

message("Missingness report for covariates:")
print(missingness_report, n = Inf, width = Inf)

key_covariates_for_missing_rows <- c(
  "medicaid_expansion_ever_adopted",
  "medicaid_expansion_active",
  "medicaid_expansion_active_any_part_quarter",
  structural_covariate_cols
)

rows_missing_key_covariates <- master |>
  filter(if_any(all_of(key_covariates_for_missing_rows), is.na)) |>
  select(state, year, quarter, all_of(key_covariates_for_missing_rows))

if (nrow(rows_missing_key_covariates) == 0) {
  message("No rows have missing key covariates.")
} else {
  message("Rows with missing key covariates:")
  print(rows_missing_key_covariates, n = 100)
}

message("Distribution of rurality quintiles and states:")
print(
  rurality_quintile_summary,
  n = Inf,
  width = Inf
)

rate_vars <- names(master) |>
  str_subset("sglt2.*(per_10000|rate)|rate")

if ("sglt2_prescriptions_per_10000" %in% names(master)) {
  sglt2_rate_summary <- master |>
    group_by(rurality_quintile, rurality_quintile_label) |>
    summarise(
      n_state_quarters = n(),
      mean_sglt2_prescriptions_per_10000 = mean(sglt2_prescriptions_per_10000, na.rm = TRUE),
      median_sglt2_prescriptions_per_10000 = median(sglt2_prescriptions_per_10000, na.rm = TRUE),
      p25_sglt2_prescriptions_per_10000 = quantile(sglt2_prescriptions_per_10000, 0.25, na.rm = TRUE),
      p75_sglt2_prescriptions_per_10000 = quantile(sglt2_prescriptions_per_10000, 0.75, na.rm = TRUE),
      .groups = "drop"
    )
} else if (length(rate_vars) > 0) {
  sglt2_rate_summary <- master |>
    group_by(rurality_quintile, rurality_quintile_label) |>
    summarise(
      n_state_quarters = n(),
      across(all_of(rate_vars), ~ mean(.x, na.rm = TRUE), .names = "mean_{.col}"),
      .groups = "drop"
    )
} else {
  sglt2_rate_summary <- tibble(note = "No SGLT2 rate variables identified.")
}

message("Summary of SGLT2 prescribing rates by rurality quintile:")
print(sglt2_rate_summary, n = Inf, width = Inf)

structural_state_summary_data <- master |>
  distinct(
    state,
    svi_2022,
    physicians_per_100k_2023,
    primary_care_physicians_per_100k_2023,
    cvd_physicians_per_100k_2023,
    medicare_ffs_hf_ihd_prevalence_2023,
    medicare_ffs_diabetes_prevalence_2023,
    medicare_ffs_ckd_prevalence_2023
  )

message("Summary of SVI, physician density, and disease burden variables:")
print(summary(structural_state_summary_data))

if (!identical(sort(unique(master$rurality_quintile)), 1:5)) {
  stop("Validation failed: rurality_quintile must have values 1 to 5.", call. = FALSE)
}
message("Validation passed: rurality_quintile has values 1 to 5.")

q1_min <- min(
  rurality_membership$rucc_nonmetro_population_share_2023[
    rurality_membership$rurality_quintile == 1
  ],
  na.rm = TRUE
)
q5_max <- max(
  rurality_membership$rucc_nonmetro_population_share_2023[
    rurality_membership$rurality_quintile == 5
  ],
  na.rm = TRUE
)

if (q1_min < q5_max) {
  stop("Validation failed: Q1 does not have higher nonmetro share than Q5.", call. = FALSE)
}
message("Validation passed: Q1 has higher nonmetro population share than Q5.")

# ------------------------------------------------------------
# 11. Outputs
# ------------------------------------------------------------

print_section("11. Outputs")

master_path <- path_out("master_state_quarter_sglt2_covariates_poc.csv")
rucc_summary_path <- path_out("rucc_state_rurality_2023.csv")
missingness_path <- path_out("master_poc_missingness_report.csv")
rurality_membership_path <- path_out("rurality_quintile_membership_2023.csv")
audit_log_path <- doc_out("2026-05-03_master_table_poc_log.md")

readr::write_csv(master, master_path)
readr::write_csv(rucc_state_summary, rucc_summary_path)
readr::write_csv(missingness_report, missingness_path)
readr::write_csv(rurality_membership, rurality_membership_path)

residual_issues <- c()

if (nrow(adopted_missing_dates) > 0) {
  residual_issues <- c(
    residual_issues,
    paste0(
      "States adopted expansion but have missing effective dates: ",
      paste(adopted_missing_dates$state, collapse = ", "),
      "."
    )
  )
}

if (nrow(missing_rucc_counties) > 0) {
  residual_issues <- c(
    residual_issues,
    paste0(
      "RUCC county rows with missing RUCC or population values: ",
      nrow(missing_rucc_counties),
      "."
    )
  )
}

key_missing_n <- nrow(rows_missing_key_covariates)
if (key_missing_n > 0) {
  residual_issues <- c(
    residual_issues,
    paste0("State-quarter rows with missing key covariates: ", key_missing_n, ".")
  )
}

sglt2_missing_without_valid_enrolment_n <- sglt2_zero_fill_report |>
  summarise(n = sum(n_missing_without_valid_enrolment)) |>
  pull(n)

if (sglt2_missing_without_valid_enrolment_n > 0) {
  residual_issues <- c(
    residual_issues,
    paste0(
      "Missing SGLT2 outcome/count/reimbursement values remain in state-quarters without valid Medicaid enrolment: ",
      sglt2_missing_without_valid_enrolment_n,
      "."
    )
  )
}

if (length(residual_issues) == 0) {
  residual_issues <- "No missing key covariates detected; review source definitions before final modelling."
}

year_2025_counts <- final_state_counts_yq |>
  filter(year == 2025)

year_2025_note <- if (nrow(year_2025_counts) == 0) {
  "- No 2025 quarters are present in the current analytic sample."
} else if (all(year_2025_counts$n_states == 51)) {
  "- Current 2025 quarter(s) have 51 jurisdictions."
} else {
  paste0(
    "- Some 2025 quarter(s) have fewer than 51 jurisdictions, which is allowed if due to enrolment availability: ",
    paste0(year_2025_counts$year, " Q", year_2025_counts$quarter, " = ", year_2025_counts$n_states, collapse = "; "),
    "."
  )
}

rucc_exclusion_note <- if (length(rucc_excluded_states) > 0) {
  paste0(
    "- RUCC source rows outside 50 states plus DC were excluded before state-level summarisation: ",
    paste(sort(rucc_excluded_states), collapse = ", "),
    "."
  )
} else {
  "- RUCC source contained only 50 states plus DC."
}

sglt2_zero_fill_md <- capture.output(
  sglt2_zero_fill_report |>
    print(n = Inf, width = Inf)
)

sglt2_zero_fill_remaining_md <- capture.output(
  sglt2_zero_fill_remaining |>
    print(n = Inf, width = Inf)
)

missingness_md <- capture.output(
  missingness_report |>
    mutate(pct_missing = round(pct_missing, 2)) |>
    print(n = Inf, width = Inf)
)

rurality_md <- capture.output(
  rurality_quintile_summary |>
    mutate(
      min_nonmetro_share = round(min_nonmetro_share, 4),
      max_nonmetro_share = round(max_nonmetro_share, 4)
    ) |>
    print(n = Inf, width = Inf)
)

audit_lines <- c(
  "# Master State-Quarter SGLT2 Merge Log",
  "",
  "Date: 2026-05-03",
  "",
  "## Purpose",
  "",
  "Create the master state-quarter analysis table for the Medicaid SDUD SGLT2 inhibitor uptake study. The base SGLT2 state-quarter table defines the analytic sample, and state-level covariates are joined onto that sample.",
  "",
  "## Input Files Used",
  "",
  paste0("- `for_analysis/", input_files, "`"),
  "",
  "## Join Keys Used",
  "",
  "- Base table key: `state`, `year`, `quarter`.",
  "- Medicaid expansion status joined by `state`, then evaluated against `quarter_start_date` and `quarter_end_date`.",
  "- AHRF physician density joined by `state`.",
  "- CMS Mapping Medicare Disparities disease burden joined by `state`.",
  "- SVI 2022 state aggregate joined by `state`.",
  "- RUCC 2023 rurality summary joined by `state`.",
  "- Census region/division joined by `state`.",
  "",
  "## Final Master Table",
  "",
  paste0("- Rows: ", nrow(master)),
  paste0("- Columns: ", ncol(master)),
  paste0("- Output: `for_analysis/", basename(master_path), "`"),
  "",
  "## Exclusions and Base Sample Checks",
  "",
  "- 2020 is absent from the base and final master table.",
  "- PR and XX are absent from the base and final master table.",
  "- The analytic sample contains only the 50 states plus DC.",
  rucc_exclusion_note,
  "- No duplicate `state`-`year`-`quarter` rows were detected.",
  "- Non-2025 year-quarters have 51 jurisdictions.",
  year_2025_note,
  "",
  "## Medicaid Expansion",
  "",
  "`medicaid_expansion_ever_adopted` and `medicaid_expansion_effective_date` were read from the Medicaid expansion file. `medicaid_expansion_active` equals 1 when the quarter start date is on or after the effective date. `medicaid_expansion_active_any_part_quarter` equals 1 when the quarter end date is on or after the effective date. Non-adopting states are coded 0 for active expansion variables in all quarters.",
  "",
  "## SGLT2 Outcome Zero-Fill and Rate Recalculation",
  "",
  "After loading the SGLT2 state-quarter table, missing SGLT2 outcome/count/reimbursement values are replaced with 0 only for state-quarters with valid Medicaid enrolment, defined as non-missing `medicaid_enrolment_quarter_avg` greater than 0. Medicaid enrolment and covariates are not zero-filled. SGLT2 rates are then recalculated using `medicaid_enrolment_quarter_avg` as the denominator. `sglt2_reimbursement_per_prescription` is set to NA when `sglt2_prescriptions == 0`.",
  "",
  "Before zero-fill:",
  "",
  "```",
  sglt2_zero_fill_md,
  "```",
  "",
  "After zero-fill and rate recalculation:",
  "",
  "```",
  sglt2_zero_fill_remaining_md,
  "```",
  "",
  "## RUCC Rurality",
  "",
  "County-level RUCC 2023 data were reshaped from long to wide format. Metro counties were defined as RUCC 1-3 and nonmetro counties as RUCC 4-9. State rurality is based on the proportion of the 2020 state population living in nonmetro counties. Rurality quintiles were created using `ntile(desc(rucc_nonmetro_population_share_2023), 5)`, so Q1 is most rural and Q5 is most urban.",
  "",
  "## Structural Covariates",
  "",
  "All non-expansion covariates are treated as fixed structural state-level covariates in this analysis table. Medicaid expansion is the only time-varying covariate.",
  "",
  "## Assumptions",
  "",
  "- Medicaid expansion is the only time-varying covariate in this master table.",
  "- Missing SGLT2 prescribing outcomes/counts/reimbursements are interpreted as zero only when valid Medicaid enrolment exists for that state-quarter.",
  "- AHRF physician density is treated as 2023 time-invariant structural access.",
  "- CMS MMD disease burden is treated as 2023 time-invariant disease burden.",
  "- SVI is treated as 2022 time-invariant social vulnerability.",
  "- RUCC is treated as 2023 time-invariant rurality.",
  "- Census region is treated as time-invariant geography.",
  "- RUCC state-level rurality is based on the proportion of the 2020 state population living in nonmetro counties, where nonmetro is defined as RUCC 4-9.",
  "- Disease burden is Medicare FFS-based and used as a state-level proxy, not Medicaid-specific prevalence.",
  "- HF/IHD is not pure heart failure prevalence. It is CMS MMD Heart Failure and Non-Ischemic Heart Disease prevalence.",
  "- The final master table contains `medicaid_enrolment_quarter_avg` as the only Medicaid denominator column.",
  "",
  "## Missingness Summary",
  "",
  "```",
  missingness_md,
  "```",
  "",
  "## Rurality Quintile Membership Summary",
  "",
  "```",
  rurality_md,
  "```",
  "",
  "## Residual Issues to Check Manually",
  "",
  paste0("- ", residual_issues),
  "",
  "## Derived Outputs",
  "",
  paste0("- `for_analysis/", basename(master_path), "`"),
  paste0("- `for_analysis/", basename(rucc_summary_path), "`"),
  paste0("- `for_analysis/", basename(missingness_path), "`"),
  paste0("- `for_analysis/", basename(rurality_membership_path), "`")
)

writeLines(audit_lines, audit_log_path)

message("Wrote final master table: ", master_path)
message("Wrote RUCC state summary: ", rucc_summary_path)
message("Wrote missingness report: ", missingness_path)
message("Wrote rurality quintile membership: ", rurality_membership_path)
message("Wrote audit markdown log: ", audit_log_path)

print_section("Complete")
