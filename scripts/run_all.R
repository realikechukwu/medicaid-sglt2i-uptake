# Run the complete Medicaid SDUD SGLT2 analysis from raw inputs to final outputs.
#
# Expected manual raw inputs before running (see README for download sources):
# - data_raw/ndc_lookup/product.txt
# - data_raw/ndc_lookup/package.txt
# - data_raw/sdud/StateDrugUtilizationData-2015.csv through StateDrugUtilizationData-2019.csv
# - data_raw/sdud/sdud-2020-updated.csv through sdud-2025-updated.csv
# - data_raw/medicaid_enrolment/medicaid-enrollment-new-adult-group-02052026.csv
# - data_raw/covariates/ahrf/AHRFDashboard*.xlsx
# - data_raw/covariates/mmd/mmd_data_hf_ihd.csv
# - data_raw/covariates/mmd/mmd_data_dm.csv
# - data_raw/covariates/mmd/mmd_data_ckd.csv
# - data_raw/covariates/rucc/Ruralurbancontinuumcodes2023.csv
# - data_raw/covariates/svi/SVI_2022_US_county.csv
# - data_raw/covariates/medicaid_expansion/medicaid_expansion_status.csv

# Diagnostics accumulate across scripts; start each full run from an empty file.
unlink(here::here("for_analysis", "model_outputs", "diagnostics", "model_diagnostics_summary.csv"))

source("scripts/00_setup.R")
source("scripts/01_build_sglt2_ndc_lookup.R")
source("scripts/02_extract_sglt2_from_sdud.R")
source("scripts/03_build_medicaid_enrolment_denominators.R")
source("scripts/04_clean_covariates.R")
source("scripts/05_build_master_analysis_table.R")
source("scripts/06_model_main_analysis.R")
source("scripts/07_model_sensitivity_outcomes.R")
source("scripts/08_model_region_adjusted_sensitivity.R")
source("scripts/09_model_sequential_series.R")
source("scripts/10_make_manuscript_tables.R")
source("scripts/11_check_final_outputs.R")
source("scripts/12_verify_manuscript_values.R")

writeLines(
  capture.output(sessionInfo()),
  here::here("docs", "logs", "r_session_info.txt")
)
