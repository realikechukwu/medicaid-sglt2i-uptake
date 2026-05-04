# ============================================================
# Clean CMS Mapping Medicare Disparities disease burden files
# HF/IHD, diabetes, CKD, 2023
# ============================================================

# Data source:

# https://data.cms.gov/tools/mapping-medicare-disparities-by-population

#
library(tidyverse)
library(janitor)
library(here)

# ------------------------------------------------------------
# 0. Paths
# ------------------------------------------------------------

input_dir <- here("for_analysis", "covariates")
output_file <- here("for_analysis", "mmd_disease_burden_2023_50dc.csv")

hf_file <- file.path(input_dir, "mmd_data_hf_ihd.csv")
dm_file <- file.path(input_dir, "mmd_data_dm.csv")
ckd_file <- file.path(input_dir, "mmd_data_ckd.csv")

dir.create(here("for_analysis"), showWarnings = FALSE, recursive = TRUE)

# ------------------------------------------------------------
# 1. State lookup
# ------------------------------------------------------------

state_xwalk <- tibble(
  state_name = toupper(c(state.name, "District of Columbia")),
  state_abbr = c(state.abb, "DC")
)

valid_50dc <- state_xwalk$state_abbr

# ------------------------------------------------------------
# 2. Helper function
# ------------------------------------------------------------

clean_mmd_file <- function(file_path) {
  
  if (!file.exists(file_path)) {
    stop("File not found: ", file_path)
  }
  
  message("Reading: ", basename(file_path))
  
  dat <- read_csv(file_path, show_col_types = FALSE) %>%
    clean_names()
  
  required_cols <- c(
    "population",
    "year",
    "geography",
    "measure",
    "adjustment",
    "analysis",
    "domain",
    "condition",
    "fips",
    "state",
    "primary_value",
    "primary_denominator"
  )
  
  missing_cols <- setdiff(required_cols, names(dat))
  
  if (length(missing_cols) > 0) {
    stop(
      "Missing required columns in ",
      basename(file_path),
      ": ",
      paste(missing_cols, collapse = ", ")
    )
  }
  
  dat_clean <- dat %>%
    mutate(
      state_name = str_squish(str_to_upper(state)),
      source_year = as.integer(year),
      value = as.numeric(primary_value),
      primary_denominator = as.character(primary_denominator)
    ) %>%
    inner_join(state_xwalk, by = "state_name") %>%
    filter(state_abbr %in% valid_50dc) %>%
    transmute(
      state = state_abbr,
      source_year,
      value,
      condition = condition,
      population_source = population,
      measure = measure,
      adjustment = adjustment,
      denominator_category = primary_denominator
    ) %>%
    arrange(state)
  
  if (nrow(dat_clean) != 51) {
    warning(
      basename(file_path),
      " has ",
      nrow(dat_clean),
      " rows after restricting to 50 states + DC. Expected 51."
    )
  }
  
  dat_clean
}

# ------------------------------------------------------------
# 3. Clean files and rename values explicitly
# ------------------------------------------------------------

hf <- clean_mmd_file(hf_file) %>%
  rename(
    medicare_ffs_hf_ihd_prevalence_2023 = value
  )

dm <- clean_mmd_file(dm_file) %>%
  rename(
    medicare_ffs_diabetes_prevalence_2023 = value
  )

ckd <- clean_mmd_file(ckd_file) %>%
  rename(
    medicare_ffs_ckd_prevalence_2023 = value
  )

# ------------------------------------------------------------
# 4. Check each cleaned file
# ------------------------------------------------------------

message("\nHF/IHD rows:")
print(nrow(hf))
print(names(hf))
print(summary(hf$medicare_ffs_hf_ihd_prevalence_2023))

message("\nDiabetes rows:")
print(nrow(dm))
print(names(dm))
print(summary(dm$medicare_ffs_diabetes_prevalence_2023))

message("\nCKD rows:")
print(nrow(ckd))
print(names(ckd))
print(summary(ckd$medicare_ffs_ckd_prevalence_2023))

# ------------------------------------------------------------
# 5. Combine into one wide table
# ------------------------------------------------------------

disease_burden <- hf %>%
  select(
    state,
    source_year,
    medicare_ffs_hf_ihd_prevalence_2023,
    hf_ihd_condition = condition,
    hf_ihd_population_source = population_source,
    hf_ihd_measure = measure,
    hf_ihd_adjustment = adjustment,
    hf_ihd_denominator_category = denominator_category
  ) %>%
  left_join(
    dm %>%
      select(
        state,
        medicare_ffs_diabetes_prevalence_2023,
        diabetes_condition = condition,
        diabetes_population_source = population_source,
        diabetes_measure = measure,
        diabetes_adjustment = adjustment,
        diabetes_denominator_category = denominator_category
      ),
    by = "state"
  ) %>%
  left_join(
    ckd %>%
      select(
        state,
        medicare_ffs_ckd_prevalence_2023,
        ckd_condition = condition,
        ckd_population_source = population_source,
        ckd_measure = measure,
        ckd_adjustment = adjustment,
        ckd_denominator_category = denominator_category
      ),
    by = "state"
  ) %>%
  mutate(
    disease_burden_source =
      "CMS Mapping Medicare Disparities, Medicare FFS, 2023",
    disease_burden_measure =
      "Prevalence percentage; unsmoothed age-standardized estimate",
    disease_burden_population =
      "Medicare fee-for-service beneficiaries"
  ) %>%
  arrange(state)

# ------------------------------------------------------------
# 6. Final checks
# ------------------------------------------------------------

if (nrow(disease_burden) != 51) {
  stop("Expected 51 rows for 50 states + DC, got ", nrow(disease_burden))
}

missing_summary <- disease_burden %>%
  summarise(
    missing_hf_ihd =
      sum(is.na(medicare_ffs_hf_ihd_prevalence_2023)),
    missing_diabetes =
      sum(is.na(medicare_ffs_diabetes_prevalence_2023)),
    missing_ckd =
      sum(is.na(medicare_ffs_ckd_prevalence_2023))
  )

message("\nMissingness summary:")
print(missing_summary)

message("\nDisease burden summary:")
disease_burden %>%
  summarise(
    hf_ihd_min = min(medicare_ffs_hf_ihd_prevalence_2023, na.rm = TRUE),
    hf_ihd_mean = mean(medicare_ffs_hf_ihd_prevalence_2023, na.rm = TRUE),
    hf_ihd_max = max(medicare_ffs_hf_ihd_prevalence_2023, na.rm = TRUE),
    
    diabetes_min = min(medicare_ffs_diabetes_prevalence_2023, na.rm = TRUE),
    diabetes_mean = mean(medicare_ffs_diabetes_prevalence_2023, na.rm = TRUE),
    diabetes_max = max(medicare_ffs_diabetes_prevalence_2023, na.rm = TRUE),
    
    ckd_min = min(medicare_ffs_ckd_prevalence_2023, na.rm = TRUE),
    ckd_mean = mean(medicare_ffs_ckd_prevalence_2023, na.rm = TRUE),
    ckd_max = max(medicare_ffs_ckd_prevalence_2023, na.rm = TRUE)
  ) %>%
  print()

message("\nStates included:")
print(disease_burden$state)

# ------------------------------------------------------------
# 7. Save output
# ------------------------------------------------------------

write_csv(disease_burden, output_file)

message("\nSaved: ", output_file)
message("Rows: ", nrow(disease_burden))
message("Columns:")
print(names(disease_burden))