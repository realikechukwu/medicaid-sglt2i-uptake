# Repo Cleanup Audit

Date: 2026-05-04

## Current Folder Structure

- `data_raw/`
  - `sdud/`: raw SDUD annual CSVs for 2015-2025.
  - `medicaid_enrolment/`: raw CMS Medicaid enrolment CSV.
  - `covariates/`: mixed raw covariates and manual/source files.
  - `covariates/downloaded_cv/`: AHRF Excel dashboard downloads.
  - `product.txt`, `package.txt`: FDA NDC source files.
- `data_processed/`: flat folder containing NDC lookup, SDUD extracts, rate files, enrolment denominators, covariates, and diagnostics/check files.
- `for_analysis/`
  - root: copied rate/covariate files, proof-of-concept master tables, and duplicate raw-like covariates.
  - `covariates/`: copied covariate inputs and derived covariates.
  - `model_outputs/`: model tables, diagnostics, descriptive tables, and staged coefficient exports.
  - `model_outputs/plots/`: final-looking model/descriptive PNGs.
- `figures/`: earlier descriptive PNG/PDF plots.
- `output/`: one earlier trend summary CSV.
- `docs/`: protocol, methods, modelling/master logs, source notes, and miscellaneous text/PDF documentation.
- `scripts/`: extraction, rate construction, covariate, master, modelling, sensitivity, and plotting scripts.

## R Scripts Found

- `scripts/01_import_inspect.R`: builds SGLT2 FDA NDC lookup, but includes interactive inspection calls and writes to flat `data_processed/`.
- `scripts/02_extract_sglt2_from_sdud.R`: older single-file SDUD extraction workflow, currently points to `data_raw/sdud-2025-updated.csv` rather than `data_raw/sdud/`.
- `scripts/03_multiyear_sdud_join.R`: multiyear SDUD extraction/aggregation across 2015-2025; appears required for reproducible row-level and state-quarter SGLT2 outputs.
- `scripts/03_create_state_quarter_rates.R`: builds Medicaid state-quarter denominators and SGLT2 state-quarter rate files; required logic but writes denominator alias `medicaid_enrolment`.
- `scripts/03_create_state_year_rates.R`: older state-year rate/enrolment workflow; superseded by state-quarter analysis.
- `scripts/04_build_state_year_covariates.R`: older broad covariate workflow; useful source logic but superseded by cleaner final covariate/master scripts.
- `scripts/extract_ahrf_physician_density.R`: extracts 2023 AHRF physician density; required logic.
- `scripts/clean_mmd_disease_burden_2023.R`: cleans CMS Mapping Medicare Disparities disease burden; required logic.
- `scripts/05_build_master_analysis_table_poc.R`: builds the state-quarter master table with strict checks; required logic but POC filename/comments and old paths.
- `scripts/05_plot_quarterly_state_trends.R`: earlier descriptive plotting; superseded by final table/figure script.
- `scripts/06_model_sglt2_prescribing_poc.R`: main model/descriptive figure workflow; required logic but writes many staged outputs and POC log.
- `scripts/07_sensitivity_outcomes_full_model_poc.R`: joins sensitivity outcomes and runs fully adjusted sensitivity models; required logic but POC filename/comments and old paths.
- `scripts/08_region_adjusted_sensitivity_poc.R`: region-adjusted sensitivity workflow; required logic but POC filename/comments and old paths.

## Important Input Files Found

- FDA NDC inputs:
  - `data_raw/product.txt`
  - `data_raw/package.txt`
- Raw SDUD annual files:
  - `data_raw/sdud/StateDrugUtilizationData-2015.csv`
  - `data_raw/sdud/StateDrugUtilizationData-2016.csv`
  - `data_raw/sdud/StateDrugUtilizationData-2017.csv`
  - `data_raw/sdud/StateDrugUtilizationData-2018.csv`
  - `data_raw/sdud/StateDrugUtilizationData-2019.csv`
  - `data_raw/sdud/sdud-2020-updated.csv`
  - `data_raw/sdud/sdud-2021-updated.csv`
  - `data_raw/sdud/sdud-2022-updated.csv`
  - `data_raw/sdud/sdud-2023-updated.csv`
  - `data_raw/sdud/sdud-2024-updated.csv`
  - `data_raw/sdud/sdud-2025-updated.csv`
- Raw Medicaid enrolment:
  - `data_raw/medicaid_enrolment/medicaid-enrollment-new-adult-group-02052026.csv`
- Raw covariates:
  - `data_raw/covariates/Ruralurbancontinuumcodes2023.csv`
  - `data_raw/covariates/SVI_2014_US_county.csv`
  - `data_raw/covariates/SVI_2016_US_county.csv`
  - `data_raw/covariates/SVI_2018_US_county.csv`
  - `data_raw/covariates/SVI_2020_US_county.csv`
  - `data_raw/covariates/SVI_2022_US_county.csv`
  - `data_raw/covariates/medicaid_expansion_status.csv`
  - `data_raw/covariates/ahrf_state_year_workforce.csv`
  - `data_raw/covariates/medicare_chronic_conditions_state_year.csv`
  - `data_raw/covariates/places_county_diabetes_ckd_*.csv`
  - `data_raw/covariates/downloaded_cv/AHRFDashboard*.xlsx`
- Second-analysis/imported-style inputs currently in `for_analysis/`:
  - `for_analysis/covariates/mmd_data_hf_ihd.csv`
  - `for_analysis/covariates/mmd_data_dm.csv`
  - `for_analysis/covariates/mmd_data_ckd.csv`
  - `for_analysis/covariates/SVI_2022_US_county.csv`
  - `for_analysis/covariates/Ruralurbancontinuumcodes2023.csv`
  - `for_analysis/covariates/medicaid_expansion_status.csv`

## Important Output Files Found

- NDC lookup and extracted SDUD outputs:
  - `data_processed/sglt2_ndc_11_digit_list.csv`
  - `data_processed/sglt2_ndc_11_digit_list.rds`
  - `data_processed/sglt2_products_found.csv`
  - `data_processed/sdud_sglt2_row_level_2015_2025.csv`
  - `data_processed/sglt2_state_quarter_all_products_2015_2025.csv`
  - `data_processed/sglt2_state_quarter_single_agent_2015_2025.csv`
  - `data_processed/sglt2_state_quarter_empa_dapa_2015_2025.csv`
  - `data_processed/sglt2_state_quarter_by_drug_2015_2025.csv`
  - `data_processed/sglt2_state_quarter_by_product_type_2015_2025.csv`
- Enrolment and rate outputs:
  - `data_processed/medicaid_enrolment_state_quarter.csv`
  - `data_processed/medicaid_enrolment_state_year.csv`
  - `data_processed/sglt2_state_quarter_rates_all_products_50dc_excluding_2020.csv`
  - `data_processed/sglt2_state_quarter_rates_single_agent_50dc_excluding_2020.csv`
  - `data_processed/sglt2_state_quarter_rates_empa_dapa_50dc_excluding_2020.csv`
  - `data_processed/sglt2_national_quarterly_rates_50dc_excluding_2020.csv`
  - state-year rate outputs in `data_processed/` appear superseded for final analysis.
- Covariate outputs:
  - `for_analysis/ahrf_physician_density_2023_50dc.csv`
  - `for_analysis/mmd_disease_burden_2023_50dc.csv`
  - `for_analysis/rucc_state_rurality_2023.csv`
  - `for_analysis/svi_state_aggregates_by_source_year.csv`
  - `data_processed/places_state_aggregates_diabetes_ckd_by_source_year.csv`
  - `data_processed/state_year_covariates_2015_2025_excluding_2020.csv`
- Master tables:
  - `for_analysis/master_state_quarter_sglt2_covariates_poc.csv`
  - `for_analysis/master_state_quarter_sglt2_covariates_with_sensitivity_outcomes_poc.csv`
  - `for_analysis/master_state_quarter_sglt2_covariates_with_region_poc.csv`
- Model/descriptive outputs:
  - `for_analysis/model_outputs/key_results_summary.csv`
  - `for_analysis/model_outputs/model_6_full_covariate_coefficients.csv`
  - `for_analysis/model_outputs/model_6_full_covariate_cluster_robust_coefficients.csv`
  - `for_analysis/model_outputs/sensitivity_outcome_comparison_key_results.csv`
  - `for_analysis/model_outputs/region_adjusted_key_results.csv`
  - `for_analysis/model_outputs/region_adjusted_vs_original_key_results.csv`
  - `for_analysis/model_outputs/descriptive_*_trend.csv`
  - `for_analysis/model_outputs/descriptive_state_summary.csv`
  - `for_analysis/model_outputs/model_diagnostics_summary.csv`
  - `for_analysis/model_outputs/poisson_overdispersion_check.csv`
  - `for_analysis/model_outputs/plots/*.png`

## Docs and Log Files Found

- `README.md`
- `for_analysis/README.md`
- `docs/2026-04-27_covariate_sourcing_and_analysis_log.md`
- `docs/2026-05-03_master_table_poc_log.md`
- `docs/2026-05-03_modelling_poc_log.md`
- `docs/analysis.txt`
- `docs/considerations.txt`
- `docs/covariate_construction_limitations.md`
- `docs/full-analysis-report.md`
- `docs/medicaid_enrolment_and_rate_construction.md`
- `docs/methods_sglt2_medicaid_study.md`
- `docs/osf_preregistration_protocol_original_plan_sglt2_medicaid.md`
- `docs/protocol.txt`
- `docs/sglt2-medicaid-research-protocol.pdf`

## CSV Outputs Found

- Final-looking outputs: NDC lookup, row-level SDUD extract, state-quarter SGLT2 extracts, Medicaid denominator files, final covariate summaries, master tables, descriptive tables, model tables, diagnostics.
- Superseded/diagnostic outputs: `check_sglt2_*`, state-year rates, `*_with_covariates_50dc_excluding_2020.csv`, copied `for_analysis/` rate/covariate files, `model_input_cleaned_all_products.csv`, staged model 0-5/S2 coefficient and summary exports, earlier `output/sglt2_state_quarter_rate_trend_summary_all_products_50dc_excluding_2020.csv`.
- Exact duplicate CSVs confirmed by SHA-256:
  - `data_processed/sglt2_state_quarter_rates_all_products_50dc_excluding_2020.csv` and `for_analysis/sglt2_state_quarter_rates_all_products_50dc_excluding_2020.csv`
  - `data_processed/sglt2_state_quarter_rates_single_agent_50dc_excluding_2020.csv` and `for_analysis/sglt2_state_quarter_rates_single_agent_50dc_excluding_2020.csv`
  - `data_processed/sglt2_state_quarter_rates_empa_dapa_50dc_excluding_2020.csv` and `for_analysis/sglt2_state_quarter_rates_empa_dapa_50dc_excluding_2020.csv`
  - `data_processed/sglt2_national_quarterly_rates_50dc_excluding_2020.csv` and `for_analysis/sglt2_national_quarterly_rates_50dc_excluding_2020.csv`
  - `data_processed/svi_state_aggregates_by_source_year.csv`, `for_analysis/svi_state_aggregates_by_source_year.csv`, and `for_analysis/covariates/svi_state_aggregates_by_source_year.csv`
  - `data_raw/covariates/Ruralurbancontinuumcodes2023.csv`, `for_analysis/Ruralurbancontinuumcodes2023.csv`, and `for_analysis/covariates/Ruralurbancontinuumcodes2023.csv`
  - `data_raw/covariates/medicaid_expansion_status.csv`, `for_analysis/medicaid_expansion_status.csv`, and `for_analysis/covariates/medicaid_expansion_status.csv`
  - `data_processed/medicaid_enrolment_state_quarter.csv` and `for_analysis/covariates/medicaid_enrolment_state_quarter.csv`
  - `data_processed/medicaid_enrolment_state_year.csv` and `for_analysis/covariates/medicaid_enrolment_state_year.csv`

## PNG Figures Found

- Earlier descriptive figures in `figures/`:
  - `sglt2_national_quarterly_rate_trends_by_definition.png`
  - `sglt2_quarterly_rate_state_facets_all_products.png`
  - `sglt2_quarterly_rate_state_facets_single_agent.png`
  - `sglt2_quarterly_rate_state_facets_empa_dapa.png`
  - `sglt2_quarterly_rate_state_heatmap_all_products.png`
- Final-looking figures in `for_analysis/model_outputs/plots/`:
  - `fig1_national_quarterly_sglt2_rate.png`
  - `fig2_rurality_quintile_quarterly_sglt2_rate.png`
  - `fig3_svi_quintile_quarterly_sglt2_rate.png`
  - `fig4_boxplot_rates_by_rurality_quintile.png`
  - `fig5_scatter_svi_vs_state_mean_rate.png`
  - `fig6_state_quarter_heatmap_sglt2_rate.png`
  - `fig7_forest_plot_full_model_irrs.png`
  - `fig8_forest_plot_region_adjusted_full_model_irrs.png`
  - `region_adjusted_full_model_forest_plot.png`
  - `sensitivity_outcome_comparison_forest_plot.png`

## Suspected Proof-of-Concept or Superseded Files

- Scripts with POC naming: `05_build_master_analysis_table_poc.R`, `06_model_sglt2_prescribing_poc.R`, `07_sensitivity_outcomes_full_model_poc.R`, `08_region_adjusted_sensitivity_poc.R`.
- POC/superseded master outputs: `master_state_quarter_sglt2_covariates_poc.csv`, `master_state_quarter_sglt2_covariates_with_sensitivity_outcomes_poc.csv`, `master_state_quarter_sglt2_covariates_with_region_poc.csv`, `master_poc_missingness_report.csv`.
- Staged model outputs not required for final reporting: `model_0_*`, `model_1_*`, `model_2_*`, `model_3_*`, `model_4_*`, `model_5_*`, `model_s2_*`, and associated summary TXT files.
- Earlier state-year outputs are not part of the final state-quarter analysis.
- Earlier root `figures/` and `output/` files appear superseded by final model output folders.
- Copied covariates/rate files in `for_analysis/` are duplicates of `data_raw/` or `data_processed/` files and should not remain in the main analysis area.

## Files Required for Final Reproducibility

- Raw FDA, SDUD, Medicaid enrolment, AHRF, MMD, RUCC, SVI, and Medicaid expansion source files.
- Final scripts in numbered order from NDC lookup through final tables/figures.
- Final processed outputs:
  - NDC lookup.
  - Row-level SGLT2 extract.
  - State-quarter SGLT2 outcome files.
  - Medicaid enrolment denominators.
  - Cleaned covariates.
  - Master analysis tables.
  - Final model/descriptive/diagnostic tables.
  - Final figures.
  - Final logs and documentation.

## Proposed Final Structure

```text
data_raw/
  sdud/
  medicaid_enrolment/
  covariates/
    ahrf/
    mmd/
    rucc/
    svi/
    medicaid_expansion/

data_processed/
  ndc_lookup/
  sdud_extracts/
  enrolment/
  covariates/

for_analysis/
  master/
  model_outputs/
    tables/
    figures/
    diagnostics/
    logs/

scripts/
  00_setup.R
  01_build_sglt2_ndc_lookup.R
  02_extract_sglt2_from_sdud.R
  03_build_medicaid_enrolment_denominators.R
  04_clean_covariates.R
  05_build_master_analysis_table.R
  06_model_main_analysis.R
  07_model_sensitivity_outcomes.R
  08_model_region_adjusted_sensitivity.R
  09_make_final_tables_and_figures.R
  run_all.R

docs/
  protocol/
  logs/
  methods/
  data_dictionary/

archive/
  old_outputs/
  old_scripts/
  poc_outputs/
  duplicate_files/
```

## Proposed Archive

- `archive/old_scripts/`: older scripts not in the final numbered sequence.
- `archive/poc_outputs/`: POC master/log/model outputs and staged coefficient/summary exports not needed in the final output folders.
- `archive/old_outputs/`: earlier state-year, check, flat `output/`, and root `figures/` outputs not part of final reporting.
- `archive/duplicate_files/`: exact duplicate copied inputs/outputs from `for_analysis/` and `for_analysis/covariates/` once canonical copies exist in `data_raw/`, `data_processed/`, or final `for_analysis/`.

## Proposed Keep

- Keep raw files under reorganized `data_raw/`.
- Keep final processed files under reorganized `data_processed/`.
- Keep final master tables under `for_analysis/master/`.
- Keep only final tables, figures, diagnostics, and logs under `for_analysis/model_outputs/`.
- Keep final protocol/methods/data dictionary under `docs/`.
- Keep this audit and the file move plan under `docs/logs/`.
