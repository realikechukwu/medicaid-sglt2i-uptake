# ============================================================
# Create state-year SGLT2 prescribing rates, 50 states + DC
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
# Notes:
#   The CMS MBES file reports monthly state Medicaid enrollee counts.
#   Annual denominators are constructed as the mean monthly Medicaid
#   enrollment within each state-year.
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

sglt2_main_file <- here(
  "data_processed",
  "sglt2_state_quarter_all_products_2015_2025.csv"
)

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

enrolment_clean_file <- here(
  "data_processed",
  "medicaid_enrolment_state_year.csv"
)

dir.create(here("data_processed"), showWarnings = FALSE)
dir.create(enrolment_raw_dir, recursive = TRUE, showWarnings = FALSE)

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

max_or_na <- function(x) {
  if (all(is.na(x))) {
    return(NA_real_)
  }
  max(x, na.rm = TRUE)
}

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

create_state_year_counts <- function(file_path) {
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

  state_year <- sglt2_quarterly %>%
    filter(
      year %in% analysis_years,
      year != 2020,
      state %in% valid_50dc
    ) %>%
    group_by(state, year) %>%
    summarise(
      sglt2_prescriptions = sum(sglt2_prescriptions, na.rm = TRUE),
      sglt2_units = sum(sglt2_units, na.rm = TRUE),
      sglt2_medicaid_reimbursed = sum(sglt2_medicaid_reimbursed, na.rm = TRUE),
      sglt2_total_reimbursed = sum(sglt2_total_reimbursed, na.rm = TRUE),
      n_quarters_observed = n_distinct(quarter),
      n_rows = sum(n_rows, na.rm = TRUE),
      n_ndcs = max_or_na(n_ndcs),
      .groups = "drop"
    ) %>%
    arrange(state, year)

  incomplete_quarters <- state_year %>%
    filter(n_quarters_observed != 4)

  if (nrow(incomplete_quarters) > 0) {
    print(incomplete_quarters)
    warning(
      basename(file_path),
      " has state-years with fewer or more than 4 quarters."
    )
  }

  state_counts <- state_year %>%
    count(year, name = "n_states") %>%
    filter(n_states != 51)

  if (nrow(state_counts) > 0) {
    print(state_counts)
    warning(
      basename(file_path),
      " does not have 51 states/DC in every analytic year."
    )
  }

  if (any(state_year$year == 2020)) {
    stop("2020 is present after filtering.")
  }

  if (any(state_year$state %in% c("PR", "XX"))) {
    stop("PR or XX is present after filtering.")
  }

  state_year
}

create_rate_file <- function(state_year_data, enrolment_data, output_file) {
  state_year_rates <- state_year_data %>%
    left_join(enrolment_data, by = c("state", "year")) %>%
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
    arrange(state, year)

  state_counts <- state_year_rates %>%
    count(year, name = "n_states") %>%
    filter(n_states != 51)

  if (nrow(state_counts) > 0) {
    print(state_counts)
    warning(output_file, " does not have 51 states/DC in every analytic year.")
  }

  if (any(state_year_rates$year == 2020)) {
    stop("2020 is present in ", output_file)
  }

  if (any(state_year_rates$state %in% c("PR", "XX"))) {
    stop("PR or XX is present in ", output_file)
  }

  missing_enrolment <- state_year_rates %>%
    filter(is.na(medicaid_enrolment)) %>%
    select(state, year)

  if (nrow(missing_enrolment) > 0) {
    print(missing_enrolment)
    stop("Missing Medicaid enrolment after merge for ", output_file)
  }

  message("Prescription rate distribution for ", basename(output_file), ":")
  print(summary(state_year_rates$sglt2_prescriptions_per_10000))

  write_csv(state_year_rates, output_file)

  state_year_rates
}

# ------------------------------------------------------------
# 2. Build Medicaid enrolment state-year denominator
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

medicaid_enrolment_monthly <- read_csv(
  enrolment_raw_file,
  col_types = cols(.default = col_character())
) %>%
  clean_names() %>%
  check_required_columns(
    c(
      "state",
      "total_medicaid_enrollees",
      "enrollment_year",
      "enrollment_month"
    ),
    enrolment_raw_file
  ) %>%
  mutate(
    state_name = str_squish(str_remove(state, "[[:space:]]*[*]$")),
    state_name = case_when(
      state_name %in% c("Dist. Of Col.", "District Of Columbia") ~
        "District of Columbia",
      TRUE ~ state_name
    ),
    year = as.integer(enrollment_year),
    month = as.integer(enrollment_month),
    medicaid_enrolment_monthly =
      parse_number(as.character(total_medicaid_enrollees))
  ) %>%
  inner_join(state_xwalk, by = "state_name") %>%
  filter(
    year %in% analysis_years,
    state_abbr %in% valid_50dc
  ) %>%
  select(
    state = state_abbr,
    year,
    month,
    medicaid_enrolment_monthly,
    raw_state_name = state_name
  ) %>%
  arrange(state, year, month)

duplicate_enrolment_rows <- medicaid_enrolment_monthly %>%
  count(state, year, month) %>%
  filter(n > 1)

if (nrow(duplicate_enrolment_rows) > 0) {
  print(duplicate_enrolment_rows)
  stop("Duplicate state-month rows in Medicaid enrolment source.")
}

medicaid_enrolment_state_year <- medicaid_enrolment_monthly %>%
  group_by(state, year) %>%
  summarise(
    medicaid_enrolment_avg = mean(medicaid_enrolment_monthly, na.rm = TRUE),
    medicaid_enrolment = medicaid_enrolment_avg,
    n_enrolment_months = n_distinct(month[!is.na(medicaid_enrolment_monthly)]),
    .groups = "drop"
  ) %>%
  arrange(state, year)

missing_enrolment_years <- expand_grid(
  state = valid_50dc,
  year = analysis_years
) %>%
  anti_join(medicaid_enrolment_state_year, by = c("state", "year"))

if (nrow(missing_enrolment_years) > 0) {
  print(missing_enrolment_years)
  stop("Missing state-year Medicaid enrolment denominators.")
}

incomplete_enrolment_years <- medicaid_enrolment_state_year %>%
  filter(n_enrolment_months != 12)

if (nrow(incomplete_enrolment_years) > 0) {
  print(incomplete_enrolment_years)
  warning(
    "Some Medicaid enrolment state-years have fewer than 12 monthly ",
    "observations. This is expected for 2025 in the current CMS MBES ",
    "release if only January-June 2025 are available."
  )
}

write_csv(medicaid_enrolment_state_year, enrolment_clean_file)

# ------------------------------------------------------------
# 3. Aggregate main SGLT2 quarterly outcome to state-year
# ------------------------------------------------------------

sglt2_state_year_all <- create_state_year_counts(sglt2_main_file)

write_csv(
  sglt2_state_year_all,
  here(
    "data_processed",
    "sglt2_state_year_all_products_50dc_excluding_2020.csv"
  )
)

# ------------------------------------------------------------
# 4. Merge enrolment and create main rate file
# ------------------------------------------------------------

sglt2_state_year_rates_all <- create_rate_file(
  sglt2_state_year_all,
  medicaid_enrolment_state_year,
  here(
    "data_processed",
    "sglt2_state_year_rates_all_products_50dc_excluding_2020.csv"
  )
)

# ------------------------------------------------------------
# 5. National yearly summary
# ------------------------------------------------------------

sglt2_national_yearly_rates <- sglt2_state_year_rates_all %>%
  group_by(year) %>%
  summarise(
    total_prescriptions = sum(sglt2_prescriptions, na.rm = TRUE),
    total_medicaid_enrolment = sum(medicaid_enrolment, na.rm = TRUE),
    national_prescriptions_per_10000 =
      total_prescriptions / total_medicaid_enrolment * 10000,
    .groups = "drop"
  ) %>%
  arrange(year)

print(sglt2_national_yearly_rates)

write_csv(
  sglt2_national_yearly_rates,
  here(
    "data_processed",
    "sglt2_national_yearly_rates_50dc_excluding_2020.csv"
  )
)

# ------------------------------------------------------------
# 6. Sensitivity rate files, if present
# ------------------------------------------------------------

sensitivity_files <- tribble(
  ~input_file, ~output_file,
  here(
    "data_processed",
    "sglt2_state_quarter_single_agent_2015_2025.csv"
  ),
  here(
    "data_processed",
    "sglt2_state_year_rates_single_agent_50dc_excluding_2020.csv"
  ),
  here(
    "data_processed",
    "sglt2_state_quarter_empa_dapa_2015_2025.csv"
  ),
  here(
    "data_processed",
    "sglt2_state_year_rates_empa_dapa_50dc_excluding_2020.csv"
  )
)

for (i in seq_len(nrow(sensitivity_files))) {
  input_file <- sensitivity_files$input_file[i]
  output_file <- sensitivity_files$output_file[i]

  if (file.exists(input_file)) {
    sensitivity_state_year <- create_state_year_counts(input_file)

    create_rate_file(
      sensitivity_state_year,
      medicaid_enrolment_state_year,
      output_file
    )
  } else {
    warning("Sensitivity file not found, skipping: ", input_file)
  }
}

message("Done creating state-year SGLT2 prescribing rate datasets.")
