# File Move Plan

Date: 2026-05-04

This plan was created after the repository audit and before reorganising files. No files are to be deleted permanently. Superseded, duplicate, proof-of-concept, or exploratory files will be moved into `archive/`.

## Create Directories

- `data_raw/ndc_lookup/`
- `data_raw/covariates/ahrf/`
- `data_raw/covariates/mmd/`
- `data_raw/covariates/rucc/`
- `data_raw/covariates/svi/`
- `data_raw/covariates/medicaid_expansion/`
- `data_processed/ndc_lookup/`
- `data_processed/sdud_extracts/`
- `data_processed/enrolment/`
- `data_processed/covariates/`
- `for_analysis/master/`
- `for_analysis/model_outputs/tables/`
- `for_analysis/model_outputs/figures/`
- `for_analysis/model_outputs/diagnostics/`
- `for_analysis/model_outputs/logs/`
- `docs/protocol/`
- `docs/logs/`
- `docs/methods/`
- `docs/data_dictionary/`
- `archive/old_outputs/`
- `archive/old_scripts/`
- `archive/poc_outputs/`
- `archive/duplicate_files/`

## Raw Inputs to Canonical Locations

- Move `data_raw/product.txt` to `data_raw/ndc_lookup/product.txt`.
- Move `data_raw/package.txt` to `data_raw/ndc_lookup/package.txt`.
- Move `data_raw/covariates/downloaded_cv/AHRFDashboard*.xlsx` to `data_raw/covariates/ahrf/`.
- Move `for_analysis/covariates/mmd_data_hf_ihd.csv` to `data_raw/covariates/mmd/mmd_data_hf_ihd.csv`.
- Move `for_analysis/covariates/mmd_data_dm.csv` to `data_raw/covariates/mmd/mmd_data_dm.csv`.
- Move `for_analysis/covariates/mmd_data_ckd.csv` to `data_raw/covariates/mmd/mmd_data_ckd.csv`.
- Move `data_raw/covariates/Ruralurbancontinuumcodes2023.csv` to `data_raw/covariates/rucc/Ruralurbancontinuumcodes2023.csv`.
- Move `data_raw/covariates/SVI_*.csv` to `data_raw/covariates/svi/`.
- Move `data_raw/covariates/medicaid_expansion_status.csv` to `data_raw/covariates/medicaid_expansion/medicaid_expansion_status.csv`.

## Raw or Source-Like Files to Archive

- Move old PLACES/county covariate files from `data_raw/covariates/places_county_diabetes_ckd_*.csv` to `archive/old_outputs/old_covariate_inputs/`.
- Move older manual/state-year covariate inputs from:
  - `data_raw/covariates/ahrf_state_year_workforce.csv`
  - `data_raw/covariates/medicare_chronic_conditions_state_year.csv`
  to `archive/old_outputs/old_covariate_inputs/`.

## Processed Outputs to Canonical Locations

- Move `data_processed/sglt2_ndc_11_digit_list.csv` to `data_processed/ndc_lookup/sglt2_ndc_11_digit_list.csv`.
- Move `data_processed/sdud_sglt2_row_level_2015_2025.csv` to `data_processed/sdud_extracts/sdud_sglt2_row_level_2015_2025.csv`.
- Move state-quarter SGLT2 count files to `data_processed/sdud_extracts/`:
  - `sglt2_state_quarter_all_products_2015_2025.csv`
  - `sglt2_state_quarter_single_agent_2015_2025.csv`
  - `sglt2_state_quarter_empa_dapa_2015_2025.csv`
- Move `data_processed/medicaid_enrolment_state_quarter.csv` to `data_processed/enrolment/medicaid_enrolment_state_quarter.csv`.
- Move `data_processed/medicaid_enrolment_state_year.csv` to `data_processed/enrolment/medicaid_enrolment_state_year.csv`.
- Move final covariate outputs to `data_processed/covariates/`:
  - `for_analysis/ahrf_physician_density_2023_50dc.csv`
  - `for_analysis/mmd_disease_burden_2023_50dc.csv`
  - `for_analysis/rucc_state_rurality_2023.csv`
  - `for_analysis/svi_state_aggregates_by_source_year.csv`

## Analysis Outputs to Canonical Locations

- Move `for_analysis/master_state_quarter_sglt2_covariates_poc.csv` to `for_analysis/master/master_state_quarter_sglt2_covariates.csv` after standardising final outcome names.
- Move `for_analysis/master_state_quarter_sglt2_covariates_with_sensitivity_outcomes_poc.csv` to `for_analysis/master/master_state_quarter_sglt2_covariates_with_sensitivity_outcomes.csv`.
- Move final model/descriptive tables to `for_analysis/model_outputs/tables/` using final names:
  - `key_results_summary.csv` to `main_model_key_results.csv`
  - `model_6_full_covariate_coefficients.csv` to `main_model_full_coefficients.csv`
  - `model_6_full_covariate_cluster_robust_coefficients.csv` to `main_model_full_cluster_robust_coefficients.csv`
  - `sensitivity_outcome_comparison_key_results.csv`
  - `region_adjusted_key_results.csv`
  - `region_adjusted_vs_original_key_results.csv` to `region_adjusted_vs_main_key_results.csv`
  - `descriptive_national_quarterly_trend.csv`
  - `descriptive_rurality_quarterly_trend.csv`
  - `descriptive_svi_quarterly_trend.csv`
  - `descriptive_state_summary.csv`
- Move final diagnostics to `for_analysis/model_outputs/diagnostics/`:
  - `model_diagnostics_summary.csv`
  - `poisson_overdispersion_check.csv`
  - `master_poc_missingness_report.csv` to `master_missingness_report.csv`
- Move final figures to `for_analysis/model_outputs/figures/` using final names:
  - `fig1_national_quarterly_sglt2_rate.png`
  - `fig2_rurality_quintile_quarterly_sglt2_rate.png`
  - `fig3_svi_quintile_quarterly_sglt2_rate.png`
  - `fig4_boxplot_rates_by_rurality_quintile.png`
  - `fig5_scatter_svi_vs_state_mean_rate.png`
  - `fig6_state_quarter_heatmap_sglt2_rate.png`
  - `fig7_forest_plot_full_model_irrs.png` to `fig7_main_model_forest_plot.png`
  - `sensitivity_outcome_comparison_forest_plot.png` to `fig8_sensitivity_outcome_comparison_forest_plot.png`
  - `region_adjusted_full_model_forest_plot.png` to `fig9_region_adjusted_forest_plot.png`

## Documentation to Canonical Locations

- Copy/move `docs/2026-05_repo_cleanup_audit.md` to `docs/logs/2026-05_repo_cleanup_audit.md`.
- Move `docs/2026-05-03_master_table_poc_log.md` to `docs/logs/2026-05_master_table_log.md`.
- Move `docs/2026-05-03_modelling_poc_log.md` to `docs/logs/2026-05_modelling_log.md`.
- Move `docs/osf_preregistration_protocol_original_plan_sglt2_medicaid.md` to `docs/protocol/osf_preregistration_protocol.md`.
- Move `docs/methods_sglt2_medicaid_study.md` to `docs/methods/methods_draft.md`.
- Create `docs/data_dictionary/data_dictionary.md`.

## Scripts to Archive and Replace

- Move existing non-final scripts to `archive/old_scripts/`.
- Create final numbered scripts in `scripts/`:
  - `00_setup.R`
  - `01_build_sglt2_ndc_lookup.R`
  - `02_extract_sglt2_from_sdud.R`
  - `03_build_medicaid_enrolment_denominators.R`
  - `04_clean_covariates.R`
  - `05_build_master_analysis_table.R`
  - `06_model_main_analysis.R`
  - `07_model_sensitivity_outcomes.R`
  - `08_model_region_adjusted_sensitivity.R`
  - `09_make_final_tables_and_figures.R`
  - `run_all.R`

## Files to Archive After Canonical Copies Exist

- Exact duplicate copied inputs/outputs under `for_analysis/` and `for_analysis/covariates/`.
- State-year SGLT2 outputs.
- `*_with_covariates_50dc_excluding_2020.csv` files.
- `check_sglt2_*` files.
- `sglt2_products_found.csv` and `sglt2_ndc_11_digit_list.rds`.
- Earlier root `figures/` and `output/` folders.
- POC master/region copies and all staged model 0-5/S2 coefficient/summary exports not needed for final reporting.

## Manual Review Flags

- Raw SDUD files are several GB and should remain uncommitted.
- `data_raw/covariates/places_county_diabetes_ckd_*.csv`, `ahrf_state_year_workforce.csv`, and `medicare_chronic_conditions_state_year.csv` appear superseded by final AHRF/MMD/SVI/RUCC covariate workflow but are archived rather than deleted.
- `docs/sglt2-medicaid-research-protocol.pdf`, `docs/full-analysis-report.md`, and earlier free-text notes should be reviewed before deciding whether to keep, update, or archive in a later documentation pass.
