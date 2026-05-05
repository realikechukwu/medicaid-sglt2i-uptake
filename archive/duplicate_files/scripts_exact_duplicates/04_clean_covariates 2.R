if (!requireNamespace("here", quietly = TRUE)) {
  stop("Install the `here` package before running this script.", call. = FALSE)
}
source(here::here("scripts", "00_setup.R"))

output_dir <- project_path("data_processed", "covariates")
ensure_dir(output_dir)

state_xwalk <- tibble::tibble(
  state_name = c(state.name, "District of Columbia"),
  state = valid_50dc
)

read_clean_csv <- function(path, label) {
  require_files(path, label)
  readr::read_csv(path, show_col_types = FALSE) |>
    janitor::clean_names()
}

classify_ahrf_file <- function(file_path) {
  preview <- readxl::read_excel(file_path, sheet = "AHRF Geo Data", col_names = FALSE, n_max = 4)
  text <- preview |>
    dplyr::mutate(dplyr::across(dplyr::everything(), as.character)) |>
    tidyr::unite("text", dplyr::everything(), sep = " | ", na.rm = TRUE) |>
    dplyr::pull(text) |>
    paste(collapse = " | ") |>
    stringr::str_to_lower()

  dplyr::case_when(
    stringr::str_detect(text, "cardiovascular disease") ~ "cvd_physicians",
    stringr::str_detect(text, "primary care") ~ "primary_care_physicians",
    stringr::str_detect(text, "all m[.]d|all md|all m d") ~ "physicians",
    TRUE ~ NA_character_
  )
}

read_one_ahrf_file <- function(file_path) {
  physician_type <- classify_ahrf_file(file_path)
  if (is.na(physician_type)) {
    stop("Could not classify AHRF physician type for: ", basename(file_path), call. = FALSE)
  }

  dat <- readxl::read_excel(file_path, sheet = "AHRF Geo Data", skip = 3) |>
    janitor::clean_names()

  state_col <- names(dat)[stringr::str_detect(names(dat), "^state")]
  pop_col <- names(dat)[stringr::str_detect(names(dat), "^population")]
  rate_col <- names(dat)[stringr::str_detect(names(dat), "^rate")]
  source_col <- names(dat)[stringr::str_detect(names(dat), "^source")]
  count_col <- setdiff(names(dat), c(state_col, pop_col, rate_col, source_col))
  count_col <- count_col[!stringr::str_detect(count_col, "^x[0-9]+$|^[.][.][.]")]

  if (length(state_col) != 1 || length(pop_col) != 1 || length(rate_col) != 1 || length(count_col) != 1) {
    stop("Unexpected AHRF column structure in: ", basename(file_path), call. = FALSE)
  }

  dat |>
    dplyr::transmute(
      state_name = stringr::str_squish(as.character(.data[[state_col]])),
      population = as.numeric(.data[[pop_col]]),
      "{paste0('number_', physician_type)}" := as.numeric(.data[[count_col]]),
      "{paste0(physician_type, '_per_100k')}" := as.numeric(.data[[rate_col]]),
      "{paste0(physician_type, '_source')}" :=
        if (length(source_col) == 1) as.character(.data[[source_col]]) else NA_character_
    ) |>
    dplyr::inner_join(state_xwalk, by = "state_name") |>
    dplyr::select(state, state_name, population, dplyr::everything())
}

ahrf_files <- list.files(
  project_path("data_raw", "covariates", "ahrf"),
  pattern = "AHRFDashboard.*[.]xlsx$",
  full.names = TRUE
)

if (length(ahrf_files) == 0) {
  stop("No AHRF dashboard Excel files found in `data_raw/covariates/ahrf/`.", call. = FALSE)
}

ahrf_state <- purrr::map(ahrf_files, read_one_ahrf_file) |>
  purrr::reduce(function(x, y) {
    dplyr::left_join(x, y |> dplyr::select(-state_name, -population), by = "state")
  }) |>
  dplyr::filter(state %in% valid_50dc) |>
  dplyr::arrange(state) |>
  dplyr::select(
    state,
    state_name,
    population,
    number_physicians,
    physicians_per_100k,
    number_primary_care_physicians,
    primary_care_physicians_per_100k,
    number_cvd_physicians,
    cvd_physicians_per_100k,
    dplyr::everything()
  )

assert_valid_states(ahrf_state, "AHRF physician density")
assert_no_duplicate_keys(ahrf_state, "state", "AHRF physician density")

safe_write_csv(
  ahrf_state,
  project_path("data_processed", "covariates", "ahrf_physician_density_2023_50dc.csv")
)

clean_mmd_file <- function(path) {
  dat <- read_clean_csv(path, basename(path))
  require_columns(
    dat,
    c("population", "year", "condition", "state", "primary_value", "primary_denominator", "measure", "adjustment"),
    basename(path)
  )

  dat |>
    dplyr::mutate(
      state_name = stringr::str_squish(stringr::str_to_upper(state)),
      source_year = as.integer(year),
      value = as.numeric(primary_value)
    ) |>
    dplyr::inner_join(
      tibble::tibble(
        state_name = stringr::str_to_upper(c(state.name, "District of Columbia")),
        state_abbr = valid_50dc
      ),
      by = "state_name"
    ) |>
    dplyr::transmute(
      state = state_abbr,
      source_year,
      value,
      condition,
      population_source = population,
      measure,
      adjustment,
      denominator_category = primary_denominator
    ) |>
    dplyr::arrange(state)
}

hf <- clean_mmd_file(project_path("data_raw", "covariates", "mmd", "mmd_data_hf_ihd.csv")) |>
  dplyr::rename(medicare_ffs_hf_ihd_prevalence_2023 = value)
dm <- clean_mmd_file(project_path("data_raw", "covariates", "mmd", "mmd_data_dm.csv")) |>
  dplyr::rename(medicare_ffs_diabetes_prevalence_2023 = value)
ckd <- clean_mmd_file(project_path("data_raw", "covariates", "mmd", "mmd_data_ckd.csv")) |>
  dplyr::rename(medicare_ffs_ckd_prevalence_2023 = value)

mmd_state <- hf |>
  dplyr::select(state, source_year, medicare_ffs_hf_ihd_prevalence_2023) |>
  dplyr::left_join(dm |> dplyr::select(state, medicare_ffs_diabetes_prevalence_2023), by = "state") |>
  dplyr::left_join(ckd |> dplyr::select(state, medicare_ffs_ckd_prevalence_2023), by = "state") |>
  dplyr::mutate(
    disease_burden_source = "CMS Mapping Medicare Disparities, Medicare FFS, 2023",
    disease_burden_measure = "Prevalence percentage; unsmoothed age-standardized estimate"
  ) |>
  dplyr::arrange(state)

assert_valid_states(mmd_state, "MMD disease burden")
assert_no_duplicate_keys(mmd_state, "state", "MMD disease burden")

safe_write_csv(
  mmd_state,
  project_path("data_processed", "covariates", "mmd_disease_burden_2023_50dc.csv")
)

rucc_raw <- read_clean_csv(
  project_path("data_raw", "covariates", "rucc", "Ruralurbancontinuumcodes2023.csv"),
  "RUCC 2023 county file"
)

require_columns(rucc_raw, c("fips", "state", "county_name", "attribute", "value"), "RUCC 2023 county file")

rucc_county <- rucc_raw |>
  dplyr::mutate(state = stringr::str_to_upper(state), attribute = stringr::str_squish(attribute)) |>
  dplyr::filter(state %in% valid_50dc) |>
  tidyr::pivot_wider(names_from = attribute, values_from = value) |>
  janitor::clean_names() |>
  dplyr::rename(rucc_description = description) |>
  dplyr::mutate(
    population_2020 = readr::parse_number(as.character(population_2020)),
    rucc_2023 = readr::parse_number(as.character(rucc_2023))
  )

require_columns(rucc_county, c("fips", "state", "population_2020", "rucc_2023"), "reshaped RUCC 2023 county file")

rucc_state <- rucc_county |>
  dplyr::group_by(state) |>
  dplyr::summarise(
    rucc_population_2020_total = sum(population_2020, na.rm = TRUE),
    rucc_nonmetro_population_2020 = sum(dplyr::if_else(rucc_2023 >= 4 & rucc_2023 <= 9, population_2020, 0), na.rm = TRUE),
    rucc_counties_total_2023 = dplyr::n_distinct(fips),
    rucc_nonmetro_counties_2023 = sum(rucc_2023 >= 4 & rucc_2023 <= 9, na.rm = TRUE),
    .groups = "drop"
  ) |>
  dplyr::mutate(
    rucc_nonmetro_county_share_2023 = rucc_nonmetro_counties_2023 / rucc_counties_total_2023,
    rucc_nonmetro_population_share_2023 = rucc_nonmetro_population_2020 / rucc_population_2020_total
  ) |>
  dplyr::arrange(dplyr::desc(rucc_nonmetro_population_share_2023)) |>
  dplyr::mutate(
    rurality_quintile = dplyr::ntile(dplyr::desc(rucc_nonmetro_population_share_2023), 5),
    rurality_quintile_label = dplyr::case_when(
      rurality_quintile == 1 ~ "Q1 most rural",
      rurality_quintile == 2 ~ "Q2",
      rurality_quintile == 3 ~ "Q3",
      rurality_quintile == 4 ~ "Q4",
      rurality_quintile == 5 ~ "Q5 most urban"
    )
  ) |>
  dplyr::arrange(state)

assert_valid_states(rucc_state, "RUCC state rurality")
safe_write_csv(rucc_state, project_path("data_processed", "covariates", "rucc_state_rurality_2023.csv"))

svi_raw <- read_clean_csv(
  project_path("data_raw", "covariates", "svi", "SVI_2022_US_county.csv"),
  "CDC SVI 2022 county file"
)

require_columns(svi_raw, c("st_abbr", "e_totpop", "rpl_themes"), "CDC SVI 2022 county file")

svi_state <- svi_raw |>
  dplyr::mutate(
    state = stringr::str_to_upper(st_abbr),
    e_totpop = readr::parse_number(as.character(e_totpop)),
    rpl_themes = readr::parse_number(as.character(rpl_themes))
  ) |>
  dplyr::filter(
    state %in% valid_50dc,
    !is.na(rpl_themes),
    rpl_themes >= 0,
    !is.na(e_totpop),
    e_totpop > 0
  ) |>
  dplyr::group_by(state) |>
  dplyr::summarise(
    svi_2022 = weighted.mean(rpl_themes, e_totpop, na.rm = TRUE),
    svi_counties_used_2022 = dplyr::n(),
    svi_population_weight_2022 = sum(e_totpop, na.rm = TRUE),
    .groups = "drop"
  ) |>
  dplyr::mutate(
    svi_2022_per_0_1 = svi_2022 / 0.1,
    svi_source_year = 2022L,
    svi_source = "CDC/ATSDR county SVI 2022; population-weighted mean RPL_THEMES using E_TOTPOP"
  ) |>
  dplyr::arrange(state)

assert_valid_states(svi_state, "2022 SVI state aggregate")
safe_write_csv(svi_state, project_path("data_processed", "covariates", "svi_state_2022_50dc.csv"))

census_region <- census_region_lookup() |>
  dplyr::arrange(state)
assert_valid_states(census_region, "Census region/division lookup")
safe_write_csv(
  census_region,
  project_path("data_processed", "covariates", "census_region_division_50dc.csv")
)

expansion_raw <- read_clean_csv(
  project_path("data_raw", "covariates", "medicaid_expansion", "medicaid_expansion_status.csv"),
  "Medicaid expansion status file"
)

require_columns(expansion_raw, c("state", "expansion_adopted", "expansion_effective_date"), "Medicaid expansion status file")

expansion_state <- expansion_raw |>
  dplyr::transmute(
    state = stringr::str_to_upper(state),
    medicaid_expansion_ever_adopted = as.integer(parse_bool_strict(expansion_adopted, "expansion_adopted")),
    medicaid_expansion_effective_date = parse_date_strict(expansion_effective_date, "expansion_effective_date")
  )

assert_valid_states(expansion_state, "Medicaid expansion state file")

enrolment_quarters <- read_clean_csv(
  project_path("data_processed", "enrolment", "medicaid_enrolment_state_quarter.csv"),
  "Medicaid state-quarter denominator file"
) |>
  dplyr::distinct(state, year, quarter)

expansion_state_quarter <- enrolment_quarters |>
  dplyr::left_join(expansion_state, by = "state") |>
  dplyr::mutate(
    quarter_start_date = quarter_start_date(year, quarter),
    quarter_end_date = quarter_start_date %m+% lubridate::period(months = 3) - lubridate::days(1),
    medicaid_expansion_active = dplyr::case_when(
      medicaid_expansion_ever_adopted == 0 ~ 0L,
      medicaid_expansion_ever_adopted == 1 & !is.na(medicaid_expansion_effective_date) & quarter_start_date >= medicaid_expansion_effective_date ~ 1L,
      medicaid_expansion_ever_adopted == 1 & !is.na(medicaid_expansion_effective_date) & quarter_start_date < medicaid_expansion_effective_date ~ 0L,
      TRUE ~ NA_integer_
    ),
    medicaid_expansion_active_any_part_quarter = dplyr::case_when(
      medicaid_expansion_ever_adopted == 0 ~ 0L,
      medicaid_expansion_ever_adopted == 1 & !is.na(medicaid_expansion_effective_date) & quarter_end_date >= medicaid_expansion_effective_date ~ 1L,
      medicaid_expansion_ever_adopted == 1 & !is.na(medicaid_expansion_effective_date) & quarter_end_date < medicaid_expansion_effective_date ~ 0L,
      TRUE ~ NA_integer_
    )
  ) |>
  dplyr::select(
    state,
    year,
    quarter,
    medicaid_expansion_ever_adopted,
    medicaid_expansion_effective_date,
    medicaid_expansion_active,
    medicaid_expansion_active_any_part_quarter
  ) |>
  dplyr::arrange(state, year, quarter)

assert_no_duplicate_keys(expansion_state_quarter, c("state", "year", "quarter"), "Medicaid expansion state-quarter file")
safe_write_csv(
  expansion_state_quarter,
  project_path("data_processed", "covariates", "medicaid_expansion_state_quarter.csv")
)

message("Wrote final cleaned covariates to: ", output_dir)
