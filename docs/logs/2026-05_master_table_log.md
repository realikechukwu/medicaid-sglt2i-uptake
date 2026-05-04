# Master Table Log

Date: 2026-05-04

## Inputs

- `/Users/ikechukwuchukwudi/Documents/Academic/IMT-ACF Folder/Papers - Active/r-analysis-sglt2/data_processed/sdud_extracts/sglt2_state_quarter_all_products_2015_2025.csv`
- `/Users/ikechukwuchukwudi/Documents/Academic/IMT-ACF Folder/Papers - Active/r-analysis-sglt2/data_processed/enrolment/medicaid_enrolment_state_quarter.csv`
- `/Users/ikechukwuchukwudi/Documents/Academic/IMT-ACF Folder/Papers - Active/r-analysis-sglt2/data_processed/covariates/medicaid_expansion_state_quarter.csv`
- `/Users/ikechukwuchukwudi/Documents/Academic/IMT-ACF Folder/Papers - Active/r-analysis-sglt2/data_processed/covariates/ahrf_physician_density_2023_50dc.csv`
- `/Users/ikechukwuchukwudi/Documents/Academic/IMT-ACF Folder/Papers - Active/r-analysis-sglt2/data_processed/covariates/mmd_disease_burden_2023_50dc.csv`
- `/Users/ikechukwuchukwudi/Documents/Academic/IMT-ACF Folder/Papers - Active/r-analysis-sglt2/data_processed/covariates/rucc_state_rurality_2023.csv`
- `/Users/ikechukwuchukwudi/Documents/Academic/IMT-ACF Folder/Papers - Active/r-analysis-sglt2/data_processed/covariates/svi_state_2022_50dc.csv`
- `/Users/ikechukwuchukwudi/Documents/Academic/IMT-ACF Folder/Papers - Active/r-analysis-sglt2/data_processed/covariates/census_region_division_50dc.csv`

## Output

- `/Users/ikechukwuchukwudi/Documents/Academic/IMT-ACF Folder/Papers - Active/r-analysis-sglt2/for_analysis/master/master_state_quarter_sglt2_covariates.csv`
- Rows: 1938
- Columns: 42

## Validation

- One row per `state`-`year`-`quarter`.
- 2020 excluded.
- PR and XX excluded.
- `medicaid_enrolment_quarter_avg` is the only Medicaid denominator in the master table.
- SGLT2 outcome/count values are zero-filled only where Medicaid enrolment is valid.
- Enrolment and covariates are not zero-filled.

## State-Quarter Counts

```
# A tibble: 38 × 3
    year quarter n_states
   <int>   <int>    <int>
 1  2015       1       51
 2  2015       2       51
 3  2015       3       51
 4  2015       4       51
 5  2016       1       51
 6  2016       2       51
 7  2016       3       51
 8  2016       4       51
 9  2017       1       51
10  2017       2       51
11  2017       3       51
12  2017       4       51
13  2018       1       51
14  2018       2       51
15  2018       3       51
16  2018       4       51
17  2019       1       51
18  2019       2       51
19  2019       3       51
20  2019       4       51
21  2021       1       51
22  2021       2       51
23  2021       3       51
24  2021       4       51
25  2022       1       51
26  2022       2       51
27  2022       3       51
28  2022       4       51
29  2023       1       51
30  2023       2       51
31  2023       3       51
32  2023       4       51
33  2024       1       51
34  2024       2       51
35  2024       3       51
36  2024       4       51
37  2025       1       51
38  2025       2       51
```

## Missingness

```
# A tibble: 42 × 4
   variable                                   n_missing n_non_missing
   <chr>                                          <int>         <int>
 1 medicaid_expansion_effective_date                380          1558
 2 sglt2_reimbursement_per_prescription               5          1933
 3 census_division                                    0          1938
 4 census_region                                      0          1938
 5 cvd_physicians_per_100k_2023                       0          1938
 6 medicaid_enrolment_quarter_avg                     0          1938
 7 medicaid_expansion_active                          0          1938
 8 medicaid_expansion_active_any_part_quarter         0          1938
 9 medicaid_expansion_ever_adopted                    0          1938
10 medicare_ffs_ckd_prevalence_2023                   0          1938
11 medicare_ffs_diabetes_prevalence_2023              0          1938
12 medicare_ffs_hf_ihd_prevalence_2023                0          1938
13 n_enrolment_months                                 0          1938
14 n_ndcs                                             0          1938
15 n_rows                                             0          1938
16 number_cvd_physicians_2023                         0          1938
17 number_physicians_2023                             0          1938
18 number_primary_care_physicians_2023                0          1938
19 physicians_per_100k_2023                           0          1938
20 population_2023_ahrf                               0          1938
21 primary_care_physicians_per_100k_2023              0          1938
22 quarter                                            0          1938
23 quarter_end_date                                   0          1938
24 quarter_start_date                                 0          1938
25 rucc_nonmetro_county_share_2023                    0          1938
26 rucc_nonmetro_population_share_2023                0          1938
27 rurality_quintile                                  0          1938
28 rurality_quintile_label                            0          1938
29 sglt2_medicaid_reimbursed                          0          1938
30 sglt2_medicaid_reimbursed_per_10000                0          1938
31 sglt2_prescriptions_all_products                   0          1938
32 sglt2_prescriptions_all_products_per_10000         0          1938
33 sglt2_total_reimbursed                             0          1938
34 sglt2_units_all_products                           0          1938
35 sglt2_units_all_products_per_10000                 0          1938
36 state                                              0          1938
37 svi_2022                                           0          1938
38 svi_2022_per_0_1                                   0          1938
39 svi_counties_used_2022                             0          1938
40 svi_population_weight_2022                         0          1938
41 svi_source_year                                    0          1938
42 year                                               0          1938
   pct_missing
         <dbl>
 1      19.6  
 2       0.258
 3       0    
 4       0    
 5       0    
 6       0    
 7       0    
 8       0    
 9       0    
10       0    
11       0    
12       0    
13       0    
14       0    
15       0    
16       0    
17       0    
18       0    
19       0    
20       0    
21       0    
22       0    
23       0    
24       0    
25       0    
26       0    
27       0    
28       0    
29       0    
30       0    
31       0    
32       0    
33       0    
34       0    
35       0    
36       0    
37       0    
38       0    
39       0    
40       0    
41       0    
42       0    
```
