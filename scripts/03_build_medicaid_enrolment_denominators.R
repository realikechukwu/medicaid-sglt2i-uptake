if (!requireNamespace("here", quietly = TRUE)) {
  stop("Install the `here` package before running this script.", call. = FALSE)
}
source(here::here("scripts", "00_setup.R"))

enrolment_raw_file <- project_path(
  "data_raw",
  "medicaid_enrolment",
  "medicaid-enrollment-new-adult-group-02052026.csv"
)

state_quarter_file <- project_path(
  "data_processed",
  "enrolment",
  "medicaid_enrolment_state_quarter.csv"
)

state_year_file <- project_path(
  "data_processed",
  "enrolment",
  "medicaid_enrolment_state_year.csv"
)

if (!file.exists(enrolment_raw_file)) {
  stop(
    "Missing CMS Medicaid enrolment file: ",
    enrolment_raw_file,
    "\nManually download `medicaid-enrollment-new-adult-group-02052026.csv` from https://download.medicaid.gov/data/medicaid-enrollment-new-adult-group-02052026.csv.",
    call. = FALSE
  )
}

state_xwalk <- tibble::tibble(
  state_name = c(state.name, "District of Columbia"),
  state_abbr = valid_50dc
)

raw <- readr::read_csv(
  enrolment_raw_file,
  col_types = readr::cols(.default = readr::col_character()),
  show_col_types = FALSE
) |>
  janitor::clean_names()

require_columns(
  raw,
  c("state", "total_medicaid_enrollees", "enrollment_year", "enrollment_month"),
  "raw Medicaid enrolment file"
)

monthly <- raw |>
  dplyr::mutate(
    state_name = stringr::str_squish(stringr::str_remove(state, "[[:space:]]*[*]$")),
    state_name = dplyr::case_when(
      state_name %in% c("Dist. Of Col.", "District Of Columbia") ~ "District of Columbia",
      TRUE ~ state_name
    ),
    year = as.integer(enrollment_year),
    month = as.integer(enrollment_month),
    quarter = quarter_from_month(month),
    medicaid_enrolment_monthly = readr::parse_number(as.character(total_medicaid_enrollees))
  ) |>
  dplyr::inner_join(state_xwalk, by = "state_name") |>
  dplyr::filter(
    year %in% analysis_years,
    state_abbr %in% valid_50dc,
    !is.na(quarter)
  ) |>
  dplyr::transmute(state = state_abbr, year, quarter, month, medicaid_enrolment_monthly) |>
  dplyr::arrange(state, year, quarter, month)

assert_analysis_exclusions(monthly, "monthly Medicaid enrolment")
assert_no_duplicate_keys(monthly, c("state", "year", "month"), "monthly Medicaid enrolment")

state_quarter <- monthly |>
  dplyr::group_by(state, year, quarter) |>
  dplyr::summarise(
    medicaid_enrolment_quarter_avg = mean(medicaid_enrolment_monthly, na.rm = TRUE),
    n_enrolment_months = dplyr::n_distinct(month[!is.na(medicaid_enrolment_monthly)]),
    .groups = "drop"
  ) |>
  dplyr::arrange(state, year, quarter)

state_year <- monthly |>
  dplyr::group_by(state, year) |>
  dplyr::summarise(
    medicaid_enrolment_year_avg = mean(medicaid_enrolment_monthly, na.rm = TRUE),
    n_enrolment_months = dplyr::n_distinct(month[!is.na(medicaid_enrolment_monthly)]),
    .groups = "drop"
  ) |>
  dplyr::arrange(state, year)

assert_no_duplicate_keys(state_quarter, c("state", "year", "quarter"), "state-quarter Medicaid enrolment")
assert_no_duplicate_keys(state_year, c("state", "year"), "state-year Medicaid enrolment")
assert_valid_states(state_quarter, "state-quarter Medicaid enrolment")
assert_valid_states(state_year, "state-year Medicaid enrolment")

if (any(state_quarter$medicaid_enrolment_quarter_avg <= 0, na.rm = TRUE)) {
  stop("Non-positive `medicaid_enrolment_quarter_avg` found.", call. = FALSE)
}

safe_write_csv(state_quarter, state_quarter_file)
safe_write_csv(state_year, state_year_file)

message("Wrote Medicaid state-quarter denominators: ", state_quarter_file)
message("Wrote Medicaid state-year denominators: ", state_year_file)
