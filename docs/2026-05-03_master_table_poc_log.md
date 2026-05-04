# Master State-Quarter SGLT2 Merge Log

Date: 2026-05-03

## Purpose

Create the master state-quarter analysis table for the Medicaid SDUD SGLT2 inhibitor uptake study. The base SGLT2 state-quarter table defines the analytic sample, and state-level covariates are joined onto that sample.

## Input Files Used

- `for_analysis/sglt2_state_quarter_rates_all_products_50dc_excluding_2020.csv`
- `for_analysis/medicaid_expansion_status.csv`
- `for_analysis/ahrf_physician_density_2023_50dc.csv`
- `for_analysis/mmd_disease_burden_2023_50dc.csv`
- `for_analysis/svi_state_aggregates_by_source_year.csv`
- `for_analysis/Ruralurbancontinuumcodes2023.csv`

## Join Keys Used

- Base table key: `state`, `year`, `quarter`.
- Medicaid expansion status joined by `state`, then evaluated against `quarter_start_date` and `quarter_end_date`.
- AHRF physician density joined by `state`.
- CMS Mapping Medicare Disparities disease burden joined by `state`.
- SVI 2022 state aggregate joined by `state`.
- RUCC 2023 rurality summary joined by `state`.
- Census region/division joined by `state`.

## Final Master Table

- Rows: 1938
- Columns: 40
- Output: `for_analysis/master_state_quarter_sglt2_covariates_poc.csv`

## Exclusions and Base Sample Checks

- 2020 is absent from the base and final master table.
- PR and XX are absent from the base and final master table.
- The analytic sample contains only the 50 states plus DC.
- RUCC source rows outside 50 states plus DC were excluded before state-level summarisation: AS, GU, MP, PR, VI.
- No duplicate `state`-`year`-`quarter` rows were detected.
- Non-2025 year-quarters have 51 jurisdictions.
- Current 2025 quarter(s) have 51 jurisdictions.

## Medicaid Expansion

`medicaid_expansion_ever_adopted` and `medicaid_expansion_effective_date` were read from the Medicaid expansion file. `medicaid_expansion_active` equals 1 when the quarter start date is on or after the effective date. `medicaid_expansion_active_any_part_quarter` equals 1 when the quarter end date is on or after the effective date. Non-adopting states are coded 0 for active expansion variables in all quarters.

## SGLT2 Outcome Zero-Fill and Rate Recalculation

After loading the SGLT2 state-quarter table, missing SGLT2 outcome/count/reimbursement values are replaced with 0 only for state-quarters with valid Medicaid enrolment, defined as non-missing `medicaid_enrolment_quarter_avg` greater than 0. Medicaid enrolment and covariates are not zero-filled. SGLT2 rates are then recalculated using `medicaid_enrolment_quarter_avg` as the denominator. `sglt2_reimbursement_per_prescription` is set to NA when `sglt2_prescriptions == 0`.

Before zero-fill:

```
# A tibble: 6 × 4
  variable                  n_missing_before n_missing_with_valid_enrolment
  <chr>                                <int>                          <int>
1 sglt2_prescriptions                      5                              5
2 sglt2_units                              5                              5
3 sglt2_medicaid_reimbursed                5                              5
4 sglt2_total_reimbursed                   5                              5
5 n_rows                                   0                              0
6 n_ndcs                                   0                              0
  n_missing_without_valid_enrolment
                              <int>
1                                 0
2                                 0
3                                 0
4                                 0
5                                 0
6                                 0
```

After zero-fill and rate recalculation:

```
# A tibble: 10 × 2
   variable                             n_missing_after
   <chr>                                          <int>
 1 sglt2_prescriptions                                0
 2 sglt2_units                                        0
 3 sglt2_medicaid_reimbursed                          0
 4 sglt2_total_reimbursed                             0
 5 n_rows                                             0
 6 n_ndcs                                             0
 7 sglt2_prescriptions_per_10000                      0
 8 sglt2_units_per_10000                              0
 9 sglt2_medicaid_reimbursed_per_10000                0
10 sglt2_reimbursement_per_prescription               5
```

## RUCC Rurality

County-level RUCC 2023 data were reshaped from long to wide format. Metro counties were defined as RUCC 1-3 and nonmetro counties as RUCC 4-9. State rurality is based on the proportion of the 2020 state population living in nonmetro counties. Rurality quintiles were created using `ntile(desc(rucc_nonmetro_population_share_2023), 5)`, so Q1 is most rural and Q5 is most urban.

## Structural Covariates

All non-expansion covariates are treated as fixed structural state-level covariates in this analysis table. Medicaid expansion is the only time-varying covariate.

## Assumptions

- Medicaid expansion is the only time-varying covariate in this master table.
- Missing SGLT2 prescribing outcomes/counts/reimbursements are interpreted as zero only when valid Medicaid enrolment exists for that state-quarter.
- AHRF physician density is treated as 2023 time-invariant structural access.
- CMS MMD disease burden is treated as 2023 time-invariant disease burden.
- SVI is treated as 2022 time-invariant social vulnerability.
- RUCC is treated as 2023 time-invariant rurality.
- Census region is treated as time-invariant geography.
- RUCC state-level rurality is based on the proportion of the 2020 state population living in nonmetro counties, where nonmetro is defined as RUCC 4-9.
- Disease burden is Medicare FFS-based and used as a state-level proxy, not Medicaid-specific prevalence.
- HF/IHD is not pure heart failure prevalence. It is CMS MMD Heart Failure and Non-Ischemic Heart Disease prevalence.
- The final master table contains `medicaid_enrolment_quarter_avg` as the only Medicaid denominator column.

## Missingness Summary

```
# A tibble: 23 × 4
   variable                                   n_missing n_non_missing
   <chr>                                          <int>         <int>
 1 medicaid_expansion_effective_date                380          1558
 2 census_division                                    0          1938
 3 census_region                                      0          1938
 4 cvd_physicians_per_100k_2023                       0          1938
 5 medicaid_expansion_active                          0          1938
 6 medicaid_expansion_active_any_part_quarter         0          1938
 7 medicaid_expansion_ever_adopted                    0          1938
 8 medicare_ffs_ckd_prevalence_2023                   0          1938
 9 medicare_ffs_diabetes_prevalence_2023              0          1938
10 medicare_ffs_hf_ihd_prevalence_2023                0          1938
11 number_cvd_physicians_2023                         0          1938
12 number_physicians_2023                             0          1938
13 number_primary_care_physicians_2023                0          1938
14 physicians_per_100k_2023                           0          1938
15 population_2023_ahrf                               0          1938
16 primary_care_physicians_per_100k_2023              0          1938
17 rucc_nonmetro_population_share_2023                0          1938
18 rurality_quintile                                  0          1938
19 rurality_quintile_label                            0          1938
20 svi_2022                                           0          1938
21 svi_counties_used_2022                             0          1938
22 svi_population_weight_2022                         0          1938
23 svi_source_year                                    0          1938
   pct_missing
         <dbl>
 1        19.6
 2         0  
 3         0  
 4         0  
 5         0  
 6         0  
 7         0  
 8         0  
 9         0  
10         0  
11         0  
12         0  
13         0  
14         0  
15         0  
16         0  
17         0  
18         0  
19         0  
20         0  
21         0  
22         0  
23         0  
```

## Rurality Quintile Membership Summary

```
# A tibble: 5 × 6
  rurality_quintile rurality_quintile_label n_states
              <int> <chr>                      <int>
1                 1 Q1 most rural                 11
2                 2 Q2                            10
3                 3 Q3                            10
4                 4 Q4                            10
5                 5 Q5 most urban                 10
  states                                     min_nonmetro_share
  <chr>                                                   <dbl>
1 WY, VT, MS, SD, MT, ME, ND, AR, WV, IA, KY             0.382 
2 NH, NE, NM, AK, OK, KS, ID, WI, MO, DE                 0.240 
3 AL, MN, IN, TN, NC, HI, OH, GA, MI, LA                 0.159 
4 OR, SC, PA, IL, VA, CO, UT, WA, TX, NV                 0.0743
5 NY, CT, AZ, MD, FL, CA, MA, DC, NJ, RI                 0     
  max_nonmetro_share
               <dbl>
1             0.687 
2             0.370 
3             0.223 
4             0.151 
5             0.0688
```

## Residual Issues to Check Manually

- No missing key covariates detected; review source definitions before final modelling.

## Derived Outputs

- `for_analysis/master_state_quarter_sglt2_covariates_poc.csv`
- `for_analysis/rucc_state_rurality_2023.csv`
- `for_analysis/master_poc_missingness_report.csv`
- `for_analysis/rurality_quintile_membership_2023.csv`
