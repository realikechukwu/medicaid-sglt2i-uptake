# ============================================================
# Extract AHRF physician density files into one wide CSV
# ============================================================

library(tidyverse)
library(readxl)
library(janitor)
library(here)
library(stringr)

input_dir <- here("data_raw", "covariates","downloaded_cv")
output_file <- here("for_analysis", "ahrf_physician_density_2023_50dc.csv")

dir.create(here("for_analysis"), showWarnings = FALSE, recursive = TRUE)

state_xwalk <- tibble(
  state_name = c(state.name, "District of Columbia"),
  state = c(state.abb, "DC")
)

valid_50dc <- state_xwalk$state

ahrf_files <- list.files(
  input_dir,
  pattern = "AHRFDashboard.*\\.xlsx$",
  full.names = TRUE
)

if (length(ahrf_files) == 0) {
  stop("No AHRFDashboard Excel files found in data_raw/covariates/")
}

print(ahrf_files)

classify_physician_file <- function(file_path) {
  preview <- read_excel(
    file_path,
    sheet = "AHRF Geo Data",
    col_names = FALSE,
    n_max = 4
  )
  
  text <- preview %>%
    mutate(across(everything(), as.character)) %>%
    unite("text", everything(), sep = " | ", na.rm = TRUE) %>%
    pull(text) %>%
    paste(collapse = " | ") %>%
    str_to_lower()
  
  if (str_detect(text, "cardiovascular disease")) {
    return("cvd_physicians")
  }
  
  if (str_detect(text, "primary care")) {
    return("primary_care_physicians")
  }
  
  if (str_detect(text, "all m\\.d|all m\\.d\\.|all md|all m d")) {
    return("physicians")
  }
  
  stop("Could not classify physician type for: ", basename(file_path))
}

read_one_ahrf_file <- function(file_path) {
  
  physician_type <- classify_physician_file(file_path)
  
  message("Reading ", basename(file_path), " as ", physician_type)
  
  dat_raw <- read_excel(
    file_path,
    sheet = "AHRF Geo Data",
    skip = 3
  )
  
  # Keep the original names first
  original_names <- names(dat_raw)
  print(original_names)
  
  dat <- dat_raw %>%
    clean_names()
  
  print(names(dat))
  
  state_col <- names(dat)[str_detect(names(dat), "^state")]
  pop_col <- names(dat)[str_detect(names(dat), "^population")]
  rate_col <- names(dat)[str_detect(names(dat), "^rate")]
  source_col <- names(dat)[str_detect(names(dat), "^source")]
  
  count_col <- setdiff(
    names(dat),
    c(state_col, pop_col, rate_col, source_col)
  )
  
  count_col <- count_col[!str_detect(count_col, "^x[0-9]+$|^\\.\\.\\.")]
  
  if (length(state_col) != 1) {
    stop("Could not identify state column in ", basename(file_path))
  }
  
  if (length(pop_col) != 1) {
    print(names(dat))
    stop("Could not identify population column in ", basename(file_path))
  }
  
  if (length(rate_col) != 1) {
    print(names(dat))
    stop("Could not identify rate column in ", basename(file_path))
  }
  
  if (length(count_col) != 1) {
    print(names(dat))
    stop(
      "Could not identify a single physician count column in ",
      basename(file_path),
      ". Candidate count columns: ",
      paste(count_col, collapse = ", ")
    )
  }
  out <- dat %>%
    transmute(
      state_name = str_squish(as.character(.data[[state_col]])),
      population = as.numeric(.data[[pop_col]]),
      !!paste0("number_", physician_type) := as.numeric(.data[[count_col]]),
      !!paste0(physician_type, "_per_100k") := as.numeric(.data[[rate_col]]),
      !!paste0(physician_type, "_source") :=
        if (length(source_col) == 1) as.character(.data[[source_col]]) else NA_character_
    ) %>%
    inner_join(state_xwalk, by = "state_name") %>%
    select(state, state_name, population, everything()) %>%
    arrange(state)
  
  out
}

ahrf_tables <- map(ahrf_files, read_one_ahrf_file)

wide <- reduce(
  ahrf_tables,
  function(x, y) {
    y_small <- y %>%
      select(-state_name, -population)
    
    left_join(x, y_small, by = "state")
  }
)

wide <- state_xwalk %>%
  left_join(
    wide %>% select(-state_name),
    by = "state"
  ) %>%
  filter(state %in% valid_50dc) %>%
  arrange(state)

if (nrow(wide) != 51) {
  stop("Expected 51 rows for 50 states + DC, got ", nrow(wide))
}

wide <- wide %>%
  mutate(
    physicians_per_100k_calculated =
      number_physicians / population * 100000,
    primary_care_physicians_per_100k_calculated =
      number_primary_care_physicians / population * 100000,
    cvd_physicians_per_100k_calculated =
      number_cvd_physicians / population * 100000
  ) %>%
  select(
    state,
    state_name,
    population,
    number_physicians,
    physicians_per_100k,
    physicians_per_100k_calculated,
    number_primary_care_physicians,
    primary_care_physicians_per_100k,
    primary_care_physicians_per_100k_calculated,
    number_cvd_physicians,
    cvd_physicians_per_100k,
    cvd_physicians_per_100k_calculated,
    everything()
  )

rate_check <- wide %>%
  transmute(
    state,
    physicians_rate_diff =
      abs(physicians_per_100k_calculated - physicians_per_100k),
    primary_care_rate_diff =
      abs(primary_care_physicians_per_100k_calculated -
            primary_care_physicians_per_100k),
    cvd_rate_diff =
      abs(cvd_physicians_per_100k_calculated -
            cvd_physicians_per_100k)
  )

print(summary(rate_check))

write_csv(wide, output_file)

message("Saved: ", output_file)
message("Rows: ", nrow(wide))
message("Columns:")
print(names(wide))