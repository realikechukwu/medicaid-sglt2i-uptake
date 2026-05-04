# Full Analysis Report: Medicaid SDUD SGLT2 Inhibitor Uptake Proof-of-Concept

Report date: 2026-05-04

Project: Medicaid State Drug Utilization Data (SDUD) SGLT2 inhibitor uptake study

Status: Proof-of-concept analysis report for manuscript planning and audit. This document is intended to make the current workflow traceable before final JAHA-facing analysis decisions. It is not, by itself, a final causal analysis.

All paths below are relative to the project root:

`/Users/ikechukwuchukwudi/Documents/Academic/IMT-ACF Folder/Papers - Active/sglt2-may-2026`

## 1. Research Questions

The proof-of-concept workflow was built to address four main questions:

1. What is the pattern of Medicaid SGLT2 inhibitor prescribing over time?
2. Does SGLT2 inhibitor prescribing differ by state rurality?
3. Is state-level social vulnerability associated with SGLT2 inhibitor prescribing?
4. Do these associations persist after adjustment for Medicaid expansion, physician density, cardiometabolic disease burden, and, in sensitivity analysis, Census region?

## 2. High-Level Workflow

Four R scripts were created:

| Script | Purpose |
|---|---|
| `scripts/05_build_master_analysis_table_poc.R` | Builds the master state-quarter table from the all-products SGLT2 file and structural covariate files. |
| `scripts/06_model_sglt2_prescribing_poc.R` | Runs descriptive analyses, plots, staged negative binomial models, continuous-rurality sensitivity, and complete-year sensitivity. |
| `scripts/07_sensitivity_outcomes_full_model_poc.R` | Adds single-agent and empagliflozin/dapagliflozin outcomes to the master table and repeats only the final fully adjusted model for those outcomes. |
| `scripts/08_region_adjusted_sensitivity_poc.R` | Adds Census region/division and runs only the region-adjusted fully adjusted model for all-products and sensitivity outcomes. |

The original raw/proof-of-concept input CSV files in `for_analysis/` were not overwritten. New master tables and model outputs were written as separate files.

## 3. Input Files

### Master Table Inputs

The initial master table was built from:

| Relative path | Role |
|---|---|
| `for_analysis/sglt2_state_quarter_rates_all_products_50dc_excluding_2020.csv` | Base analytic sample and all-products SGLT2 prescribing outcome file. |
| `for_analysis/medicaid_expansion_status.csv` | State-level Medicaid expansion adoption and timing file. |
| `for_analysis/ahrf_physician_density_2023_50dc.csv` | 2023 AHRF physician density covariates. |
| `for_analysis/mmd_disease_burden_2023_50dc.csv` | 2023 CMS Mapping Medicare Disparities disease burden covariates. |
| `for_analysis/svi_state_aggregates_by_source_year.csv` | State-level Social Vulnerability Index aggregates; 2022 rows were used. |
| `for_analysis/Ruralurbancontinuumcodes2023.csv` | County-level 2023 Rural-Urban Continuum Codes in long format. |

### Product Sensitivity Outcome Inputs

Additional product-specific outcome files were later joined:

| Relative path | Role |
|---|---|
| `for_analysis/sglt2_state_quarter_rates_single_agent_50dc_excluding_2020.csv` | State-quarter single-agent SGLT2 prescribing outcomes. |
| `for_analysis/sglt2_state_quarter_rates_empa_dapa_50dc_excluding_2020.csv` | State-quarter empagliflozin/dapagliflozin prescribing outcomes. |

### Modelling Inputs

| Relative path | Role |
|---|---|
| `for_analysis/master_state_quarter_sglt2_covariates_poc.csv` | Initial master table used for the primary staged modelling workflow. |
| `for_analysis/master_state_quarter_sglt2_covariates_with_sensitivity_outcomes_poc.csv` | Master table with all-products, single-agent, and empagliflozin/dapagliflozin outcomes. |
| `for_analysis/master_state_quarter_sglt2_covariates_with_region_poc.csv` | Master table with sensitivity outcomes plus Census region/division. |

## 4. Master Table Construction

### Unit of Analysis

Each row is one state-quarter. The base all-products SGLT2 file defined the analytic sample.

Expected key columns:

- `state`
- `year`
- `quarter`

The master table retained SGLT2 outcome, denominator, and rate variables already present in the base SGLT2 file, then joined covariates.

### Analytic Sample Validation

The current final region-augmented master table has:

| Quantity | Value |
|---|---:|
| Rows | 1,938 |
| Columns | 47 |
| States/jurisdictions | 51 |
| Jurisdictions included | 50 states plus DC |
| Years included | 2015-2019 and 2021-2025 |
| 2020 present | No |
| PR or XX present | No |
| Duplicate `state`-`year`-`quarter` rows | 0 |

The initial master table `for_analysis/master_state_quarter_sglt2_covariates_poc.csv` had 1,938 rows and 39 columns. The row count did not change when sensitivity outcomes or Census region/division were added.

### Quarter Dates

The master-building script created:

- `quarter_start_date`
- `quarter_end_date`

Quarter date definitions:

| Quarter | Start date | End date |
|---|---|---|
| Q1 | January 1 | March 31 |
| Q2 | April 1 | June 30 |
| Q3 | July 1 | September 30 |
| Q4 | October 1 | December 31 |

These dates were used to evaluate time-varying Medicaid expansion status.

## 5. Outcome Handling and Zero-Prescribing Rule

### All-Products Outcome

In the base master workflow, missing SGLT2 outcome/count/reimbursement values were interpreted as zero only if the state-quarter had valid Medicaid enrolment. This rule was applied to:

- `sglt2_prescriptions`
- `sglt2_units`
- `sglt2_medicaid_reimbursed`
- `sglt2_total_reimbursed`
- `n_rows`
- `n_ndcs`

The following rate variables were recalculated after zero-fill:

- `sglt2_prescriptions_per_10000`
- `sglt2_units_per_10000`
- `sglt2_medicaid_reimbursed_per_10000`
- `sglt2_reimbursement_per_prescription`

`sglt2_reimbursement_per_prescription` was set to `NA` when `sglt2_prescriptions == 0`.

Medicaid enrolment was not replaced with zero. Covariates were not replaced with zero.

### Product Sensitivity Outcomes

The sensitivity-outcome workflow created:

- `sglt2_prescriptions_all_products`
- `sglt2_units_all_products`
- `sglt2_prescriptions_all_products_per_10000`
- `sglt2_prescriptions_single_agent`
- `sglt2_units_single_agent`
- `sglt2_prescriptions_single_agent_per_10000`
- `sglt2_prescriptions_empa_dapa`
- `sglt2_units_empa_dapa`
- `sglt2_prescriptions_empa_dapa_per_10000`

After joining the single-agent and empagliflozin/dapagliflozin files by `state`, `year`, and `quarter`, missing sensitivity prescribing counts and units were set to zero only where valid Medicaid enrolment existed. Sensitivity prescribing rates per 10,000 were recalculated using the master-table Medicaid enrolment denominator. Missing Medicaid enrolment and missing covariates were not zero-filled.

## 6. Covariate Definitions and Assumptions

### Medicaid Expansion

Medicaid expansion was the only time-varying covariate in the proof-of-concept master table.

Variables created:

- `medicaid_expansion_ever_adopted`
- `medicaid_expansion_effective_date`
- `medicaid_expansion_active`
- `medicaid_expansion_active_any_part_quarter`

Main model variable:

- `medicaid_expansion_active`

Coding logic:

- Non-adopting states were coded `0` for active expansion variables in all quarters.
- For adopting states with a valid effective date, `medicaid_expansion_active = 1` when `quarter_start_date` was on or after the effective date.
- `medicaid_expansion_active_any_part_quarter = 1` when `quarter_end_date` was on or after the effective date.

`medicaid_expansion_effective_date` was missing for 380 rows (19.6%), corresponding to states without an effective expansion date in the input file. The active expansion indicators had no missingness in the final master table.

### Physician Density

Source file:

- `for_analysis/ahrf_physician_density_2023_50dc.csv`

Physician density was treated as 2023 time-invariant structural access. The main fully adjusted model used:

- `cvd_physicians_per_100k_2023`

The master table also retained:

- `population_2023_ahrf`
- `number_physicians_2023`
- `physicians_per_100k_2023`
- `number_primary_care_physicians_2023`
- `primary_care_physicians_per_100k_2023`
- `number_cvd_physicians_2023`
- `cvd_physicians_per_100k_2023`

Future sensitivity options were noted in the modelling script for primary care physicians per 100,000 and total physicians per 100,000.

### Disease Burden

Source file:

- `for_analysis/mmd_disease_burden_2023_50dc.csv`

CMS Mapping Medicare Disparities disease burden was treated as 2023 time-invariant state-level disease burden.

Variables used:

- `medicare_ffs_hf_ihd_prevalence_2023`
- `medicare_ffs_diabetes_prevalence_2023`
- `medicare_ffs_ckd_prevalence_2023`

Important assumption: these are Medicare fee-for-service based state-level proxies, not Medicaid-specific prevalence estimates.

Important naming caveat: `medicare_ffs_hf_ihd_prevalence_2023` is not pure heart failure prevalence. It is the CMS Mapping Medicare Disparities Heart Failure and Non-Ischemic Heart Disease prevalence measure.

### Social Vulnerability

Source file:

- `for_analysis/svi_state_aggregates_by_source_year.csv`

Only `svi_source_year == 2022` was used.

Variables retained:

- `svi_2022`
- `svi_counties_used_2022`
- `svi_population_weight_2022`
- `svi_source_year`

Interpretation: `svi_2022` is a population-weighted average of county-level overall SVI scores within each state. Higher values indicate greater social vulnerability.

In models, SVI was scaled as:

`svi_2022_per_0_1 = svi_2022 / 0.1`

Thus the SVI IRR is interpreted per 0.1 higher state-level SVI.

### RUCC Rurality

Source file:

- `for_analysis/Ruralurbancontinuumcodes2023.csv`

The RUCC file was county-level and long format, with rows for:

- `Population_2020`
- `RUCC_2023`
- `Description`

The script reshaped the file to one row per county, then calculated state-level rurality.

Definitions:

- Metro counties: RUCC 1-3
- Nonmetro counties: RUCC 4-9

Main rurality measure:

`rucc_nonmetro_population_share_2023 = rucc_nonmetro_population_2020 / rucc_population_2020_total`

Rurality quintiles:

`rurality_quintile = ntile(desc(rucc_nonmetro_population_share_2023), 5)`

Thus:

- Q1 = most rural, highest nonmetro population share
- Q5 = most urban, lowest nonmetro population share

The main modelling table includes:

- `rurality_quintile`
- `rurality_quintile_label`
- `rucc_nonmetro_population_share_2023`

The audit RUCC output also includes total population, nonmetro population, county counts, and nonmetro county share.

Rurality quintile validation:

| Quintile | Label | States | Nonmetro share range |
|---:|---|---:|---:|
| 1 | Q1 most rural | 11 | 0.382 to 0.687 |
| 2 | Q2 | 10 | 0.240 to 0.370 |
| 3 | Q3 | 10 | 0.159 to 0.223 |
| 4 | Q4 | 10 | 0.074 to 0.151 |
| 5 | Q5 most urban | 10 | 0.000 to 0.069 |

The direction was checked and is correct: Q1 has the highest nonmetro population share and Q5 has the lowest.

### Census Region and Division

Census region and division were added as state-level sensitivity covariates in `scripts/08_region_adjusted_sensitivity_poc.R`.

The lookup was encoded directly in the script using the standard U.S. Census Bureau four-region and nine-division classification:

| Region | Division | States |
|---|---|---|
| Northeast | New England | CT, ME, MA, NH, RI, VT |
| Northeast | Middle Atlantic | NJ, NY, PA |
| Midwest | East North Central | IL, IN, MI, OH, WI |
| Midwest | West North Central | IA, KS, MN, MO, NE, ND, SD |
| South | South Atlantic | DE, DC, FL, GA, MD, NC, SC, VA, WV |
| South | East South Central | AL, KY, MS, TN |
| South | West South Central | AR, LA, OK, TX |
| West | Mountain | AZ, CO, ID, MT, NV, NM, UT, WY |
| West | Pacific | AK, CA, HI, OR, WA |

Validation confirmed that all 51 states/DC matched to both `census_region` and `census_division`, with no PR or XX rows.

## 7. Missingness Summary

In the current final region master table, only two variables had nonzero missingness:

| Variable | Missing rows | Percent missing |
|---|---:|---:|
| `medicaid_expansion_effective_date` | 380 | 19.6% |
| `sglt2_reimbursement_per_prescription` | 5 | 0.258% |

Key modelling covariates had no missingness in the rows analysed.

The saved missingness output is:

- `for_analysis/master_poc_missingness_report.csv`

## 8. Modelling Dataset

The main modelling input was written to:

- `for_analysis/model_outputs/model_input_cleaned_all_products.csv`

Cleaning steps before modelling:

- Restricted to `year != 2020`.
- Excluded PR and XX.
- Restricted to `state %in% c(state.abb, "DC")`.
- Required positive, non-missing Medicaid enrolment.
- Reapplied the zero-prescribing correction for state-quarters with valid enrolment.
- Did not zero-fill missing enrolment or missing covariates.
- Created `year_quarter`, `time_index`, `calendar_quarter`, and `year_factor`.
- Set rurality quintile as a factor with levels `c(5, 4, 3, 2, 1)`, making Q5 most urban the reference group.
- Created `svi_2022_per_0_1`.
- Created `log_medicaid_enrolment`.
- Created `rucc_nonmetro_population_share_per_10pct` when `rucc_nonmetro_population_share_2023` existed.

The modelling denominator was selected by checking, in order:

1. `medicaid_enrolment`
2. `medicaid_enrolment_quarter_avg`
3. `medicaid_enrolment_avg`

In the current final region master table, `medicaid_enrolment` and `medicaid_enrolment_quarter_avg` are both present, fully non-missing, and identical across all 1,938 rows (maximum absolute difference = 0). The modelling script therefore used `medicaid_enrolment` as `medicaid_enrolment_model`.

## 9. Descriptive Analyses

Descriptive tables created:

| Relative path | Contents |
|---|---|
| `for_analysis/model_outputs/descriptive_national_quarterly_trend.csv` | National quarterly prescriptions, enrolment, rates per 10,000, and number of states. |
| `for_analysis/model_outputs/descriptive_state_summary.csv` | State-level mean/median/min/max rates, total prescriptions, enrolment, rurality, and SVI. |
| `for_analysis/model_outputs/descriptive_rurality_quarterly_trend.csv` | Quarterly rates by rurality quintile. |
| `for_analysis/model_outputs/descriptive_svi_quarterly_trend.csv` | Quarterly rates by SVI quintile. |
| `for_analysis/model_outputs/rurality_quintile_state_membership.csv` | Rurality membership with nonmetro share, SVI, and mean prescribing rate. |

Key descriptive findings:

| Quantity | Value |
|---|---:|
| Number of analysed quarters | 38 |
| First analysed quarter | 2015 Q1 |
| Last analysed quarter | 2025 Q2 |
| National prescribing rate in 2015 Q1 | 5.97 prescriptions per 10,000 Medicaid enrollees |
| National prescribing rate in 2025 Q2 | 138 prescriptions per 10,000 Medicaid enrollees |
| Total all-products SGLT2 prescriptions across analysed rows | 19,923,664 |
| Mean state-level mean prescribing rate | 58.1 prescriptions per 10,000 |
| Lowest mean state prescribing rate | WY, 19.0 per 10,000 |
| Highest mean state prescribing rate | KY, 112 per 10,000 |
| Mean state SVI | 0.515 |
| State SVI range | 0.170 to 0.815 |

Descriptive plots created:

| Relative path | Plot |
|---|---|
| `for_analysis/model_outputs/plots/fig1_national_quarterly_sglt2_rate.png` | National quarterly SGLT2 prescribing rate over time. |
| `for_analysis/model_outputs/plots/fig2_rurality_quintile_quarterly_sglt2_rate.png` | Quarterly prescribing rate by rurality quintile. |
| `for_analysis/model_outputs/plots/fig3_svi_quintile_quarterly_sglt2_rate.png` | Quarterly prescribing rate by SVI quintile. |
| `for_analysis/model_outputs/plots/fig4_boxplot_rates_by_rurality_quintile.png` | State-quarter prescribing rates by rurality quintile. |
| `for_analysis/model_outputs/plots/fig5_scatter_svi_vs_state_mean_rate.png` | SVI versus mean state prescribing rate. |
| `for_analysis/model_outputs/plots/fig6_state_quarter_heatmap_sglt2_rate.png` | Heatmap of state-quarter prescribing rates by state over time. |

## 10. Statistical Modelling Methods

### Primary Modelling Approach

The primary regression outcome was a count:

`sglt2_prescriptions`

The model used the natural log of Medicaid enrolment as an offset:

`offset(log_medicaid_enrolment)`

This means the models estimate prescribing rate ratios rather than modelling the pre-calculated prescribing rate as the dependent variable.

Negative binomial regression was used with `MASS::glm.nb()` because the outcome is a count and the Poisson comparison showed strong overdispersion. The Poisson overdispersion check gave:

| Quantity | Value |
|---|---:|
| Poisson model observations | 1,938 |
| Residual deviance | 3,942,801 |
| Residual df | 1,921 |
| Dispersion ratio | 2,052 |

The saved overdispersion output is:

- `for_analysis/model_outputs/poisson_overdispersion_check.csv`

### General Model Form

For state `s` in quarter `t`, the model can be expressed as:

```text
Y_st ~ Negative Binomial(mu_st, theta)

log(mu_st) =
  log(Medicaid enrolment_st) +
  beta0 +
  beta1 * rurality +
  beta2 * SVI +
  beta3 * Medicaid expansion active +
  beta4 * CVD physician density +
  beta5 * disease burden +
  year fixed effects +
  quarter fixed effects
```

Incidence rate ratios (IRRs) were calculated as `exp(beta)`.

Wald 95% confidence intervals were calculated as:

```text
exp(estimate +/- 1.96 * standard error)
```

State-clustered robust standard errors were attempted for every model using:

- `sandwich::vcovCL(model, cluster = data$state)`
- `lmtest::coeftest()`

The key results reported below use state-clustered robust standard errors where available. Robust SEs succeeded for the primary staged models, the product sensitivity models, and the region-adjusted sensitivity models.

### Model Sequence

The staged all-products models were:

| Model | Formula summary |
|---|---|
| Model 0 | `sglt2_prescriptions ~ time_index + offset(log_medicaid_enrolment)` |
| Model 1 | Rurality + year fixed effects + quarter fixed effects + offset |
| Model 2 | SVI + year fixed effects + quarter fixed effects + offset |
| Model 3 | Rurality + SVI + year fixed effects + quarter fixed effects + offset |
| Model 4 | Model 3 + Medicaid expansion active |
| Model 5 | Model 4 + CVD physicians per 100,000 |
| Model 6 | Model 5 + HF/IHD prevalence + diabetes prevalence + CKD prevalence |
| Model S1 | Model 6 structure with continuous nonmetro population share instead of rurality quintiles |
| Model S2 | Model 6 restricted to complete years through 2024 |

The initial Model 7 region-adjusted model was skipped in `scripts/06_model_sglt2_prescribing_poc.R` because `census_region` was not yet present in the master table. Region adjustment was later implemented as a separate sensitivity workflow in `scripts/08_region_adjusted_sensitivity_poc.R` to avoid disrupting existing outputs.

### Full Model Formula

The main fully adjusted proof-of-concept model was:

```r
sglt2_prescriptions ~
  rurality_quintile +
  svi_2022_per_0_1 +
  medicaid_expansion_active +
  cvd_physicians_per_100k_2023 +
  medicare_ffs_hf_ihd_prevalence_2023 +
  medicare_ffs_diabetes_prevalence_2023 +
  medicare_ffs_ckd_prevalence_2023 +
  factor(year) +
  factor(quarter) +
  offset(log_medicaid_enrolment)
```

For rurality, Q5 most urban was the reference group.

## 11. Main All-Products Model Results

Model diagnostics:

| Model | Observations | AIC | Theta | Converged | Robust SE |
|---|---:|---:|---:|---|---|
| Model 0 | 1,938 | 34,963 | 2.50 | Yes | Succeeded |
| Model 1 | 1,938 | 34,862 | 2.66 | Yes | Succeeded |
| Model 2 | 1,938 | 34,891 | 2.61 | Yes | Succeeded |
| Model 3 | 1,938 | 34,825 | 2.70 | Yes | Succeeded |
| Model 4 | 1,938 | 34,588 | 3.03 | Yes | Succeeded |
| Model 5 | 1,938 | 34,581 | 3.04 | Yes | Succeeded |
| Model 6 | 1,938 | 34,267 | 3.55 | Yes | Succeeded |
| Model S1 | 1,938 | 34,301 | 3.48 | Yes | Succeeded |
| Model S2 | 1,836 | 32,262 | 3.42 | Yes | Succeeded |

Saved diagnostics:

- `for_analysis/model_outputs/model_diagnostics_summary.csv`

### Primary Fully Adjusted Model 6

State-cluster robust IRRs from Model 6:

| Exposure | Comparison or unit | IRR | 95% CI | p-value |
|---|---|---:|---:|---:|
| Rurality | Q1 most rural vs Q5 most urban | 0.788 | 0.462-1.345 | 0.382 |
| Rurality | Q2 vs Q5 most urban | 0.922 | 0.603-1.410 | 0.708 |
| Rurality | Q3 vs Q5 most urban | 0.720 | 0.502-1.030 | 0.0746 |
| Rurality | Q4 vs Q5 most urban | 0.776 | 0.520-1.160 | 0.214 |
| SVI | Per 0.1 increase | 0.868 | 0.784-0.960 | 0.00613 |
| Medicaid expansion | Active vs not active | 1.711 | 1.366-2.143 | 0.00000299 |
| CVD physician density | Per 1 CVD physician per 100,000 | 0.992 | 0.956-1.028 | 0.647 |
| HF/IHD prevalence | Per one-unit increase in source variable scale | 1.037 | 0.956-1.126 | 0.384 |
| Diabetes prevalence | Per one-unit increase in source variable scale | 1.065 | 1.014-1.119 | 0.0124 |
| CKD prevalence | Per one-unit increase in source variable scale | 1.027 | 0.982-1.073 | 0.241 |

Interpretation:

- In the full all-products model, Q1 most rural states did not have statistically significant evidence of a different SGLT2 prescribing rate compared with Q5 most urban states.
- Higher SVI was associated with lower prescribing. Each 0.1 higher SVI was associated with an estimated 13.2% lower prescribing rate (IRR 0.868).
- Active Medicaid expansion was associated with higher prescribing. Expansion-active state-quarters had an estimated 71.1% higher prescribing rate than non-active state-quarters (IRR 1.711).
- CVD physician density was not statistically associated with prescribing in the full model.
- Medicare FFS diabetes prevalence was positively associated with prescribing in the full model; HF/IHD and CKD prevalence were not statistically significant in this proof-of-concept specification.

Primary model output files:

- `for_analysis/model_outputs/model_6_full_covariate_coefficients.csv`
- `for_analysis/model_outputs/model_6_full_covariate_cluster_robust_coefficients.csv`
- `for_analysis/model_outputs/model_6_full_covariate_summary.txt`
- `for_analysis/model_outputs/key_results_summary.csv`
- `for_analysis/model_outputs/plots/fig7_forest_plot_full_model_irrs.png`

## 12. Continuous Rurality Sensitivity

The workflow did include rurality as a continuous variable. This was Model S1:

`rucc_nonmetro_population_share_per_10pct = rucc_nonmetro_population_share_2023 / 0.10`

Model S1 replaced rurality quintile categories with the continuous nonmetro population share per 10 percentage-point increase.

Key state-cluster robust Model S1 results:

| Exposure | Unit | IRR | 95% CI | p-value |
|---|---|---:|---:|---:|
| Nonmetro population share | Per 10 percentage-point increase | 0.933 | 0.847-1.028 | 0.161 |
| SVI | Per 0.1 increase | 0.848 | 0.774-0.928 | 0.000365 |
| Medicaid expansion | Active vs not active | 1.608 | 1.250-2.069 | 0.000207 |
| CVD physician density | Per 1 CVD physician per 100,000 | 0.994 | 0.958-1.031 | 0.743 |

Interpretation:

- Continuous rurality was not statistically significant in this sensitivity model.
- SVI remained inversely associated with prescribing.
- Medicaid expansion remained positively associated with prescribing.

Output files:

- `for_analysis/model_outputs/model_s1_continuous_rurality_coefficients.csv`
- `for_analysis/model_outputs/model_s1_continuous_rurality_cluster_robust_coefficients.csv`
- `for_analysis/model_outputs/model_s1_continuous_rurality_summary.txt`

## 13. Complete-Year Sensitivity Through 2024

Model S2 repeated the full all-products Model 6 after restricting to `year <= 2024`, excluding partial 2025 data.

Key state-cluster robust Model S2 results:

| Exposure | Comparison or unit | IRR | 95% CI | p-value |
|---|---|---:|---:|---:|
| Rurality | Q1 most rural vs Q5 most urban | 0.775 | 0.444-1.354 | 0.368 |
| SVI | Per 0.1 increase | 0.866 | 0.780-0.962 | 0.00733 |
| Medicaid expansion | Active vs not active | 1.702 | 1.348-2.149 | 0.00000649 |
| CVD physician density | Per 1 CVD physician per 100,000 | 0.990 | 0.953-1.029 | 0.608 |

Interpretation:

- Excluding partial 2025 data did not materially change the SVI or Medicaid expansion findings.
- Q1 rurality remained not statistically significant.

Output files:

- `for_analysis/model_outputs/model_s2_complete_years_through_2024_coefficients.csv`
- `for_analysis/model_outputs/model_s2_complete_years_through_2024_cluster_robust_coefficients.csv`
- `for_analysis/model_outputs/model_s2_complete_years_through_2024_summary.txt`

## 14. Product-Specific Sensitivity Outcomes

The product-specific sensitivity workflow added two outcome families to the existing master table:

- Single-agent SGLT2 inhibitors
- Empagliflozin/dapagliflozin

The workflow deliberately did not rerun the full staged model sequence. It repeated only the final fully adjusted negative binomial model for:

1. All products
2. Single-agent SGLT2 inhibitors
3. Empagliflozin/dapagliflozin

All models used the same covariates and offset as Model 6.

State-cluster robust key results:

| Outcome | Exposure | Comparison or unit | IRR | 95% CI | p-value |
|---|---|---|---:|---:|---:|
| All products | Rurality | Q1 most rural vs Q5 most urban | 0.788 | 0.462-1.345 | 0.382 |
| All products | SVI | Per 0.1 increase | 0.868 | 0.784-0.960 | 0.00613 |
| All products | Medicaid expansion | Active vs not active | 1.711 | 1.366-2.143 | 0.00000299 |
| All products | CVD physician density | Per 1 CVD physician per 100,000 | 0.992 | 0.956-1.028 | 0.647 |
| Single-agent SGLT2 inhibitors | Rurality | Q1 most rural vs Q5 most urban | 0.808 | 0.475-1.374 | 0.432 |
| Single-agent SGLT2 inhibitors | SVI | Per 0.1 increase | 0.863 | 0.781-0.953 | 0.00381 |
| Single-agent SGLT2 inhibitors | Medicaid expansion | Active vs not active | 1.722 | 1.379-2.149 | 0.00000190 |
| Single-agent SGLT2 inhibitors | CVD physician density | Per 1 CVD physician per 100,000 | 0.993 | 0.958-1.029 | 0.703 |
| Empagliflozin/dapagliflozin | Rurality | Q1 most rural vs Q5 most urban | 0.728 | 0.376-1.411 | 0.345 |
| Empagliflozin/dapagliflozin | SVI | Per 0.1 increase | 0.845 | 0.758-0.942 | 0.00236 |
| Empagliflozin/dapagliflozin | Medicaid expansion | Active vs not active | 1.581 | 1.265-1.975 | 0.0000496 |
| Empagliflozin/dapagliflozin | CVD physician density | Per 1 CVD physician per 100,000 | 0.974 | 0.924-1.026 | 0.316 |

Interpretation:

- SVI remained inversely associated with prescribing across all three product outcome definitions.
- Medicaid expansion remained positively associated with prescribing across all three product outcome definitions.
- Q1 most rural versus Q5 most urban was not statistically significant in any of the product outcome models.
- CVD physician density was not statistically significant in any of the product outcome models.

Output files:

- `for_analysis/master_state_quarter_sglt2_covariates_with_sensitivity_outcomes_poc.csv`
- `for_analysis/model_outputs/sensitivity_full_model_all_products.csv`
- `for_analysis/model_outputs/sensitivity_full_model_single_agent.csv`
- `for_analysis/model_outputs/sensitivity_full_model_empa_dapa.csv`
- `for_analysis/model_outputs/sensitivity_outcome_comparison_key_results.csv`
- `for_analysis/model_outputs/plots/sensitivity_outcome_comparison_forest_plot.png`

## 15. Region-Adjusted Sensitivity Analysis

Census region was added as a geographic sensitivity adjustment to assess whether broad regional differences in policy environment, prescribing norms, or access patterns changed the rurality, SVI, or Medicaid expansion findings.

This was implemented without rerunning all staged models and without overwriting existing main model outputs.

The region-adjusted all-products model added `census_region` to the Model 6 formula:

```r
outcome ~
  rurality_quintile +
  svi_2022_per_0_1 +
  medicaid_expansion_active +
  census_region +
  cvd_physicians_per_100k_2023 +
  medicare_ffs_hf_ihd_prevalence_2023 +
  medicare_ffs_diabetes_prevalence_2023 +
  medicare_ffs_ckd_prevalence_2023 +
  factor(year) +
  factor(quarter) +
  offset(log_medicaid_enrolment)
```

Northeast was the Census region reference group.

Region-adjusted all-products key results:

| Exposure | Comparison or unit | IRR | 95% CI | p-value |
|---|---|---:|---:|---:|
| Rurality | Q1 most rural vs Q5 most urban | 1.017 | 0.634-1.632 | 0.944 |
| Rurality | Q2 vs Q5 | 1.080 | 0.731-1.600 | 0.696 |
| Rurality | Q3 vs Q5 | 0.839 | 0.610-1.150 | 0.279 |
| Rurality | Q4 vs Q5 | 0.893 | 0.640-1.250 | 0.504 |
| SVI | Per 0.1 increase | 0.898 | 0.806-1.000 | 0.0494 |
| Medicaid expansion | Active vs not active | 1.530 | 1.182-1.979 | 0.00122 |
| CVD physician density | Per 1 CVD physician per 100,000 | 1.005 | 0.967-1.044 | 0.815 |
| Census region | Midwest vs Northeast | 0.863 | 0.643-1.160 | 0.326 |
| Census region | South vs Northeast | 0.626 | 0.459-0.853 | 0.00303 |
| Census region | West vs Northeast | 0.940 | 0.588-1.500 | 0.796 |

Original Model 6 versus region-adjusted all-products model:

| Exposure | Original full model IRR | Original 95% CI | Region-adjusted IRR | Region-adjusted 95% CI | Interpretation change |
|---|---:|---:|---:|---:|---|
| Q1 most rural vs Q5 most urban | 0.788 | 0.462-1.345 | 1.017 | 0.634-1.632 | Region adjustment moved the point estimate upward. |
| SVI per 0.1 increase | 0.868 | 0.784-0.960 | 0.898 | 0.806-1.000 | Little material change in point estimate; statistical evidence became borderline. |
| Medicaid expansion active | 1.711 | 1.366-2.143 | 1.530 | 1.182-1.979 | Region adjustment moved the point estimate downward but association remained positive and statistically significant. |
| CVD physicians per 100,000 | 0.992 | 0.956-1.028 | 1.005 | 0.967-1.044 | Little material change in point estimate. |

Output files:

- `for_analysis/master_state_quarter_sglt2_covariates_with_region_poc.csv`
- `for_analysis/model_outputs/region_adjusted_full_model_coefficients.csv`
- `for_analysis/model_outputs/region_adjusted_full_model_robust_coefficients.csv`
- `for_analysis/model_outputs/region_adjusted_key_results.csv`
- `for_analysis/model_outputs/region_adjusted_vs_original_key_results.csv`
- `for_analysis/model_outputs/plots/region_adjusted_full_model_forest_plot.png`

## 16. Region-Adjusted Product Sensitivity Outcomes

The region-adjusted workflow also repeated the same fully adjusted region model for the single-agent and empagliflozin/dapagliflozin outcomes because those columns existed in the updated master table.

Key SVI and Medicaid expansion results:

| Outcome | Exposure | Comparison or unit | IRR | 95% CI | p-value |
|---|---|---|---:|---:|---:|
| All products | SVI | Per 0.1 increase | 0.898 | 0.806-1.000 | 0.0494 |
| All products | Medicaid expansion | Active vs not active | 1.530 | 1.182-1.979 | 0.00122 |
| Single-agent SGLT2 inhibitors | SVI | Per 0.1 increase | 0.891 | 0.801-0.990 | 0.0325 |
| Single-agent SGLT2 inhibitors | Medicaid expansion | Active vs not active | 1.540 | 1.190-2.000 | 0.00108 |
| Empagliflozin/dapagliflozin | SVI | Per 0.1 increase | 0.880 | 0.786-0.985 | 0.0259 |
| Empagliflozin/dapagliflozin | Medicaid expansion | Active vs not active | 1.380 | 1.080-1.760 | 0.0107 |

Interpretation:

- Yes, the single-agent and empagliflozin/dapagliflozin region-adjusted sensitivity outcomes were checked for both SVI and Medicaid expansion.
- SVI remained inversely associated with prescribing for both sensitivity outcomes after adding Census region.
- Medicaid expansion remained positively associated with prescribing for both sensitivity outcomes after adding Census region.

Output files:

- `for_analysis/model_outputs/region_adjusted_single_agent_coefficients.csv`
- `for_analysis/model_outputs/region_adjusted_empa_dapa_coefficients.csv`
- `for_analysis/model_outputs/region_adjusted_sensitivity_outcome_comparison.csv`

## 17. Complete Output Inventory

### Master and Audit Outputs

| Relative path | Description |
|---|---|
| `for_analysis/master_state_quarter_sglt2_covariates_poc.csv` | Initial all-products master state-quarter table with covariates. |
| `for_analysis/master_state_quarter_sglt2_covariates_with_sensitivity_outcomes_poc.csv` | Master table with all-products, single-agent, and empagliflozin/dapagliflozin outcomes. |
| `for_analysis/master_state_quarter_sglt2_covariates_with_region_poc.csv` | Master table with sensitivity outcomes plus Census region/division. |
| `for_analysis/rucc_state_rurality_2023.csv` | State-level RUCC rurality audit summary. |
| `for_analysis/rurality_quintile_membership_2023.csv` | RUCC rurality quintile membership file. |
| `for_analysis/master_poc_missingness_report.csv` | Master table covariate missingness report. |

### Logs and Reports

| Relative path | Description |
|---|---|
| `docs/2026-05-03_master_table_poc_log.md` | Master table merge audit log. |
| `docs/2026-05-03_modelling_poc_log.md` | Modelling audit log with sensitivity and region-adjusted appendices. |
| `docs/full-analysis-report.md` | This full analysis report. |

### Descriptive Outputs

| Relative path | Description |
|---|---|
| `for_analysis/model_outputs/model_input_cleaned_all_products.csv` | Cleaned all-products modelling input. |
| `for_analysis/model_outputs/descriptive_national_quarterly_trend.csv` | National quarterly trend table. |
| `for_analysis/model_outputs/descriptive_state_summary.csv` | State-level descriptive summary. |
| `for_analysis/model_outputs/descriptive_rurality_quarterly_trend.csv` | Rurality-quarter descriptive trend table. |
| `for_analysis/model_outputs/descriptive_svi_quarterly_trend.csv` | SVI-quintile quarterly trend table. |
| `for_analysis/model_outputs/rurality_quintile_state_membership.csv` | Rurality quintile state membership table. |

### Primary and Staged Model Outputs

| Relative path | Description |
|---|---|
| `for_analysis/model_outputs/model_0_time_trend_coefficients.csv` | Ordinary coefficient table for Model 0. |
| `for_analysis/model_outputs/model_0_time_trend_cluster_robust_coefficients.csv` | State-cluster robust coefficient table for Model 0. |
| `for_analysis/model_outputs/model_0_time_trend_summary.txt` | Text model summary for Model 0. |
| `for_analysis/model_outputs/model_1_rurality_time_coefficients.csv` | Ordinary coefficient table for Model 1. |
| `for_analysis/model_outputs/model_1_rurality_time_cluster_robust_coefficients.csv` | State-cluster robust coefficient table for Model 1. |
| `for_analysis/model_outputs/model_1_rurality_time_summary.txt` | Text model summary for Model 1. |
| `for_analysis/model_outputs/model_2_svi_time_coefficients.csv` | Ordinary coefficient table for Model 2. |
| `for_analysis/model_outputs/model_2_svi_time_cluster_robust_coefficients.csv` | State-cluster robust coefficient table for Model 2. |
| `for_analysis/model_outputs/model_2_svi_time_summary.txt` | Text model summary for Model 2. |
| `for_analysis/model_outputs/model_3_rurality_svi_time_coefficients.csv` | Ordinary coefficient table for Model 3. |
| `for_analysis/model_outputs/model_3_rurality_svi_time_cluster_robust_coefficients.csv` | State-cluster robust coefficient table for Model 3. |
| `for_analysis/model_outputs/model_3_rurality_svi_time_summary.txt` | Text model summary for Model 3. |
| `for_analysis/model_outputs/model_4_add_medicaid_expansion_coefficients.csv` | Ordinary coefficient table for Model 4. |
| `for_analysis/model_outputs/model_4_add_medicaid_expansion_cluster_robust_coefficients.csv` | State-cluster robust coefficient table for Model 4. |
| `for_analysis/model_outputs/model_4_add_medicaid_expansion_summary.txt` | Text model summary for Model 4. |
| `for_analysis/model_outputs/model_5_add_cvd_physician_density_coefficients.csv` | Ordinary coefficient table for Model 5. |
| `for_analysis/model_outputs/model_5_add_cvd_physician_density_cluster_robust_coefficients.csv` | State-cluster robust coefficient table for Model 5. |
| `for_analysis/model_outputs/model_5_add_cvd_physician_density_summary.txt` | Text model summary for Model 5. |
| `for_analysis/model_outputs/model_6_full_covariate_coefficients.csv` | Ordinary coefficient table for Model 6. |
| `for_analysis/model_outputs/model_6_full_covariate_cluster_robust_coefficients.csv` | State-cluster robust coefficient table for Model 6. |
| `for_analysis/model_outputs/model_6_full_covariate_summary.txt` | Text model summary for Model 6. |
| `for_analysis/model_outputs/key_results_summary.csv` | Key extracted staged model results. |
| `for_analysis/model_outputs/model_diagnostics_summary.csv` | Model diagnostics table. |
| `for_analysis/model_outputs/poisson_overdispersion_check.csv` | Poisson overdispersion check. |

### Sensitivity Model Outputs

| Relative path | Description |
|---|---|
| `for_analysis/model_outputs/model_s1_continuous_rurality_coefficients.csv` | Ordinary coefficient table for continuous rurality sensitivity. |
| `for_analysis/model_outputs/model_s1_continuous_rurality_cluster_robust_coefficients.csv` | State-cluster robust coefficient table for continuous rurality sensitivity. |
| `for_analysis/model_outputs/model_s1_continuous_rurality_summary.txt` | Text model summary for continuous rurality sensitivity. |
| `for_analysis/model_outputs/model_s2_complete_years_through_2024_coefficients.csv` | Ordinary coefficient table for complete-year sensitivity. |
| `for_analysis/model_outputs/model_s2_complete_years_through_2024_cluster_robust_coefficients.csv` | State-cluster robust coefficient table for complete-year sensitivity. |
| `for_analysis/model_outputs/model_s2_complete_years_through_2024_summary.txt` | Text model summary for complete-year sensitivity. |
| `for_analysis/model_outputs/sensitivity_full_model_all_products.csv` | Fully adjusted all-products model from product sensitivity workflow. |
| `for_analysis/model_outputs/sensitivity_full_model_single_agent.csv` | Fully adjusted single-agent model. |
| `for_analysis/model_outputs/sensitivity_full_model_empa_dapa.csv` | Fully adjusted empagliflozin/dapagliflozin model. |
| `for_analysis/model_outputs/sensitivity_outcome_comparison_key_results.csv` | Key result comparison across product outcomes. |

### Region-Adjusted Outputs

| Relative path | Description |
|---|---|
| `for_analysis/model_outputs/region_adjusted_full_model_coefficients.csv` | Ordinary coefficient table for region-adjusted all-products model. |
| `for_analysis/model_outputs/region_adjusted_full_model_robust_coefficients.csv` | State-cluster robust coefficient table for region-adjusted all-products model. |
| `for_analysis/model_outputs/region_adjusted_key_results.csv` | Key region-adjusted all-products results. |
| `for_analysis/model_outputs/region_adjusted_vs_original_key_results.csv` | Comparison of original Model 6 and region-adjusted model. |
| `for_analysis/model_outputs/region_adjusted_single_agent_coefficients.csv` | Region-adjusted single-agent model coefficients. |
| `for_analysis/model_outputs/region_adjusted_empa_dapa_coefficients.csv` | Region-adjusted empagliflozin/dapagliflozin model coefficients. |
| `for_analysis/model_outputs/region_adjusted_sensitivity_outcome_comparison.csv` | Region-adjusted comparison across all-products and sensitivity outcomes. |

### Plot Outputs

| Relative path | Description |
|---|---|
| `for_analysis/model_outputs/plots/fig1_national_quarterly_sglt2_rate.png` | National quarterly prescribing trend. |
| `for_analysis/model_outputs/plots/fig2_rurality_quintile_quarterly_sglt2_rate.png` | Rurality-quintile quarterly trends. |
| `for_analysis/model_outputs/plots/fig3_svi_quintile_quarterly_sglt2_rate.png` | SVI-quintile quarterly trends. |
| `for_analysis/model_outputs/plots/fig4_boxplot_rates_by_rurality_quintile.png` | Boxplot by rurality quintile. |
| `for_analysis/model_outputs/plots/fig5_scatter_svi_vs_state_mean_rate.png` | SVI versus state mean rate scatterplot. |
| `for_analysis/model_outputs/plots/fig6_state_quarter_heatmap_sglt2_rate.png` | State-quarter heatmap. |
| `for_analysis/model_outputs/plots/fig7_forest_plot_full_model_irrs.png` | Full Model 6 forest plot. |
| `for_analysis/model_outputs/plots/sensitivity_outcome_comparison_forest_plot.png` | Product sensitivity forest plot. |
| `for_analysis/model_outputs/plots/region_adjusted_full_model_forest_plot.png` | Region-adjusted all-products forest plot. |

## 18. R Packages Used

Across scripts, the workflow used:

- `tidyverse`
- `janitor`
- `lubridate`
- `here`
- `readr`
- `MASS`
- `broom`
- `sandwich`
- `lmtest`
- `ggplot2`
- `scales`
- `forcats`

The modelling workflow required `sandwich` and `lmtest` for state-clustered robust standard errors.

## 19. Traceability and Reproducibility Notes

Key safeguards implemented:

- Input CSV files were not overwritten.
- New derived master tables were written with explicit filenames.
- Joins used explicit keys:
  - `state`, `year`, `quarter` for outcome joins.
  - `state` for state-level structural covariates.
  - `state` plus quarter dates for time-varying Medicaid expansion indicators.
- Column names were cleaned with `janitor::clean_names()`.
- Expected columns were checked.
- Scripts were designed to stop with clear errors when required columns were missing.
- Missing prescribing outcomes were only converted to zero when valid Medicaid enrolment existed.
- Missing enrolment and missing covariates were not converted to zero.
- Source/provenance text columns were excluded from modelling master tables.
- Audit information was stored in logs and separate outputs rather than embedded as long text fields in the modelling table.

## 20. Key Assumptions

The following assumptions should be reviewed before final manuscript modelling:

- Medicaid expansion is the only time-varying covariate in this proof-of-concept master table.
- Missing SGLT2 prescribing outcomes/counts/reimbursements are interpreted as zero only when valid Medicaid enrolment exists for that state-quarter.
- AHRF physician density is treated as 2023 time-invariant structural access.
- CMS MMD disease burden is treated as 2023 time-invariant disease burden.
- SVI is treated as 2022 time-invariant social vulnerability.
- RUCC is treated as 2023 time-invariant rurality.
- RUCC state-level rurality is based on the proportion of the 2020 state population living in nonmetro counties, where nonmetro is defined as RUCC 4-9.
- Disease burden is Medicare FFS-based and used as a state-level proxy, not Medicaid-specific prevalence.
- HF/IHD is not pure heart failure prevalence. It is CMS MMD Heart Failure and Non-Ischemic Heart Disease prevalence.
- Census region/division is treated as static geography.
- Models are ecological state-quarter analyses and should not be interpreted as patient-level associations.
- The proof-of-concept models estimate associations, not causal effects.

## 21. Current Evidence Summary

Within this proof-of-concept workflow:

- Medicaid SGLT2 prescribing rose substantially over time, from 5.97 prescriptions per 10,000 Medicaid enrollees in 2015 Q1 to 138 prescriptions per 10,000 in 2025 Q2.
- There was no statistically significant evidence that the most rural quintile differed from the most urban quintile in the fully adjusted all-products model.
- Higher state-level SVI was consistently associated with lower SGLT2 prescribing in the fully adjusted model and in product-specific sensitivity models.
- Medicaid expansion active status was consistently associated with higher prescribing.
- CVD physician density did not explain the SVI association and was not statistically significant in the full models.
- Region adjustment attenuated the SVI estimate modestly and moved the Q1 rurality estimate upward, but SVI and Medicaid expansion remained statistically significant in the region-adjusted all-products model.
- Region-adjusted single-agent and empagliflozin/dapagliflozin sensitivity outcomes continued to show inverse SVI associations and positive Medicaid expansion associations.

## 22. Limitations to Address Before JAHA Submission

This proof-of-concept is close to a reproducible analysis pipeline, but several issues should be addressed before submission:

- Confirm the final analytic period, especially whether partial 2025 data should be included in primary analyses or restricted to sensitivity analyses.
- Confirm the Medicaid enrolment denominator definition and document its source, transformation, and whether it is an average monthly or quarterly denominator.
- Confirm the SDUD drug classification rules, NDC lists, and product family definitions for all-products, single-agent, and empagliflozin/dapagliflozin outcomes.
- Verify source provenance and versioning for all external covariate files.
- Decide whether Census region belongs in the primary model or should remain a sensitivity analysis.
- Consider whether state fixed effects, random effects, generalized estimating equations, or alternative longitudinal correlation structures better match the final estimand. A state fixed-effects model would not estimate effects for time-invariant state covariates such as rurality, SVI, or 2023 physician density.
- Evaluate collinearity among rurality, SVI, region, physician density, and disease burden.
- Check influential states and outlying state-quarter rates.
- Consider whether overdispersion, zero counts, or excess heterogeneity require additional sensitivity analyses.
- Pre-specify the main exposure contrast and sensitivity model set.
- Avoid causal language unless the final design is strengthened to support causal inference.
- Use a reporting checklist appropriate for observational studies, such as STROBE, when converting this report into a manuscript methods/results section.

## 23. Manuscript Methods Drafting Notes

A concise JAHA-facing methods description can be built from the following elements:

- The unit of analysis was the state-quarter.
- The base analytic sample was defined by the all-products Medicaid SDUD SGLT2 state-quarter prescribing file, excluding 2020 and excluding PR/XX.
- The final analytic sample contained 1,938 state-quarter observations from 51 jurisdictions across 2015-2019 and 2021-2025.
- Outcomes were counts of SGLT2 prescriptions, with Medicaid enrolment included as a log offset.
- Descriptive prescribing rates per 10,000 Medicaid enrollees were calculated for trends and plots but were not used as the primary regression outcome.
- Rurality was defined using RUCC 2023 county classifications, summarized as the share of the 2020 state population living in nonmetro counties, where nonmetro was RUCC 4-9.
- Rurality quintiles were constructed so Q1 was most rural and Q5 most urban; Q5 was the model reference group.
- Social vulnerability was the 2022 population-weighted state average SVI.
- Medicaid expansion was time-varying and was coded as active when the quarter start date was on or after the expansion effective date.
- Physician density and disease burden variables were treated as time-invariant structural state covariates.
- Negative binomial regression was used because prescribing counts were overdispersed relative to Poisson assumptions.
- Models estimated prescribing rate ratios with state-clustered robust standard errors.
- Sensitivity analyses examined continuous rurality, complete years through 2024, product-specific outcomes, and Census region adjustment.

## 24. Recommended Next Steps

Before final modelling and manuscript drafting:

1. Freeze the input data files and record checksums or data version metadata.
2. Decide whether the primary analysis includes 2025 Q1-Q2 or uses complete years through 2024.
3. Decide whether the primary outcome is all-products SGLT2 prescribing, single-agent prescribing, or another product definition.
4. Decide whether Census region is primary adjustment or sensitivity adjustment.
5. Confirm the final disease burden variable scales so model coefficients can be described accurately.
6. Add a formal table-one style covariate summary by rurality quintile and SVI quintile.
7. Add diagnostics for influential states and collinearity.
8. Review all source files and code with a reproducibility checklist before manuscript submission.

