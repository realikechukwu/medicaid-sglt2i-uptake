# Data Dictionary

Date: 2026-05-04

## Final Input Datasets

- `data_raw/ndc_lookup/product.txt`: FDA product-level NDC file.
- `data_raw/ndc_lookup/package.txt`: FDA package-level NDC file.
- `data_raw/sdud/*.csv`: annual Medicaid SDUD raw files, 2015-2025.
- `data_raw/medicaid_enrolment/medicaid-enrollment-new-adult-group-02052026.csv`: CMS monthly Medicaid enrolment source.
- `data_raw/covariates/ahrf/AHRFDashboard*.xlsx`: AHRF physician density dashboards.
- `data_raw/covariates/mmd/mmd_data_*.csv`: CMS Mapping Medicare Disparities condition prevalence extracts.
- `data_raw/covariates/rucc/Ruralurbancontinuumcodes2023.csv`: county RUCC 2023 file.
- `data_raw/covariates/svi/SVI_2022_US_county.csv`: county SVI 2022 file.
- `data_raw/covariates/medicaid_expansion/medicaid_expansion_status.csv`: state Medicaid expansion status and effective dates.

## Final Derived Datasets

- `data_processed/ndc_lookup/sglt2_ndc_11_digit_list.csv`: final SGLT2 11-digit NDC lookup.
- `data_processed/sdud_extracts/sdud_sglt2_row_level_2015_2025.csv`: row-level SDUD SGLT2 extract.
- `data_processed/sdud_extracts/sglt2_state_quarter_all_products_2015_2025.csv`: all SGLT2 products by state-quarter.
- `data_processed/sdud_extracts/sglt2_state_quarter_single_agent_2015_2025.csv`: single-agent SGLT2 products by state-quarter.
- `data_processed/sdud_extracts/sglt2_state_quarter_empa_dapa_2015_2025.csv`: empagliflozin/dapagliflozin products by state-quarter.
- `data_processed/enrolment/medicaid_enrolment_state_quarter.csv`: state-quarter Medicaid denominator.
- `data_processed/covariates/*.csv`: final cleaned state-level covariates.

## Master Tables

- `for_analysis/master/master_state_quarter_sglt2_covariates.csv`: primary all-products master table.
- `for_analysis/master/master_state_quarter_sglt2_covariates_with_sensitivity_outcomes.csv`: master table with sensitivity outcomes.

Key columns:

- `state`, `year`, `quarter`: state-quarter key.
- `quarter_start_date`, `quarter_end_date`: calendar quarter bounds.
- `medicaid_enrolment_quarter_avg`: average monthly total Medicaid enrolment within the state-quarter.
- `log_medicaid_enrolment`: created in modelling scripts as the offset.

## Outcomes

- `sglt2_prescriptions_all_products`: primary quarterly prescription count.
- `sglt2_prescriptions_single_agent`: single-agent sensitivity prescription count.
- `sglt2_prescriptions_empa_dapa`: empagliflozin/dapagliflozin sensitivity prescription count.

Rates:

- `sglt2_prescriptions_all_products_per_10000`
- `sglt2_prescriptions_single_agent_per_10000`
- `sglt2_prescriptions_empa_dapa_per_10000`

All rates use `medicaid_enrolment_quarter_avg`.

## Exposures and Covariates

- Rurality: `rucc_nonmetro_population_share_2023`, `rurality_quintile`, `rurality_quintile_label`
- SVI: `svi_2022`, `svi_2022_per_0_1`
- Medicaid expansion: `medicaid_expansion_active`, `medicaid_expansion_active_any_part_quarter`
- Physician density: `cvd_physicians_per_100k_2023`, `primary_care_physicians_per_100k_2023`, `physicians_per_100k_2023`
- Disease burden: `medicare_ffs_hf_ihd_prevalence_2023`, `medicare_ffs_diabetes_prevalence_2023`, `medicare_ffs_ckd_prevalence_2023`
- Region: `census_region`, `census_division`

## Model Output Files

- `main_model_key_results.csv`
- `main_model_full_coefficients.csv`
- `main_model_full_cluster_robust_coefficients.csv`
- `sensitivity_outcome_comparison_key_results.csv`
- `region_adjusted_key_results.csv`
- `region_adjusted_vs_main_key_results.csv`
- `descriptive_national_quarterly_trend.csv`
- `descriptive_rurality_quarterly_trend.csv`
- `descriptive_svi_quarterly_trend.csv`
- `descriptive_state_summary.csv`
- `sequential_models_key_results.csv`: Models 1-7 key associations (sequential adjustment series)
- `sequential_models_cluster_robust_coefficients.csv`: all coefficients for Models 1-5
- `model_diagnostics_summary.csv`
- `poisson_overdispersion_check.csv`
- `master_missingness_report.csv`

## Manuscript Tables

In `for_analysis/manuscript_tables/`, full precision, laid out as reported:

- `table1_state_characteristics.csv`: Table 1 Panels A and B, one row per state
- `table2_primary_model.csv`: Table 2, primary model (Model 6)
- `table3_primary_vs_region_adjusted.csv`: Table 3, primary vs region-adjusted model (Model 7)
- `table_supplement_sequential_models.csv`: sequential models 1-7
