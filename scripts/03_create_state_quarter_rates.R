# ============================================================
# Create state-quarter SGLT2 prescribing rates, 50 states + DC
# ============================================================
#
# SDUD outcome source:
#   data_processed/sglt2_state_quarter_all_products_2015_2025.csv
#
# Medicaid enrolment source:
#   CMS Data.Medicaid.gov, "Medicaid Enrollment - New Adult Group"
#   Download URL:
#   https://download.medicaid.gov/data/medicaid-enrollment-new-adult-group-02052026.csv
#   Dataset landing/API identifier:
#   https://data.medicaid.gov/dataset/6c114b2c-cb83-559b-832f-4d8b06d6c1b9
#   Download date for this project script: 2026-04-25
#
# Denominator:
#   Uses Total Medicaid Enrollees. Does not use Total VIII Group Enrollees
#   or any VIII/new adult group columns.
# ============================================================

library(tidyverse)
library(here)
library(janitor)
library(readr)

# ------------------------------------------------------------
# 0. Paths and settings
# ------------------------------------------------------------

analysis_years <- c(2015:2019, 2021:2025)
valid_50dc <- c(state.abb, "DC")

enrolment_url <- paste0(
  "https://download.medicaid.gov/data/",
  "medicaid-enrollment-new-adult-group-02052026.csv"
)

enrolment_raw_dir <- here("data_raw", "medicaid_enrolment")
enrolment_raw_file <- here(
  "data_raw",
  "medicaid_enrolment",
  "medicaid-enrollment-new-adult-group-02052026.csv"
)

enrolment_quarterly_file <- here(
  "data_processed",
  "medicaid_enrolment_state_quarter.csv"
)

sglt2_main_file <- here(
  "data_processed",
  "sglt2_state_quarter_all_products_2015_2025.csv"
)

analysis_output_dir <- here("for_analysis")

dir.create(here("data_processed"), showWarnings = FALSE)
dir.create(enrolment_raw_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(analysis_output_dir, showWarnings = FALSE)

# ------------------------------------------------------------
# 1. Helper functions
# ------------------------------------------------------------

required_sglt2_cols <- c(
  "state",
  "year",
  "quarter",
  "sglt2_prescriptions",
  "sglt2_units",
  "sglt2_medicaid_reimbursed",
  "sglt2_total_reimbursed",
  "n_rows",
  "n_ndcs"
)

required_enrolment_cols <- c(
  "state",
  "total_medicaid_enrollees",
  "enrollment_year",
  "enrollment_month"
)

check_required_columns <- function(data, required_cols, file_path) {
  missing_cols <- setdiff(required_cols, names(data))

  if (length(missing_cols) > 0) {
    stop(
      "Missing required column(s) in ",
      file_path,
      ": ",
      paste(missing_cols, collapse = ", ")
    )
  }

  invisible(data)
}

copy_for_analysis <- function(file_path) {
  if (!file.exists(file_path)) {
    warning("Cannot copy missing analysis file: ", file_path)
    return(invisible(FALSE))
  }

  file.copy(
    from = file_path,
    to = file.path(analysis_output_dir, basename(file_path)),
    overwrite = TRUE
  )
}

quarter_from_month <- function(month) {
  case_when(
    month %in% 1:3 ~ 1L,
    month %in% 4:6 ~ 2L,
    month %in% 7:9 ~ 3L,
    month %in% 10:12 ~ 4L,
    TRUE ~ NA_integer_
  )
}

read_sglt2_quarterly <- function(file_path) {
  if (!file.exists(file_path)) {
    stop("SGLT2 file does not exist: ", file_path)
  }

  sglt2_quarterly <- read_csv(
    file_path,
    show_col_types = FALSE
  ) %>%
    clean_names()

  check_required_columns(sglt2_quarterly, required_sglt2_cols, file_path)

  sglt2_quarterly %>%
    mutate(
      state = as.character(state),
      year = as.integer(year),
      quarter = as.integer(quarter)
    )
}

prepare_sglt2_quarterly <- function(file_path, enrolment_data) {
  sglt2_quarterly <- read_sglt2_quarterly(file_path)

  message("Available years in ", basename(file_path), ":")
  print(sort(unique(sglt2_quarterly$year)))

  message("Available state/reporting codes in ", basename(file_path), ":")
  print(sort(unique(sglt2_quarterly$state)))

  non_state_codes <- setdiff(sort(unique(sglt2_quarterly$state)), valid_50dc)

  if (length(non_state_codes) > 0) {
    message(
      "Codes excluded from analytic sample: ",
      paste(non_state_codes, collapse = ", ")
    )
  }

  sglt2_filtered <- sglt2_quarterly %>%
    filter(
      year %in% analysis_years,
      year != 2020,
      state %in% valid_50dc
    )

  if (any(sglt2_filtered$state %in% c("PR", "XX"))) {
    stop("PR or XX is present after SGLT2 filtering.")
  }

  if (any(sglt2_filtered$year == 2020)) {
    stop("2020 is present after SGLT2 filtering.")
  }

  available_enrolment_quarters <- enrolment_data %>%
    distinct(year, quarter)

  analysis_grid <- available_enrolment_quarters %>%
    crossing(state = valid_50dc) %>%
    select(state, year, quarter) %>%
    arrange(state, year, quarter)

  sglt2_without_enrolment <- sglt2_filtered %>%
    distinct(year, quarter) %>%
    anti_join(available_enrolment_quarters, by = c("year", "quarter")) %>%
    arrange(year, quarter)

  if (nrow(sglt2_without_enrolment) > 0) {
    print(sglt2_without_enrolment)
    warning(
      basename(file_path),
      " has SGLT2 year-quarters without Medicaid enrolment denominators. ",
      "These year-quarters are excluded from the rate file."
    )
  }

  sglt2_for_available_quarters <- sglt2_filtered %>%
    semi_join(available_enrolment_quarters, by = c("year", "quarter"))

  absent_sglt2_state_quarters <- analysis_grid %>%
    anti_join(
      sglt2_for_available_quarters %>% distinct(state, year, quarter),
      by = c("state", "year", "quarter")
    )

  if (nrow(absent_sglt2_state_quarters) > 0) {
    message(
      "Filling ",
      nrow(absent_sglt2_state_quarters),
      " absent SGLT2 state-quarter rows as zero utilization for ",
      basename(file_path),
      ". Existing rows with missing SDUD utilization values are preserved as missing."
    )
  }

  sglt2_analysis <- analysis_grid %>%
    left_join(
      sglt2_for_available_quarters,
      by = c("state", "year", "quarter")
    ) %>%
    mutate(
      has_sglt2_row = !is.na(n_rows),
      sglt2_prescriptions = if_else(
        has_sglt2_row,
        sglt2_prescriptions,
        0
      ),
      sglt2_units = if_else(has_sglt2_row, sglt2_units, 0),
      sglt2_medicaid_reimbursed = if_else(
        has_sglt2_row,
        sglt2_medicaid_reimbursed,
        0
      ),
      sglt2_total_reimbursed = if_else(
        has_sglt2_row,
        sglt2_total_reimbursed,
        0
      ),
      n_rows = replace_na(n_rows, 0),
      n_ndcs = replace_na(n_ndcs, 0)
    ) %>%
    select(-has_sglt2_row) %>%
    arrange(state, year, quarter)

  jurisdiction_counts <- sglt2_analysis %>%
    count(year, quarter, name = "n_jurisdictions") %>%
    filter(n_jurisdictions != 51)

  if (nrow(jurisdiction_counts) > 0) {
    print(jurisdiction_counts)
    warning(
      basename(file_path),
      " does not have 51 jurisdictions in every included year-quarter."
    )
  }

  sglt2_analysis
}

create_rate_file <- function(sglt2_quarterly, enrolment_data, output_file) {
  state_quarter_rates <- sglt2_quarterly %>%
    left_join(enrolment_data, by = c("state", "year", "quarter")) %>%
    mutate(
      sglt2_prescriptions_per_10000 =
        sglt2_prescriptions / medicaid_enrolment * 10000,
      sglt2_units_per_10000 =
        sglt2_units / medicaid_enrolment * 10000,
      sglt2_medicaid_reimbursed_per_10000 =
        sglt2_medicaid_reimbursed / medicaid_enrolment * 10000,
      sglt2_reimbursement_per_prescription =
        if_else(
          sglt2_prescriptions > 0,
          sglt2_medicaid_reimbursed / sglt2_prescriptions,
          NA_real_
        )
    ) %>%
    arrange(state, year, quarter)

  if (any(state_quarter_rates$year == 2020)) {
    stop("2020 is present in ", output_file)
  }

  if (any(state_quarter_rates$state %in% c("PR", "XX"))) {
    stop("PR or XX is present in ", output_file)
  }

  missing_enrolment <- state_quarter_rates %>%
    filter(is.na(medicaid_enrolment)) %>%
    select(state, year, quarter)

  if (nrow(missing_enrolment) > 0) {
    print(missing_enrolment)
    stop("Missing Medicaid enrolment after merge for ", output_file)
  }

  jurisdiction_counts <- state_quarter_rates %>%
    count(year, quarter, name = "n_jurisdictions") %>%
    filter(n_jurisdictions != 51)

  if (nrow(jurisdiction_counts) > 0) {
    print(jurisdiction_counts)
    warning(output_file, " does not have 51 jurisdictions in every quarter.")
  }

  enrolment_month_check <- state_quarter_rates %>%
    distinct(state, year, quarter, n_enrolment_months) %>%
    filter(n_enrolment_months < 3)

  if (nrow(enrolment_month_check) > 0) {
    print(enrolment_month_check)
    warning(output_file, " has quarters with fewer than 3 enrolment months.")
  }

  message("Prescription rate distribution for ", basename(output_file), ":")
  print(summary(state_quarter_rates$sglt2_prescriptions_per_10000))

  write_csv(state_quarter_rates, output_file)

  state_quarter_rates
}

# ------------------------------------------------------------
# 2. Build Medicaid enrolment state-quarter denominator
# ------------------------------------------------------------

if (!file.exists(enrolment_raw_file)) {
  message("Downloading CMS MBES Medicaid enrolment file...")

  download_status <- tryCatch(
    {
      download.file(
        enrolment_url,
        enrolment_raw_file,
        mode = "wb",
        quiet = FALSE
      )
      TRUE
    },
    error = function(e) {
      message("Download failed: ", conditionMessage(e))
      FALSE
    }
  )

  if (!download_status) {
    stop(
      "Could not download the CMS MBES enrolment file. ",
      "Manually download ",
      enrolment_url,
      " to ",
      enrolment_raw_file,
      ". Expected columns include State, Total Medicaid Enrollees, ",
      "Enrollment Year, and Enrollment Month."
    )
  }
}

state_xwalk <- tibble(
  state_name = c(state.name, "District of Columbia"),
  state_abbr = valid_50dc
)

medicaid_enrolment_raw <- read_csv(
  enrolment_raw_file,
  col_types = cols(.default = col_character())
) %>%
  clean_names()

check_required_columns(
  medicaid_enrolment_raw,
  required_enrolment_cols,
  enrolment_raw_file
)

medicaid_enrolment_monthly <- medicaid_enrolment_raw %>%
  mutate(
    state_name = str_squish(str_remove(state, "[[:space:]]*[*]$")),
    state_name = case_when(
      state_name %in% c("Dist. Of Col.", "District Of Columbia") ~
        "District of Columbia",
      TRUE ~ state_name
    ),
    year = as.integer(enrollment_year),
    month = as.integer(enrollment_month),
    quarter = quarter_from_month(month),
    medicaid_enrolment_monthly =
      parse_number(as.character(total_medicaid_enrollees))
  ) %>%
  inner_join(state_xwalk, by = "state_name") %>%
  filter(
    year %in% analysis_years,
    year != 2020,
    state_abbr %in% valid_50dc,
    !is.na(quarter)
  ) %>%
  transmute(
    state = state_abbr,
    year,
    quarter,
    month,
    medicaid_enrolment_monthly
  ) %>%
  arrange(state, year, quarter, month)

duplicate_enrolment_rows <- medicaid_enrolment_monthly %>%
  count(state, year, month) %>%
  filter(n > 1)

if (nrow(duplicate_enrolment_rows) > 0) {
  print(duplicate_enrolment_rows)
  stop("Duplicate state-year-month rows in Medicaid enrolment source.")
}

if (any(medicaid_enrolment_monthly$year == 2020)) {
  stop("2020 is present in Medicaid enrolment denominator.")
}

if (any(medicaid_enrolment_monthly$state %in% c("PR", "XX"))) {
  stop("PR or XX is present in Medicaid enrolment denominator.")
}

medicaid_enrolment_state_quarter <- medicaid_enrolment_monthly %>%
  group_by(state, year, quarter) %>%
  summarise(
    medicaid_enrolment_quarter_avg =
      mean(medicaid_enrolment_monthly, na.rm = TRUE),
    medicaid_enrolment = medicaid_enrolment_quarter_avg,
    n_enrolment_months = n_distinct(month[!is.na(medicaid_enrolment_monthly)]),
    .groups = "drop"
  ) %>%
  arrange(state, year, quarter)

duplicate_enrolment_quarters <- medicaid_enrolment_state_quarter %>%
  count(state, year, quarter) %>%
  filter(n > 1)

if (nrow(duplicate_enrolment_quarters) > 0) {
  print(duplicate_enrolment_quarters)
  stop("Duplicate state-year-quarter rows in Medicaid enrolment denominator.")
}

incomplete_enrolment_quarters <- medicaid_enrolment_state_quarter %>%
  filter(n_enrolment_months < 3)

if (nrow(incomplete_enrolment_quarters) > 0) {
  print(incomplete_enrolment_quarters)
  warning("Some Medicaid enrolment state-quarters have fewer than 3 months.")
}

enrolment_jurisdiction_counts <- medicaid_enrolment_state_quarter %>%
  count(year, quarter, name = "n_jurisdictions") %>%
  arrange(year, quarter)

print(enrolment_jurisdiction_counts)

bad_enrolment_jurisdiction_counts <- enrolment_jurisdiction_counts %>%
  filter(n_jurisdictions != 51)

if (nrow(bad_enrolment_jurisdiction_counts) > 0) {
  print(bad_enrolment_jurisdiction_counts)
  warning(
    "Some Medicaid enrolment year-quarters do not have 51 jurisdictions."
  )
}

expected_year_quarters <- expand_grid(
  year = analysis_years,
  quarter = 1:4
)

missing_enrolment_year_quarters <- expected_year_quarters %>%
  anti_join(
    medicaid_enrolment_state_quarter %>% distinct(year, quarter),
    by = c("year", "quarter")
  ) %>%
  arrange(year, quarter)

if (nrow(missing_enrolment_year_quarters) > 0) {
  print(missing_enrolment_year_quarters)

  unexpected_missing <- missing_enrolment_year_quarters %>%
    filter(!(year == 2025 & quarter %in% c(3L, 4L)))

  if (nrow(unexpected_missing) > 0) {
    stop("Unexpected missing Medicaid enrolment year-quarters.")
  }

  warning(
    "Medicaid enrolment denominators are unavailable for the listed ",
    "year-quarters. These are expected for 2025 Q3/Q4 in the current ",
    "CMS MBES release and are excluded from rate outputs."
  )
}

write_csv(medicaid_enrolment_state_quarter, enrolment_quarterly_file)

# ------------------------------------------------------------
# 3. Main all-products quarterly rate file
# ------------------------------------------------------------

sglt2_quarterly_all <- prepare_sglt2_quarterly(
  sglt2_main_file,
  medicaid_enrolment_state_quarter
)

sglt2_state_quarter_rates_all <- create_rate_file(
  sglt2_quarterly_all,
  medicaid_enrolment_state_quarter,
  here(
    "data_processed",
    "sglt2_state_quarter_rates_all_products_50dc_excluding_2020.csv"
  )
)

# ------------------------------------------------------------
# 4. National quarterly summary
# ------------------------------------------------------------

sglt2_national_quarterly_rates <- sglt2_state_quarter_rates_all %>%
  group_by(year, quarter) %>%
  summarise(
    total_prescriptions = sum(sglt2_prescriptions, na.rm = TRUE),
    total_medicaid_enrolment = sum(medicaid_enrolment, na.rm = TRUE),
    national_prescriptions_per_10000 =
      total_prescriptions / total_medicaid_enrolment * 10000,
    .groups = "drop"
  ) %>%
  arrange(year, quarter)

message("National quarterly SGLT2 prescription rate summary:")
print(sglt2_national_quarterly_rates, n = Inf)

write_csv(
  sglt2_national_quarterly_rates,
  here(
    "data_processed",
    "sglt2_national_quarterly_rates_50dc_excluding_2020.csv"
  )
)

# ------------------------------------------------------------
# 5. Sensitivity quarterly rate files, if present
# ------------------------------------------------------------

sensitivity_files <- tribble(
  ~input_file, ~output_file,
  here(
    "data_processed",
    "sglt2_state_quarter_single_agent_2015_2025.csv"
  ),
  here(
    "data_processed",
    "sglt2_state_quarter_rates_single_agent_50dc_excluding_2020.csv"
  ),
  here(
    "data_processed",
    "sglt2_state_quarter_empa_dapa_2015_2025.csv"
  ),
  here(
    "data_processed",
    "sglt2_state_quarter_rates_empa_dapa_50dc_excluding_2020.csv"
  )
)

for (i in seq_len(nrow(sensitivity_files))) {
  input_file <- sensitivity_files$input_file[i]
  output_file <- sensitivity_files$output_file[i]

  if (file.exists(input_file)) {
    sensitivity_quarterly <- prepare_sglt2_quarterly(
      input_file,
      medicaid_enrolment_state_quarter
    )

    create_rate_file(
      sensitivity_quarterly,
      medicaid_enrolment_state_quarter,
      output_file
    )
  } else {
    warning("Sensitivity file not found, skipping: ", input_file)
  }
}

analysis_ready_files <- c(
  here(
    "data_processed",
    "sglt2_state_quarter_rates_all_products_50dc_excluding_2020.csv"
  ),
  here(
    "data_processed",
    "sglt2_state_quarter_rates_single_agent_50dc_excluding_2020.csv"
  ),
  here(
    "data_processed",
    "sglt2_state_quarter_rates_empa_dapa_50dc_excluding_2020.csv"
  ),
  here(
    "data_processed",
    "sglt2_national_quarterly_rates_50dc_excluding_2020.csv"
  )
)

walk(analysis_ready_files, copy_for_analysis)

message("Done creating state-quarter SGLT2 prescribing rate datasets.")
