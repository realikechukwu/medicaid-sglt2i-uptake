# ============================================================
# Build state-year covariates and merge onto SGLT2 quarterly rates
# ============================================================
#
# Analysis unit:
#   State-year covariates merged to state-quarter SGLT2 outcomes by
#   state + year.
#
# Analysis years:
#   2015-2019 and 2021-2025. Excludes 2020.
#
# Jurisdictions:
#   50 U.S. states + DC only.
#
# Outputs:
#   data_processed/state_year_covariates_2015_2025_excluding_2020.csv
#   data_processed/state_year_covariates_missingness_report.csv
#   data_processed/sglt2_state_quarter_rates_all_products_with_covariates_50dc_excluding_2020.csv
#   data_processed/sglt2_state_quarter_rates_single_agent_with_covariates_50dc_excluding_2020.csv
#   data_processed/sglt2_state_quarter_rates_empa_dapa_with_covariates_50dc_excluding_2020.csv
#   docs/covariate_construction_limitations.md
# ============================================================

library(tidyverse)
library(here)
library(janitor)
library(lubridate)
library(readr)

# ------------------------------------------------------------
# 0. Paths and settings
# ------------------------------------------------------------

analysis_years <- c(2015:2019, 2021:2025)
valid_50dc <- c(state.abb, "DC")
expected_n_state_years <- length(valid_50dc) * length(analysis_years)

raw_covariate_dir <- here("data_raw", "covariates")
processed_dir <- here("data_processed")
docs_dir <- here("docs")

dir.create(raw_covariate_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(processed_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(docs_dir, recursive = TRUE, showWarnings = FALSE)

covariate_output_file <- here(
  "data_processed",
  "state_year_covariates_2015_2025_excluding_2020.csv"
)

missingness_output_file <- here(
  "data_processed",
  "state_year_covariates_missingness_report.csv"
)

limitations_doc_file <- here(
  "docs",
  "covariate_construction_limitations.md"
)

main_sglt2_file <- here(
  "data_processed",
  "sglt2_state_quarter_rates_all_products_50dc_excluding_2020.csv"
)

main_sglt2_covariate_file <- here(
  "data_processed",
  "sglt2_state_quarter_rates_all_products_with_covariates_50dc_excluding_2020.csv"
)

sensitivity_rate_files <- tribble(
  ~input_file, ~output_file,
  here(
    "data_processed",
    "sglt2_state_quarter_rates_single_agent_50dc_excluding_2020.csv"
  ),
  here(
    "data_processed",
    "sglt2_state_quarter_rates_single_agent_with_covariates_50dc_excluding_2020.csv"
  ),
  here(
    "data_processed",
    "sglt2_state_quarter_rates_empa_dapa_50dc_excluding_2020.csv"
  ),
  here(
    "data_processed",
    "sglt2_state_quarter_rates_empa_dapa_with_covariates_50dc_excluding_2020.csv"
  )
)

files_written <- character()
diagnostics_written <- character()
residual_issues <- character()

# ------------------------------------------------------------
# 1. Helper functions
# ------------------------------------------------------------

relative_path <- function(path) {
  root <- normalizePath(here(), winslash = "/", mustWork = FALSE)
  norm_path <- normalizePath(path, winslash = "/", mustWork = FALSE)

  if_else(
    startsWith(norm_path, paste0(root, "/")),
    str_sub(norm_path, nchar(root) + 2),
    norm_path
  )
}

standardise_state <- function(x) {
  state_xwalk <- tibble(
    state_name = c(state.name, "District of Columbia"),
    state_abbr = valid_50dc
  )

  x_chr <- str_squish(as.character(x))
  x_upper <- str_to_upper(x_chr)
  x_title <- str_to_title(x_chr)

  case_when(
    x_upper %in% valid_50dc ~ x_upper,
    x_upper %in% c("DISTRICT OF COLUMBIA", "DIST. OF COL.", "WASHINGTON DC") ~ "DC",
    x_title %in% state_xwalk$state_name ~ state_xwalk$state_abbr[match(x_title, state_xwalk$state_name)],
    TRUE ~ NA_character_
  )
}

check_50dc <- function(data, context, state_col = "state", year_col = NULL) {
  state_values <- sort(unique(data[[state_col]]))
  extra_states <- setdiff(state_values, valid_50dc)
  missing_states <- setdiff(valid_50dc, state_values)

  message(context, ": ", length(intersect(state_values, valid_50dc)), " valid 50-state/DC jurisdictions present.")

  if (length(extra_states) > 0) {
    warning(context, " has non-50DC state codes: ", paste(extra_states, collapse = ", "))
  }

  if (length(missing_states) > 0) {
    warning(context, " is missing 50DC state codes: ", paste(missing_states, collapse = ", "))
  }

  if (!is.null(year_col) && year_col %in% names(data)) {
    counts <- data %>%
      count(.data[[year_col]], name = "n_states") %>%
      arrange(.data[[year_col]])

    print(counts)
  }

  invisible(data)
}

nearest_source_year <- function(target_year, source_years) {
  source_years <- sort(unique(source_years[!is.na(source_years)]))

  if (length(source_years) == 0) {
    return(NA_integer_)
  }

  source_years[which.min(abs(source_years - target_year))]
}

save_diagnostic <- function(data, file_name) {
  path <- here("data_processed", file_name)
  write_csv(data, path)
  diagnostics_written <<- c(diagnostics_written, relative_path(path))
  files_written <<- c(files_written, relative_path(path))
  path
}

download_if_missing <- function(url, destfile, quiet = TRUE) {
  if (file.exists(destfile)) {
    message("Using existing file: ", destfile)
    return(TRUE)
  }

  message("Downloading: ", url)
  ok <- tryCatch(
    {
      utils::download.file(url, destfile, mode = "wb", quiet = quiet)
      TRUE
    },
    error = function(e) {
      warning("Download failed for ", url, ": ", conditionMessage(e))
      FALSE
    }
  )

  if (ok) {
    record_file_written(destfile)
  }

  ok
}

safe_read_csv <- function(file_path) {
  if (!file.exists(file_path)) {
    warning("File does not exist: ", file_path)
    return(tibble())
  }

  read_csv(file_path, col_types = cols(.default = col_character()), show_col_types = FALSE) %>%
    clean_names()
}

record_file_written <- function(path) {
  files_written <<- c(files_written, relative_path(path))
  invisible(path)
}

make_missingness_report <- function(data, covariate_cols) {
  map_dfr(covariate_cols, function(col_name) {
    missing_rows <- data %>% filter(is.na(.data[[col_name]]))

    tibble(
      covariate_name = col_name,
      number_missing = nrow(missing_rows),
      percent_missing = nrow(missing_rows) / nrow(data) * 100,
      affected_years = if_else(
        nrow(missing_rows) == 0,
        "",
        paste(sort(unique(missing_rows$year)), collapse = ";")
      ),
      affected_states = if_else(
        nrow(missing_rows) == 0,
        "",
        paste(sort(unique(missing_rows$state)), collapse = ";")
      )
    )
  }) %>%
    arrange(desc(number_missing), covariate_name)
}

check_expected_state_year_grid <- function(data, context) {
  missing_grid <- expand_grid(state = valid_50dc, year = analysis_years) %>%
    anti_join(data %>% distinct(state, year), by = c("state", "year")) %>%
    arrange(state, year)

  duplicate_grid <- data %>%
    count(state, year) %>%
    filter(n > 1) %>%
    arrange(state, year)

  message(context, " rows: ", nrow(data), "; expected: ", expected_n_state_years)

  if (nrow(missing_grid) > 0) {
    save_diagnostic(missing_grid, "state_year_covariates_missing_state_year_grid.csv")
    warning(context, " is missing expected state-year rows.")
  }

  if (nrow(duplicate_grid) > 0) {
    save_diagnostic(duplicate_grid, "state_year_covariates_duplicate_state_year_grid.csv")
    stop(context, " has duplicate state-year rows.")
  }

  invisible(data)
}

source_label <- function(prefix, path_or_url, extra = NULL) {
  base <- paste(as.character(prefix), as.character(path_or_url), sep = " | ")

  if (is.null(extra)) {
    return(base)
  }

  extra_chr <- as.character(extra)

  if_else(
    is.na(extra_chr) | extra_chr == "",
    base,
    paste(base, extra_chr, sep = " | ")
  )
}

# ------------------------------------------------------------
# 2. Expected state-year grid
# ------------------------------------------------------------

state_year_grid <- crossing(
  state = valid_50dc,
  year = analysis_years
) %>%
  arrange(state, year)

message("Expected state-year grid rows: ", nrow(state_year_grid))
print(state_year_grid %>% count(year, name = "n_states"))

# ------------------------------------------------------------
# 3. Medicaid expansion status
# ------------------------------------------------------------

medicaid_expansion_file <- here(
  "data_raw",
  "covariates",
  "medicaid_expansion_status.csv"
)

if (!file.exists(medicaid_expansion_file)) {
  message("Creating manually coded Medicaid expansion status file: ", medicaid_expansion_file)

  medicaid_expansion_seed <- tribble(
    ~state, ~expansion_adopted, ~expansion_effective_date, ~notes,
    "AL", FALSE, NA_character_, "KFF Medicaid expansion tracker; not adopted as of 2025.",
    "AK", TRUE, "2015-09-01", "KFF Medicaid expansion tracker; implementation date should be confirmed before final manuscript.",
    "AZ", TRUE, "2014-01-01", "KFF Medicaid expansion tracker.",
    "AR", TRUE, "2014-01-01", "KFF Medicaid expansion tracker.",
    "CA", TRUE, "2014-01-01", "KFF Medicaid expansion tracker.",
    "CO", TRUE, "2014-01-01", "KFF Medicaid expansion tracker.",
    "CT", TRUE, "2014-01-01", "KFF Medicaid expansion tracker.",
    "DC", TRUE, "2014-01-01", "KFF Medicaid expansion tracker.",
    "DE", TRUE, "2014-01-01", "KFF Medicaid expansion tracker.",
    "FL", FALSE, NA_character_, "KFF Medicaid expansion tracker; not adopted as of 2025.",
    "GA", FALSE, NA_character_, "KFF Medicaid expansion tracker; Georgia Pathways is not coded as ACA expansion here.",
    "HI", TRUE, "2014-01-01", "KFF Medicaid expansion tracker.",
    "IA", TRUE, "2014-01-01", "KFF Medicaid expansion tracker.",
    "ID", TRUE, "2020-01-01", "KFF Medicaid expansion tracker.",
    "IL", TRUE, "2014-01-01", "KFF Medicaid expansion tracker.",
    "IN", TRUE, "2015-02-01", "KFF Medicaid expansion tracker.",
    "KS", FALSE, NA_character_, "KFF Medicaid expansion tracker; not adopted as of 2025.",
    "KY", TRUE, "2014-01-01", "KFF Medicaid expansion tracker.",
    "LA", TRUE, "2016-07-01", "KFF Medicaid expansion tracker.",
    "MA", TRUE, "2014-01-01", "KFF Medicaid expansion tracker.",
    "MD", TRUE, "2014-01-01", "KFF Medicaid expansion tracker.",
    "ME", TRUE, "2019-01-10", "KFF Medicaid expansion tracker; Maine retroactive coverage nuance should be confirmed manually.",
    "MI", TRUE, "2014-04-01", "KFF Medicaid expansion tracker.",
    "MN", TRUE, "2014-01-01", "KFF Medicaid expansion tracker.",
    "MO", TRUE, "2021-10-01", "KFF Medicaid expansion tracker.",
    "MS", FALSE, NA_character_, "KFF Medicaid expansion tracker; not adopted as of 2025.",
    "MT", TRUE, "2016-01-01", "KFF Medicaid expansion tracker.",
    "NC", TRUE, "2023-12-01", "KFF Medicaid expansion tracker.",
    "ND", TRUE, "2014-01-01", "KFF Medicaid expansion tracker.",
    "NE", TRUE, "2020-10-01", "KFF Medicaid expansion tracker.",
    "NH", TRUE, "2014-08-15", "KFF Medicaid expansion tracker.",
    "NJ", TRUE, "2014-01-01", "KFF Medicaid expansion tracker.",
    "NM", TRUE, "2014-01-01", "KFF Medicaid expansion tracker.",
    "NV", TRUE, "2014-01-01", "KFF Medicaid expansion tracker.",
    "NY", TRUE, "2014-01-01", "KFF Medicaid expansion tracker.",
    "OH", TRUE, "2014-01-01", "KFF Medicaid expansion tracker.",
    "OK", TRUE, "2021-07-01", "KFF Medicaid expansion tracker.",
    "OR", TRUE, "2014-01-01", "KFF Medicaid expansion tracker.",
    "PA", TRUE, "2015-01-01", "KFF Medicaid expansion tracker.",
    "RI", TRUE, "2014-01-01", "KFF Medicaid expansion tracker.",
    "SC", FALSE, NA_character_, "KFF Medicaid expansion tracker; not adopted as of 2025.",
    "SD", TRUE, "2023-07-01", "KFF Medicaid expansion tracker.",
    "TN", FALSE, NA_character_, "KFF Medicaid expansion tracker; not adopted as of 2025.",
    "TX", FALSE, NA_character_, "KFF Medicaid expansion tracker; not adopted as of 2025.",
    "UT", TRUE, "2020-01-01", "KFF Medicaid expansion tracker; full ACA expansion coded from 2020.",
    "VA", TRUE, "2019-01-01", "KFF Medicaid expansion tracker.",
    "VT", TRUE, "2014-01-01", "KFF Medicaid expansion tracker.",
    "WA", TRUE, "2014-01-01", "KFF Medicaid expansion tracker.",
    "WI", FALSE, NA_character_, "KFF Medicaid expansion tracker; Wisconsin is not coded as ACA expansion.",
    "WV", TRUE, "2014-01-01", "KFF Medicaid expansion tracker.",
    "WY", FALSE, NA_character_, "KFF Medicaid expansion tracker; not adopted as of 2025."
  )

  write_csv(medicaid_expansion_seed, medicaid_expansion_file)
  record_file_written(medicaid_expansion_file)
}

medicaid_expansion_raw <- safe_read_csv(medicaid_expansion_file) %>%
  mutate(
    state = standardise_state(state),
    expansion_adopted = case_when(
      str_to_lower(expansion_adopted) %in% c("true", "t", "1", "yes", "y") ~ TRUE,
      str_to_lower(expansion_adopted) %in% c("false", "f", "0", "no", "n") ~ FALSE,
      TRUE ~ NA
    ),
    expansion_effective_date = ymd(expansion_effective_date)
  ) %>%
  filter(state %in% valid_50dc) %>%
  distinct(state, .keep_all = TRUE)

check_50dc(medicaid_expansion_raw, "Medicaid expansion lookup")

medicaid_expansion_covariates <- state_year_grid %>%
  left_join(medicaid_expansion_raw, by = "state") %>%
  mutate(
    year_start = ymd(paste0(year, "-01-01")),
    year_end = ymd(paste0(year, "-12-31")),
    medicaid_expansion_status_any_year = if_else(
      !is.na(expansion_effective_date) & expansion_effective_date <= year_end,
      1L,
      0L
    ),
    medicaid_expansion_status_full_year = if_else(
      !is.na(expansion_effective_date) & expansion_effective_date <= year_start,
      1L,
      0L
    ),
    medicaid_expansion_status = medicaid_expansion_status_any_year,
    medicaid_expansion_effective_date = as.character(expansion_effective_date)
  ) %>%
  select(
    state,
    year,
    medicaid_expansion_status,
    medicaid_expansion_status_any_year,
    medicaid_expansion_status_full_year,
    medicaid_expansion_effective_date,
    medicaid_expansion_notes = notes
  )

# ------------------------------------------------------------
# 4. Census region and division
# ------------------------------------------------------------

census_region_division <- tribble(
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

check_50dc(census_region_division, "Census region/division lookup")

census_covariates <- state_year_grid %>%
  left_join(census_region_division, by = "state")

# ------------------------------------------------------------
# 5. Rurality using USDA ERS RUCC 2023
# ------------------------------------------------------------

rucc_url <- "https://www.ers.usda.gov/sites/default/files/_laserfiche/DataFiles/53251/Ruralurbancontinuumcodes2023.csv"
rucc_file <- here("data_raw", "covariates", "Ruralurbancontinuumcodes2023.csv")

rucc_ok <- download_if_missing(rucc_url, rucc_file)

if (rucc_ok && file.exists(rucc_file)) {
  rucc_raw <- safe_read_csv(rucc_file)

  rucc_county <- rucc_raw %>%
    mutate(
      state = standardise_state(state),
      attribute = str_to_lower(attribute)
    ) %>%
    filter(attribute %in% c("population_2020", "rucc_2023")) %>%
    mutate(
      value_num = parse_number(value)
    ) %>%
    filter(state %in% valid_50dc) %>%
    select(fips, state, county_name, attribute, value_num) %>%
    pivot_wider(names_from = attribute, values_from = value_num)

  required_rucc_cols <- c("population_2020", "rucc_2023")
  missing_rucc_cols <- setdiff(required_rucc_cols, names(rucc_county))

  if (length(missing_rucc_cols) > 0) {
    residual_issues <- c(
      residual_issues,
      paste("USDA RUCC file did not contain expected columns:", paste(missing_rucc_cols, collapse = ", "))
    )
    save_diagnostic(names(rucc_county) %>% tibble(column_name = .), "rucc_candidate_columns.csv")

    rurality_state <- state_year_grid %>%
      transmute(
        state,
        year,
        rurality_measure = NA_real_,
        rurality_measure_source = "USDA ERS RUCC 2023 attempted; expected columns not found",
        rurality_measure_name = "percent_population_in_nonmetro_counties",
        rurality_source_year = 2023L,
        rucc_mean_population_weighted = NA_real_,
        rucc_mean_unweighted = NA_real_
      )
  } else {
    rurality_base <- rucc_county %>%
      filter(!is.na(population_2020), !is.na(rucc_2023)) %>%
      group_by(state) %>%
      summarise(
        state_population_2020_rucc = sum(population_2020, na.rm = TRUE),
        population_nonmetro_2020 = sum(if_else(rucc_2023 >= 4, population_2020, 0), na.rm = TRUE),
        rurality_measure = population_nonmetro_2020 / state_population_2020_rucc * 100,
        rucc_mean_population_weighted = weighted.mean(rucc_2023, population_2020, na.rm = TRUE),
        rucc_mean_unweighted = mean(rucc_2023, na.rm = TRUE),
        .groups = "drop"
      ) %>%
      mutate(
        rurality_measure_source = source_label(
          "USDA ERS Rural-Urban Continuum Codes 2023",
          rucc_url,
          "County population-weighted percent living in nonmetro counties, using 2020 county population"
        ),
        rurality_measure_name = "percent_population_in_nonmetro_counties",
        rurality_source_year = 2023L
      )

    check_50dc(rurality_base, "USDA RUCC rurality aggregate")

    rurality_state <- state_year_grid %>%
      left_join(rurality_base, by = "state")
  }
} else {
  residual_issues <- c(
    residual_issues,
    "USDA ERS RUCC 2023 could not be downloaded; rurality_measure left missing."
  )

  rurality_state <- state_year_grid %>%
    transmute(
      state,
      year,
      rurality_measure = NA_real_,
      rurality_measure_source = "USDA ERS RUCC 2023 download failed",
      rurality_measure_name = "percent_population_in_nonmetro_counties",
      rurality_source_year = 2023L,
      state_population_2020_rucc = NA_real_,
      population_nonmetro_2020 = NA_real_,
      rucc_mean_population_weighted = NA_real_,
      rucc_mean_unweighted = NA_real_
    )
}

# ------------------------------------------------------------
# 6. SVI using CDC/ATSDR county SVI
# ------------------------------------------------------------

svi_years <- c(2014, 2016, 2018, 2020, 2022)
svi_urls <- tibble(
  svi_source_year = svi_years,
  url = paste0(
    "https://svi.cdc.gov/Documents/Data/",
    svi_years,
    "/csv/states_counties/SVI_",
    svi_years,
    "_US_county.csv"
  ),
  file_path = here(
    "data_raw",
    "covariates",
    paste0("SVI_", svi_years, "_US_county.csv")
  )
)

svi_download_status <- svi_urls %>%
  mutate(downloaded = map2_lgl(url, file_path, download_if_missing))

svi_state_source <- pmap_dfr(
  svi_download_status,
  function(svi_source_year, url, file_path, downloaded) {
    if (!downloaded || !file.exists(file_path)) {
      residual_issues <<- c(
        residual_issues,
        paste("CDC SVI", svi_source_year, "could not be downloaded.")
      )
      return(tibble())
    }

    svi_raw <- safe_read_csv(file_path)
    needed <- c("st_abbr", "e_totpop", "rpl_themes")
    missing_needed <- setdiff(needed, names(svi_raw))

    if (length(missing_needed) > 0) {
      residual_issues <<- c(
        residual_issues,
        paste("CDC SVI", svi_source_year, "missing expected columns:", paste(missing_needed, collapse = ", "))
      )
      save_diagnostic(names(svi_raw) %>% tibble(column_name = .), paste0("svi_", svi_source_year, "_candidate_columns.csv"))
      return(tibble())
    }

    svi_raw %>%
      mutate(
        state = standardise_state(st_abbr),
        e_totpop = parse_number(e_totpop),
        rpl_themes = parse_number(rpl_themes)
      ) %>%
      filter(
        state %in% valid_50dc,
        !is.na(rpl_themes),
        rpl_themes >= 0,
        !is.na(e_totpop),
        e_totpop > 0
      ) %>%
      group_by(state) %>%
      summarise(
        svi_state = weighted.mean(rpl_themes, e_totpop, na.rm = TRUE),
        svi_counties_used = n(),
        svi_population_weight = sum(e_totpop, na.rm = TRUE),
        .groups = "drop"
      ) %>%
      mutate(
        svi_source_year = svi_source_year,
        svi_source = source_label(
          "CDC/ATSDR county SVI",
          url,
          "Population-weighted mean county RPL_THEMES using E_TOTPOP"
        )
      )
  }
)

if (nrow(svi_state_source) > 0) {
  save_diagnostic(svi_state_source, "svi_state_aggregates_by_source_year.csv")
  check_50dc(svi_state_source %>% filter(svi_source_year == max(svi_source_year)), "CDC SVI latest aggregate")

  svi_state_year <- state_year_grid %>%
    mutate(svi_source_year = map_int(year, nearest_source_year, source_years = svi_state_source$svi_source_year)) %>%
    left_join(svi_state_source, by = c("state", "svi_source_year"))
} else {
  residual_issues <- c(
    residual_issues,
    "No CDC SVI source years were successfully read; svi_state left missing."
  )

  svi_state_year <- state_year_grid %>%
    mutate(
      svi_state = NA_real_,
      svi_source_year = NA_integer_,
      svi_counties_used = NA_integer_,
      svi_population_weight = NA_real_,
      svi_source = "CDC/ATSDR county SVI download/read failed"
    )
}

# ------------------------------------------------------------
# 7. Diabetes and CKD prevalence using CDC PLACES
# ------------------------------------------------------------

places_sources <- tribble(
  ~places_release_label, ~places_release_year, ~api_id,
  "CDC PLACES County Data 2020 release", 2020L, "dv4u-3x3q",
  "CDC PLACES County Data 2021 release", 2021L, "pqpp-u99h",
  "CDC PLACES County Data 2022 release", 2022L, "duw2-7jbt",
  "CDC PLACES County Data 2023 release", 2023L, "h3ej-a9ec",
  "CDC PLACES County Data current release endpoint", 2025L, "swc5-untb"
) %>%
  mutate(
    url = paste0(
      "https://data.cdc.gov/resource/",
      api_id,
      ".csv?$limit=60000&$where=",
      URLencode("measureid in('DIABETES','KIDNEY')", reserved = TRUE)
    ),
    file_path = here(
      "data_raw",
      "covariates",
      paste0("places_county_diabetes_ckd_", api_id, ".csv")
    )
  )

places_download_status <- places_sources %>%
  mutate(downloaded = map2_lgl(url, file_path, download_if_missing))

places_state_source <- pmap_dfr(
  places_download_status,
  function(places_release_label, places_release_year, api_id, url, file_path, downloaded) {
    if (!downloaded || !file.exists(file_path)) {
      residual_issues <<- c(
        residual_issues,
        paste(places_release_label, "could not be downloaded from", api_id)
      )
      return(tibble())
    }

    places_raw <- safe_read_csv(file_path)

    if (nrow(places_raw) == 0) {
      residual_issues <<- c(
        residual_issues,
        paste(places_release_label, "returned zero rows.")
      )
      return(tibble())
    }

    needed <- c("year", "stateabbr", "measureid", "data_value")
    missing_needed <- setdiff(needed, names(places_raw))

    if (length(missing_needed) > 0) {
      residual_issues <<- c(
        residual_issues,
        paste(places_release_label, "missing expected columns:", paste(missing_needed, collapse = ", "))
      )
      save_diagnostic(names(places_raw) %>% tibble(column_name = .), paste0("places_", api_id, "_candidate_columns.csv"))
      return(tibble())
    }

    places_prepped <- places_raw %>%
      mutate(
        state = standardise_state(stateabbr),
        source_year = as.integer(year),
        measureid = str_to_upper(measureid),
        data_value_num = parse_number(data_value),
        totalpop18plus_num = if ("totalpop18plus" %in% names(.)) parse_number(totalpop18plus) else NA_real_,
        totalpopulation_num = if ("totalpopulation" %in% names(.)) parse_number(totalpopulation) else NA_real_,
        population_weight = case_when(
          !is.na(totalpop18plus_num) & totalpop18plus_num > 0 ~ totalpop18plus_num,
          !is.na(totalpopulation_num) & totalpopulation_num > 0 ~ totalpopulation_num,
          TRUE ~ NA_real_
        ),
        data_value_type_clean = if ("data_value_type" %in% names(.)) str_to_lower(data_value_type) else NA_character_,
        datavaluetypeid_clean = if ("datavaluetypeid" %in% names(.)) datavaluetypeid else NA_character_
      ) %>%
      filter(
        state %in% valid_50dc,
        measureid %in% c("DIABETES", "KIDNEY"),
        !is.na(source_year),
        !is.na(data_value_num),
        is.na(data_value_type_clean) |
          str_detect(data_value_type_clean, "crude prevalence") |
          datavaluetypeid_clean == "CrdPrv"
      )

    places_prepped %>%
      group_by(state, source_year, measureid) %>%
      summarise(
        prevalence = if_else(
          all(is.na(population_weight)),
          mean(data_value_num, na.rm = TRUE),
          weighted.mean(data_value_num, population_weight, na.rm = TRUE)
        ),
        places_counties_used = n(),
        places_population_weight = if_else(
          all(is.na(population_weight)),
          NA_real_,
          sum(population_weight, na.rm = TRUE)
        ),
        places_weight_method = if_else(
          all(is.na(population_weight)),
          "unweighted mean county prevalence",
          "population-weighted mean county prevalence"
        ),
        .groups = "drop"
      ) %>%
      mutate(
        places_release_label = places_release_label,
        places_release_year = places_release_year,
        places_api_id = api_id,
        places_source = source_label(
          places_release_label,
          paste0("https://data.cdc.gov/api/views/", api_id),
          places_weight_method
        )
      )
  }
)

if (nrow(places_state_source) > 0) {
  places_state_source <- places_state_source %>%
    arrange(state, source_year, measureid, places_release_year) %>%
    group_by(state, source_year, measureid) %>%
    slice_tail(n = 1) %>%
    ungroup()

  save_diagnostic(places_state_source, "places_state_aggregates_diabetes_ckd_by_source_year.csv")

  attach_places_measure <- function(grid, places_data, measure_id, value_col, source_col) {
    measure_data <- places_data %>%
      filter(measureid == measure_id)

    if (nrow(measure_data) == 0) {
      return(
        grid %>%
          mutate(
            "{value_col}" := NA_real_,
            "{source_col}" := paste("CDC PLACES", measure_id, "source unavailable")
          )
      )
    }

    grid %>%
      mutate(source_year = map_int(year, nearest_source_year, source_years = measure_data$source_year)) %>%
      left_join(
        measure_data %>%
          select(
            state,
            source_year,
            prevalence,
            places_source,
            places_counties_used,
            places_population_weight
          ),
        by = c("state", "source_year")
      ) %>%
      transmute(
        state,
        year,
        "{value_col}" := prevalence,
        "{source_col}" := if_else(
          is.na(prevalence),
          paste("CDC PLACES", measure_id, "matched source unavailable"),
          paste0(places_source, " | PLACES source year ", source_year)
        ),
        "{value_col}_source_year" := source_year,
        "{value_col}_counties_used" := places_counties_used,
        "{value_col}_population_weight" := places_population_weight
      )
  }

  diabetes_state_year <- attach_places_measure(
    state_year_grid,
    places_state_source,
    "DIABETES",
    "diabetes_prevalence",
    "diabetes_prevalence_source"
  )

  ckd_state_year <- attach_places_measure(
    state_year_grid,
    places_state_source,
    "KIDNEY",
    "ckd_prevalence",
    "ckd_prevalence_source"
  )
} else {
  residual_issues <- c(
    residual_issues,
    "No CDC PLACES sources were successfully read; diabetes_prevalence and ckd_prevalence left missing."
  )

  diabetes_state_year <- state_year_grid %>%
    mutate(
      diabetes_prevalence = NA_real_,
      diabetes_prevalence_source = "CDC PLACES download/read failed",
      diabetes_prevalence_source_year = NA_integer_,
      diabetes_prevalence_counties_used = NA_integer_,
      diabetes_prevalence_population_weight = NA_real_
    )

  ckd_state_year <- state_year_grid %>%
    mutate(
      ckd_prevalence = NA_real_,
      ckd_prevalence_source = "CDC PLACES download/read failed",
      ckd_prevalence_source_year = NA_integer_,
      ckd_prevalence_counties_used = NA_integer_,
      ckd_prevalence_population_weight = NA_real_
    )
}

# ------------------------------------------------------------
# 8. Heart failure prevalence manual source
# ------------------------------------------------------------

hf_manual_file <- here(
  "data_raw",
  "covariates",
  "medicare_chronic_conditions_state_year.csv"
)

if (!file.exists(hf_manual_file)) {
  hf_template <- state_year_grid %>%
    transmute(
      state,
      year,
      hf_prevalence = NA_real_,
      diabetes_prevalence_medicare_optional = NA_real_,
      ckd_prevalence_medicare_optional = NA_real_,
      source_url = "Expected source: CMS Medicare Chronic Conditions / Chronic Conditions Warehouse state-year data",
      notes = "Fill hf_prevalence only after confirming numerator, denominator, geography, and year definitions."
    )

  write_csv(hf_template, hf_manual_file)
  record_file_written(hf_manual_file)
}

hf_manual_raw <- safe_read_csv(hf_manual_file)

if (all(c("state", "year", "hf_prevalence") %in% names(hf_manual_raw))) {
  hf_state_year <- hf_manual_raw %>%
    mutate(
      state = standardise_state(state),
      year = as.integer(year),
      hf_prevalence = parse_number(hf_prevalence),
      hf_prevalence_source = if_else(
        !is.na(hf_prevalence),
        source_label(
          "Manual CMS Medicare Chronic Conditions state-year input",
          hf_manual_file,
          if ("source_url" %in% names(.)) source_url else NA_character_
        ),
        "Manual input required: data_raw/covariates/medicare_chronic_conditions_state_year.csv"
      )
    ) %>%
    filter(state %in% valid_50dc, year %in% analysis_years) %>%
    select(state, year, hf_prevalence, hf_prevalence_source) %>%
    right_join(state_year_grid, by = c("state", "year")) %>%
    mutate(
      hf_prevalence_source = replace_na(
        hf_prevalence_source,
        "Manual input required: data_raw/covariates/medicare_chronic_conditions_state_year.csv"
      )
    )
} else {
  save_diagnostic(names(hf_manual_raw) %>% tibble(column_name = .), "cms_hf_manual_candidate_columns.csv")
  residual_issues <- c(
    residual_issues,
    "CMS Medicare HF manual file exists but does not contain state, year, and hf_prevalence."
  )

  hf_state_year <- state_year_grid %>%
    mutate(
      hf_prevalence = NA_real_,
      hf_prevalence_source = "Manual input required: data_raw/covariates/medicare_chronic_conditions_state_year.csv"
    )
}

if (all(is.na(hf_state_year$hf_prevalence))) {
  residual_issues <- c(
    residual_issues,
    "Heart failure prevalence is missing because no confirmed CMS Medicare Chronic Conditions state-year source file has been supplied."
  )
}

# ------------------------------------------------------------
# 9. Cardiologist and physician density manual/AHRF source
# ------------------------------------------------------------

ahrf_manual_file <- here(
  "data_raw",
  "covariates",
  "ahrf_state_year_workforce.csv"
)

if (!file.exists(ahrf_manual_file)) {
  ahrf_template <- state_year_grid %>%
    transmute(
      state,
      year,
      cardiologists_count = NA_real_,
      primary_care_physicians_count = NA_real_,
      total_physicians_count = NA_real_,
      state_population = NA_real_,
      cardiologists_per_100k = NA_real_,
      primary_care_physicians_per_100k = NA_real_,
      total_physicians_per_100k = NA_real_,
      source_file = "Expected source: HRSA AHRF state or county file plus technical documentation",
      notes = "Fill counts and population or density columns only after confirming AHRF field definitions."
    )

  write_csv(ahrf_template, ahrf_manual_file)
  record_file_written(ahrf_manual_file)
}

ahrf_raw <- safe_read_csv(ahrf_manual_file)
ahrf_required <- c("state", "year")
ahrf_missing_required <- setdiff(ahrf_required, names(ahrf_raw))

if (length(ahrf_missing_required) > 0) {
  save_diagnostic(names(ahrf_raw) %>% tibble(column_name = .), "ahrf_workforce_candidate_columns.csv")
  residual_issues <- c(
    residual_issues,
    "AHRF workforce file exists but is missing state/year columns."
  )

  workforce_state_year <- state_year_grid %>%
    mutate(
      cardiologists_per_100k = NA_real_,
      cardiologist_density_source = "Manual AHRF input required: data_raw/covariates/ahrf_state_year_workforce.csv",
      primary_care_physicians_per_100k = NA_real_,
      physician_density_source = "Manual AHRF input required: data_raw/covariates/ahrf_state_year_workforce.csv"
    )
} else {
  workforce_state_year <- ahrf_raw %>%
    mutate(
      state = standardise_state(state),
      year = as.integer(year),
      cardiologists_count = if ("cardiologists_count" %in% names(.)) parse_number(cardiologists_count) else NA_real_,
      primary_care_physicians_count = if ("primary_care_physicians_count" %in% names(.)) parse_number(primary_care_physicians_count) else NA_real_,
      total_physicians_count = if ("total_physicians_count" %in% names(.)) parse_number(total_physicians_count) else NA_real_,
      state_population = if ("state_population" %in% names(.)) parse_number(state_population) else NA_real_,
      cardiologists_per_100k = if ("cardiologists_per_100k" %in% names(.)) parse_number(cardiologists_per_100k) else NA_real_,
      primary_care_physicians_per_100k = if ("primary_care_physicians_per_100k" %in% names(.)) parse_number(primary_care_physicians_per_100k) else NA_real_,
      total_physicians_per_100k = if ("total_physicians_per_100k" %in% names(.)) parse_number(total_physicians_per_100k) else NA_real_,
      cardiologists_per_100k = if_else(
        is.na(cardiologists_per_100k) & !is.na(cardiologists_count) & !is.na(state_population) & state_population > 0,
        cardiologists_count / state_population * 100000,
        cardiologists_per_100k
      ),
      primary_care_physicians_per_100k = if_else(
        is.na(primary_care_physicians_per_100k) &
          !is.na(primary_care_physicians_count) &
          !is.na(state_population) &
          state_population > 0,
        primary_care_physicians_count / state_population * 100000,
        primary_care_physicians_per_100k
      ),
      primary_care_physicians_per_100k = if_else(
        is.na(primary_care_physicians_per_100k) &
          !is.na(total_physicians_per_100k),
        total_physicians_per_100k,
        primary_care_physicians_per_100k
      ),
      physician_density_source = if_else(
        !is.na(primary_care_physicians_per_100k),
        source_label("Manual HRSA AHRF workforce input", ahrf_manual_file),
        "Manual AHRF input required: data_raw/covariates/ahrf_state_year_workforce.csv"
      ),
      cardiologist_density_source = if_else(
        !is.na(cardiologists_per_100k),
        source_label("Manual HRSA AHRF workforce input", ahrf_manual_file),
        "Manual AHRF input required: data_raw/covariates/ahrf_state_year_workforce.csv"
      )
    ) %>%
    filter(state %in% valid_50dc, year %in% analysis_years) %>%
    select(
      state,
      year,
      cardiologists_per_100k,
      cardiologist_density_source,
      primary_care_physicians_per_100k,
      physician_density_source
    ) %>%
    right_join(state_year_grid, by = c("state", "year")) %>%
    mutate(
      cardiologist_density_source = replace_na(
        cardiologist_density_source,
        "Manual AHRF input required: data_raw/covariates/ahrf_state_year_workforce.csv"
      ),
      physician_density_source = replace_na(
        physician_density_source,
        "Manual AHRF input required: data_raw/covariates/ahrf_state_year_workforce.csv"
      )
    )
}

if (all(is.na(workforce_state_year$cardiologists_per_100k))) {
  residual_issues <- c(
    residual_issues,
    "Cardiologist density is missing because no confirmed AHRF workforce input has been supplied."
  )
}

if (all(is.na(workforce_state_year$primary_care_physicians_per_100k))) {
  residual_issues <- c(
    residual_issues,
    "Primary care/physician density is missing because no confirmed AHRF workforce input has been supplied."
  )
}

ahrf_candidate_file <- here("data_processed", "ahrf_expected_manual_columns.csv")
tibble(
  expected_column = c(
    "state",
    "year",
    "cardiologists_count",
    "primary_care_physicians_count",
    "total_physicians_count",
    "state_population",
    "cardiologists_per_100k",
    "primary_care_physicians_per_100k",
    "total_physicians_per_100k",
    "source_file",
    "notes"
  )
) %>%
  write_csv(ahrf_candidate_file)
record_file_written(ahrf_candidate_file)
diagnostics_written <- c(diagnostics_written, relative_path(ahrf_candidate_file))

# ------------------------------------------------------------
# 10. Build final state-year covariate dataset
# ------------------------------------------------------------

state_year_covariates <- state_year_grid %>%
  left_join(medicaid_expansion_covariates, by = c("state", "year")) %>%
  left_join(census_covariates, by = c("state", "year")) %>%
  left_join(rurality_state, by = c("state", "year")) %>%
  left_join(svi_state_year, by = c("state", "year")) %>%
  left_join(hf_state_year, by = c("state", "year")) %>%
  left_join(diabetes_state_year, by = c("state", "year")) %>%
  left_join(ckd_state_year, by = c("state", "year")) %>%
  left_join(workforce_state_year, by = c("state", "year")) %>%
  arrange(state, year)

check_expected_state_year_grid(state_year_covariates, "Final state-year covariate table")

if (any(state_year_covariates$year == 2020)) {
  stop("2020 is present in state_year_covariates.")
}

if (any(!state_year_covariates$state %in% valid_50dc)) {
  stop("Non-50DC state code is present in state_year_covariates.")
}

core_covariate_cols <- c(
  "medicaid_expansion_status",
  "medicaid_expansion_effective_date",
  "census_region",
  "census_division",
  "rurality_measure",
  "rurality_measure_source",
  "svi_state",
  "svi_source_year",
  "hf_prevalence",
  "hf_prevalence_source",
  "diabetes_prevalence",
  "diabetes_prevalence_source",
  "ckd_prevalence",
  "ckd_prevalence_source",
  "cardiologists_per_100k",
  "cardiologist_density_source",
  "primary_care_physicians_per_100k",
  "physician_density_source"
)

missing_core_cols <- setdiff(core_covariate_cols, names(state_year_covariates))

if (length(missing_core_cols) > 0) {
  stop("Final covariate table is missing required columns: ", paste(missing_core_cols, collapse = ", "))
}

state_year_covariates <- state_year_covariates %>%
  select(
    state,
    year,
    all_of(core_covariate_cols),
    everything()
  )

missingness_report <- make_missingness_report(state_year_covariates, core_covariate_cols)

write_csv(state_year_covariates, covariate_output_file)
write_csv(missingness_report, missingness_output_file)
record_file_written(covariate_output_file)
record_file_written(missingness_output_file)

message("Final covariate table dimensions:")
print(dim(state_year_covariates))

message("Final covariate state counts by year:")
print(state_year_covariates %>% count(year, name = "n_states"))

message("Covariate missingness report:")
print(missingness_report, n = Inf)

# ------------------------------------------------------------
# 11. Merge covariates to quarterly SGLT2 rate files
# ------------------------------------------------------------

merge_covariates_to_quarterly <- function(input_file, output_file, covariates) {
  if (!file.exists(input_file)) {
    warning("Quarterly SGLT2 input file not found, skipping: ", input_file)
    return(tibble())
  }

  quarterly <- read_csv(input_file, show_col_types = FALSE) %>%
    clean_names() %>%
    mutate(
      state = standardise_state(state),
      year = as.integer(year),
      quarter = as.integer(quarter)
    )

  message("Merging covariates to ", basename(input_file))
  message("Input rows: ", nrow(quarterly))

  if (any(quarterly$year == 2020)) {
    stop("2020 is present in ", input_file)
  }

  if (any(!quarterly$state %in% valid_50dc)) {
    bad_states <- quarterly %>%
      filter(!state %in% valid_50dc) %>%
      distinct(state) %>%
      pull(state)

    stop("Non-50DC state code(s) in ", input_file, ": ", paste(bad_states, collapse = ", "))
  }

  if ("medicaid_enrolment" %in% names(quarterly) && any(is.na(quarterly$medicaid_enrolment))) {
    missing_enrolment <- quarterly %>%
      filter(is.na(medicaid_enrolment)) %>%
      select(state, year, quarter)

    save_diagnostic(
      missing_enrolment,
      paste0(tools::file_path_sans_ext(basename(output_file)), "_missing_medicaid_enrolment.csv")
    )

    stop("Missing Medicaid enrolment in ", input_file)
  }

  merged <- quarterly %>%
    left_join(covariates, by = c("state", "year")) %>%
    arrange(state, year, quarter)

  if (nrow(merged) != nrow(quarterly)) {
    stop("Row count changed during covariate merge for ", input_file)
  }

  missing_covariate_summary <- make_missingness_report(merged, core_covariate_cols)

  message("Rows by year-quarter for ", basename(output_file), ":")
  print(
    merged %>%
      count(year, quarter, name = "n_rows") %>%
      arrange(year, quarter),
    n = Inf
  )

  message("State counts by year-quarter for ", basename(output_file), ":")
  state_quarter_counts <- merged %>%
    count(year, quarter, name = "n_states") %>%
    arrange(year, quarter)
  print(state_quarter_counts, n = Inf)

  unexpected_state_quarters <- state_quarter_counts %>%
    filter(n_states != 51)

  if (nrow(unexpected_state_quarters) > 0) {
    warning(
      basename(output_file),
      " has year-quarters with != 51 states. This may be expected only if the denominator source is incomplete."
    )
  }

  message("Covariate missingness after merge for ", basename(output_file), ":")
  print(missing_covariate_summary, n = Inf)

  write_csv(merged, output_file)
  record_file_written(output_file)

  merged
}

merged_main <- merge_covariates_to_quarterly(
  main_sglt2_file,
  main_sglt2_covariate_file,
  state_year_covariates
)

merged_sensitivity <- pmap(
  sensitivity_rate_files,
  function(input_file, output_file) {
    merge_covariates_to_quarterly(input_file, output_file, state_year_covariates)
  }
)

# ------------------------------------------------------------
# 12. Documentation
# ------------------------------------------------------------

missingness_markdown <- missingness_report %>%
  mutate(
    percent_missing = round(percent_missing, 1),
    affected_years = if_else(affected_years == "", "None", affected_years),
    affected_states = if_else(affected_states == "", "None", affected_states)
  ) %>%
  transmute(
    line = paste0(
      "- ",
      covariate_name,
      ": ",
      number_missing,
      " missing (",
      percent_missing,
      "%); years: ",
      affected_years,
      "; states: ",
      affected_states
    )
  ) %>%
  pull(line) %>%
  paste(collapse = "\n")

diagnostics_markdown <- if (length(diagnostics_written) == 0) {
  "- None"
} else {
  paste0("- ", unique(diagnostics_written), collapse = "\n")
}

residual_issues_markdown <- if (length(residual_issues) == 0) {
  "- None identified beyond source-specific limitations."
} else {
  paste0("- ", unique(residual_issues), collapse = "\n")
}

doc_lines <- c(
  "# Covariate construction report and limitations",
  "",
  "## Purpose",
  "",
  "This document describes construction of the state-year covariate dataset used for the Medicaid SDUD SGLT2 inhibitor uptake study. State-year covariates are merged to state-quarter prescribing-rate outcomes by `state` and `year`.",
  "",
  "## Analysis years and jurisdiction restrictions",
  "",
  "- Analysis years: 2015-2019 and 2021-2025.",
  "- Excluded year: 2020, because the available SDUD source currently contains only Q4.",
  "- Jurisdictions: 50 U.S. states plus the District of Columbia.",
  "- Excluded reporting areas: PR, XX, territories, national totals, and unknown rows.",
  "- Expected state-year grid: 51 jurisdictions x 10 years = 510 rows.",
  "",
  "## Sources attempted",
  "",
  "- KFF Medicaid Expansion Tracker: https://www.kff.org/medicaid/status-of-state-medicaid-expansion-decisions/",
  "- U.S. Census region/division stable state lookup.",
  "- USDA ERS Rural-Urban Continuum Codes 2023: https://www.ers.usda.gov/data-products/rural-urban-continuum-codes/",
  "- CDC/ATSDR SVI data downloads: https://svi.cdc.gov/dataDownloads/data-download.html",
  "- CDC PLACES county data via Data.CDC.gov Socrata endpoints: https://www.cdc.gov/places/",
  "- CMS Medicare Chronic Conditions / Chronic Conditions Warehouse state-level chronic condition data.",
  "- HRSA Area Health Resources Files: https://data.hrsa.gov/data/download/",
  "",
  "## Sources successfully used",
  "",
  "- Medicaid expansion: manually coded CSV created at `data_raw/covariates/medicaid_expansion_status.csv`, based on the KFF tracker. Mid-year dates should be manually confirmed before final manuscript submission.",
  "- Census region/division: internal stable lookup in `scripts/04_build_state_year_covariates.R`.",
  "- Rurality: USDA ERS RUCC 2023 county data downloaded to `data_raw/covariates/Ruralurbancontinuumcodes2023.csv`.",
  "- SVI: CDC/ATSDR county SVI CSVs for 2014, 2016, 2018, 2020, and 2022 downloaded to `data_raw/covariates/`.",
  "- Diabetes and CKD: CDC PLACES county data queried from Data.CDC.gov endpoints and saved as filtered raw files in `data_raw/covariates/`.",
  "- Heart failure: no confirmed programmatic state-year file was identified; a manual input template was created.",
  "- Workforce density: no confirmed AHRF field mapping was available locally; a manual input template and expected-field diagnostic were created.",
  "",
  "## Source-specific construction details",
  "",
  "### Medicaid expansion construction",
  "",
  "Source URL: https://www.kff.org/medicaid/status-of-state-medicaid-expansion-decisions/",
  "",
  "The script creates or reads `data_raw/covariates/medicaid_expansion_status.csv` with columns `state`, `expansion_adopted`, `expansion_effective_date`, and `notes`. The default covariate is `medicaid_expansion_status`, defined as `medicaid_expansion_status_any_year`: 1 if expansion was active for any month in the calendar year, 0 otherwise. The script also creates `medicaid_expansion_status_full_year`, defined as 1 only if expansion was active on January 1 of the year.",
  "",
  "Missing `medicaid_expansion_effective_date` values are expected for states that had not adopted ACA Medicaid expansion by the analysis period.",
  "",
  "### Census region/division construction",
  "",
  "Census region and division are stable state-level classifications and are manually coded inside the script. They are time-invariant across all analysis years.",
  "",
  "### Rurality construction",
  "",
  "Source URL: https://www.ers.usda.gov/data-products/rural-urban-continuum-codes/",
  "",
  "The script downloads USDA ERS RUCC 2023 county-level data. The primary `rurality_measure` is the percentage of each state's 2020 county population living in nonmetro counties, defined as RUCC codes 4-9. The measure is treated as time-invariant for 2015-2019 and 2021-2025. Additional columns include population-weighted mean RUCC and unweighted mean RUCC.",
  "",
  "### SVI construction",
  "",
  "Source URL: https://svi.cdc.gov/dataDownloads/data-download.html",
  "",
  "The script downloads county-level CDC/ATSDR SVI files for 2014, 2016, 2018, 2020, and 2022. State-level SVI is calculated as a population-weighted mean of county `RPL_THEMES`, using county `E_TOTPOP` as the weight. Each analysis year is matched to the nearest available SVI source year; ties use the earlier source year because source years are sorted before matching. `svi_source_year` records the matched source year.",
  "",
  "### Diabetes prevalence construction",
  "",
  "Source URL: https://www.cdc.gov/places/",
  "",
  "The script queries CDC PLACES county data endpoints for rows with `measureid == DIABETES`. State-level prevalence is calculated as a population-weighted mean of county crude prevalence estimates. The preferred weight is `totalpop18plus`; if unavailable, `totalpopulation` is used. Each analysis year is matched to the nearest available PLACES source year.",
  "",
  "### CKD prevalence construction",
  "",
  "Source URL: https://www.cdc.gov/places/",
  "",
  "The script queries CDC PLACES county data endpoints for rows with `measureid == KIDNEY`. State-level prevalence is calculated using the same method as diabetes. Current PLACES releases may not include CKD, so later analysis years may use the nearest earlier PLACES source year. This is documented in `ckd_prevalence_source` and related source-year columns.",
  "",
  "### Heart failure prevalence construction",
  "",
  "Preferred source: CMS Medicare Chronic Conditions / Chronic Conditions Warehouse state-level chronic condition data.",
  "",
  "No clean, confidently identified state-year heart failure prevalence file was available in the project at construction time. The script creates the expected manual input file `data_raw/covariates/medicare_chronic_conditions_state_year.csv`. Until that file is populated and verified, `hf_prevalence` remains missing. This covariate should be interpreted as Medicare heart failure prevalence, not Medicaid-specific or all-adult prevalence.",
  "",
  "### Cardiologist and physician density construction",
  "",
  "Preferred source: HRSA Area Health Resources Files (AHRF), https://data.hrsa.gov/data/download/",
  "",
  "No local AHRF file and technical documentation were available with confidently identified cardiologist, primary care physician, and population fields. The script creates the expected manual input file `data_raw/covariates/ahrf_state_year_workforce.csv` and writes `data_processed/ahrf_expected_manual_columns.csv`. Until populated and verified, `cardiologists_per_100k` and `primary_care_physicians_per_100k` remain missing.",
  "",
  "## Missingness summary",
  "",
  missingness_markdown,
  "",
  "## Diagnostics generated",
  "",
  diagnostics_markdown,
  "",
  "## Limitations",
  "",
  "- Medicaid expansion dates, especially mid-year implementations and Maine retroactivity, should be manually confirmed before final modelling.",
  "- SVI is not annual, so nearest-year matching is used.",
  "- SVI and PLACES county aggregation is population-weighted when population fields are available, but still collapses within-state heterogeneity into a state-level measure.",
  "- PLACES estimates are model-based small-area estimates and should not be interpreted as direct survey estimates.",
  "- CKD may not be available in the newest PLACES releases, so later years may use older nearest-source values.",
  "- Medicare HF prevalence is a proxy for state HF burden and may not reflect Medicaid-specific HF burden.",
  "- Workforce density requires careful AHRF field identification; values are left missing until fields are confirmed.",
  "- Some covariates are time-invariant or nearest-year values, while the outcome is quarterly.",
  "- State-level covariates cannot capture within-state rurality, deprivation, disease burden, or physician-supply gradients.",
  "- 2020 is excluded because SDUD was incomplete in the available source.",
  "- 2025 enrolment is currently available only through Q2 in the denominator source used for the SGLT2 rate files.",
  "",
  "## Residual issues for manual review",
  "",
  residual_issues_markdown,
  "",
  "## Recommended sensitivity analyses",
  "",
  "- Repeat main models using single-agent SGLT2 inhibitor products only.",
  "- Repeat main models using empagliflozin/dapagliflozin only.",
  "- Exclude 2021 to assess sensitivity to COVID-era disruption and transitional uptake after HF/CKD indication expansion.",
  "- Compare any-year versus full-year Medicaid expansion status for mid-year expansion states.",
  "- Refit models after replacing proxy or nearest-year covariates with confirmed annual state-year sources if those become available.",
  ""
)

write_lines(doc_lines, limitations_doc_file)
record_file_written(limitations_doc_file)

# ------------------------------------------------------------
# 13. Final console summary
# ------------------------------------------------------------

message("\nFinal covariate table dimensions:")
print(dim(state_year_covariates))

message("\nExpected vs actual state-year counts:")
print(
  tibble(
    expected_state_year_rows = expected_n_state_years,
    actual_state_year_rows = nrow(state_year_covariates)
  )
)

message("\nMissingness summary:")
print(missingness_report, n = Inf)

message("\nMerged quarterly main file dimensions:")
print(dim(merged_main))

message("\nFiles written:")
print(unique(files_written))

message("\nDone building state-year covariates and merged quarterly analysis files.")
