# SGLT2 Prescribing Modelling Log

Date: 2026-05-03

## Purpose

Fit descriptive summaries, plots, and negative binomial regression models for Medicaid SGLT2 inhibitor prescribing across state-quarters.

## Input File

- `for_analysis/master_state_quarter_sglt2_covariates_poc.csv`

## Cleaning Before Modelling

- The modelling script requires `medicaid_enrolment_quarter_avg` as the only Medicaid denominator column.
- Rows were restricted to 50 states plus DC, excluded 2020, excluded PR/XX, and required positive non-missing Medicaid enrolment.
- The script checks for missing SGLT2 outcome/count/reimbursement values with valid Medicaid enrolment and treats them as zero in the modelling input only. Medicaid enrolment and covariates are not zero-filled.
- SGLT2 prescribing rates per 10,000 are recalculated after this correction and are used only for descriptive summaries and plots.
- `sglt2_reimbursement_per_prescription` is set to NA when `sglt2_prescriptions == 0`.

## Outcome and Offset

- Main regression outcome: `sglt2_prescriptions`.
- Offset: `log_medicaid_enrolment = log(medicaid_enrolment_quarter_avg)`.
- This specification estimates prescribing rate ratios rather than modelling the pre-calculated prescribing rate as the primary outcome.

## Why Negative Binomial Regression

The outcome is a count and the Poisson comparison showed overdispersion. Negative binomial regression was used to estimate incidence rate ratios while allowing extra-Poisson variation.

## Exploratory Trend Analyses

- National quarterly prescribing trends were summarised from total prescriptions and total Medicaid enrolment.
- Rurality-quintile and SVI-quintile trends were summarised using aggregated prescriptions and enrolment within each quarter.
- State-level mean prescribing rates were used for rurality membership and SVI scatter plots.

## Model Sequence

- Model 0: Time trend only.
- Model 1: Rurality plus year and quarter.
- Model 2: SVI plus year and quarter.
- Model 3: Rurality plus SVI plus year and quarter.
- Model 4: Adds Medicaid expansion.
- Model 5: Adds CVD physician density.
- Model 6: Adds cardiometabolic disease burden.
- Model 7: Adds Census region.
- Model S1: Continuous rurality sensitivity.
- Model S2: Complete years through 2024 sensitivity.

## Interpretation of IRRs

- IRR < 1 indicates a lower SGLT2 prescribing rate relative to the reference group or per-unit comparison.
- For rurality, Q5 most urban is the reference group.
- For SVI, the IRR corresponds to each 0.1 higher state-level SVI.
- Key result confidence intervals and p-values use state-clustered robust standard errors when available.

## Key Rurality Results

In Model 6, Q1 most rural versus Q5 most urban had IRR 0.788 (95% CI 0.462-1.345).

## Key SVI Results

In Model 6, each 0.1 higher SVI had IRR 0.868 (95% CI 0.784-0.960).

## Covariate Adjustment

The Q1 rurality IRR changed from 0.770 in Model 3 to 0.788 in Model 6. The SVI IRR changed from 0.939 in Model 3 to 0.868 in Model 6.
In Model 6, Medicaid expansion active had IRR 1.711 (95% CI 1.366-2.143).
In Model 6, each additional CVD physician per 100k had IRR 0.992 (95% CI 0.956-1.028).

## Key Results Table

```
# A tibble: 22 × 8
   model_name                              exposure             
   <chr>                                   <chr>                
 1 Model 1: Rurality + time                Rurality             
 2 Model 3: Rurality + SVI + time          Rurality             
 3 Model 4: Add Medicaid expansion         Rurality             
 4 Model 5: Add CVD physician density      Rurality             
 5 Model 6: Full model with disease burden Rurality             
 6 Model 7: Region-adjusted full model     Rurality             
 7 Model 6: Full model with disease burden Rurality             
 8 Model 6: Full model with disease burden Rurality             
 9 Model 6: Full model with disease burden Rurality             
10 Model 2: SVI + time                     SVI                  
11 Model 3: Rurality + SVI + time          SVI                  
12 Model 4: Add Medicaid expansion         SVI                  
13 Model 5: Add CVD physician density      SVI                  
14 Model 6: Full model with disease burden SVI                  
15 Model 7: Region-adjusted full model     SVI                  
16 Model 4: Add Medicaid expansion         Medicaid expansion   
17 Model 5: Add CVD physician density      Medicaid expansion   
18 Model 6: Full model with disease burden Medicaid expansion   
19 Model 7: Region-adjusted full model     Medicaid expansion   
20 Model 5: Add CVD physician density      CVD physician density
21 Model 6: Full model with disease burden CVD physician density
22 Model 7: Region-adjusted full model     CVD physician density
   comparison_or_unit               irr conf_low conf_high    p_value
   <chr>                          <dbl>    <dbl>     <dbl>      <dbl>
 1 Q1 most rural vs Q5 most urban 0.869    0.538      1.40 0.566     
 2 Q1 most rural vs Q5 most urban 0.77     0.434      1.37 0.373     
 3 Q1 most rural vs Q5 most urban 0.88     0.52       1.49 0.633     
 4 Q1 most rural vs Q5 most urban 0.982    0.54       1.78 0.953     
 5 Q1 most rural vs Q5 most urban 0.788    0.462      1.34 0.382     
 6 Q1 most rural vs Q5 most urban 1.02     0.634      1.63 0.944     
 7 Q2 vs Q5 most urban            0.922    0.603      1.41 0.708     
 8 Q3 vs Q5 most urban            0.72     0.502      1.03 0.0746    
 9 Q4 vs Q5 most urban            0.776    0.52       1.16 0.214     
10 Per 0.1 increase               0.956    0.893      1.02 0.194     
11 Per 0.1 increase               0.939    0.857      1.03 0.173     
12 Per 0.1 increase               0.957    0.875      1.05 0.34      
13 Per 0.1 increase               0.964    0.879      1.06 0.44      
14 Per 0.1 increase               0.868    0.784      0.96 0.00613   
15 Per 0.1 increase               0.898    0.806      1    0.0494    
16 Active vs not active           1.65     1.28       2.13 0.000111  
17 Active vs not active           1.64     1.28       2.10 0.00009   
18 Active vs not active           1.71     1.37       2.14 0.00000299
19 Active vs not active           1.53     1.18       1.98 0.00122   
20 Per 1 CVD physician per 100k   1.02     0.968      1.08 0.458     
21 Per 1 CVD physician per 100k   0.992    0.956      1.03 0.647     
22 Per 1 CVD physician per 100k   1.00     0.967      1.04 0.815     
   interpretation                                                               
   <chr>                                                                        
 1 For rurality, Q5 most urban is the reference; IRR < 1 indicates lower prescr…
 2 For rurality, Q5 most urban is the reference; IRR < 1 indicates lower prescr…
 3 For rurality, Q5 most urban is the reference; IRR < 1 indicates lower prescr…
 4 For rurality, Q5 most urban is the reference; IRR < 1 indicates lower prescr…
 5 For rurality, Q5 most urban is the reference; IRR < 1 indicates lower prescr…
 6 For rurality, Q5 most urban is the reference; IRR < 1 indicates lower prescr…
 7 For rurality, Q5 most urban is the reference; IRR < 1 indicates lower prescr…
 8 For rurality, Q5 most urban is the reference; IRR < 1 indicates lower prescr…
 9 For rurality, Q5 most urban is the reference; IRR < 1 indicates lower prescr…
10 For SVI, IRR corresponds to each 0.1 higher state-level SVI.                 
11 For SVI, IRR corresponds to each 0.1 higher state-level SVI.                 
12 For SVI, IRR corresponds to each 0.1 higher state-level SVI.                 
13 For SVI, IRR corresponds to each 0.1 higher state-level SVI.                 
14 For SVI, IRR corresponds to each 0.1 higher state-level SVI.                 
15 For SVI, IRR corresponds to each 0.1 higher state-level SVI.                 
16 IRR compares active Medicaid expansion state-quarters with non-active state-…
17 IRR compares active Medicaid expansion state-quarters with non-active state-…
18 IRR compares active Medicaid expansion state-quarters with non-active state-…
19 IRR compares active Medicaid expansion state-quarters with non-active state-…
20 IRR corresponds to each additional CVD physician per 100,000 population.     
21 IRR corresponds to each additional CVD physician per 100,000 population.     
22 IRR corresponds to each additional CVD physician per 100,000 population.     
```

## Missingness and Convergence

Raw missingness with nonzero missing counts:

```
# A tibble: 2 × 3
  variable                             n_missing pct_missing
  <chr>                                    <int>       <dbl>
1 medicaid_expansion_effective_date          380       19.6 
2 sglt2_reimbursement_per_prescription         5        0.26
```

Model diagnostics:

```
# A tibble: 10 × 9
   model_name                                status    n_observations    aic
   <chr>                                     <chr>              <int>  <dbl>
 1 Model 0: Time trend only                  succeeded           1938 34963.
 2 Model 1: Rurality + time                  succeeded           1938 34862.
 3 Model 2: SVI + time                       succeeded           1938 34891.
 4 Model 3: Rurality + SVI + time            succeeded           1938 34825.
 5 Model 4: Add Medicaid expansion           succeeded           1938 34588.
 6 Model 5: Add CVD physician density        succeeded           1938 34581.
 7 Model 6: Full model with disease burden   succeeded           1938 34267.
 8 Model 7: Region-adjusted full model       succeeded           1938 34161.
 9 Model S1: Continuous rurality sensitivity succeeded           1938 34301.
10 Model S2: Complete years through 2024     succeeded           1836 32262.
   theta converged robust_se_status warnings error
   <dbl> <lgl>     <chr>            <chr>    <chr>
 1  2.50 TRUE      succeeded        ""       <NA> 
 2  2.66 TRUE      succeeded        ""       <NA> 
 3  2.61 TRUE      succeeded        ""       <NA> 
 4  2.70 TRUE      succeeded        ""       <NA> 
 5  3.03 TRUE      succeeded        ""       <NA> 
 6  3.04 TRUE      succeeded        ""       <NA> 
 7  3.55 TRUE      succeeded        ""       <NA> 
 8  3.75 TRUE      succeeded        ""       <NA> 
 9  3.48 TRUE      succeeded        ""       <NA> 
10  3.42 TRUE      succeeded        ""       <NA> 
```

Poisson overdispersion check:

```
# A tibble: 1 × 7
  model                                         n_observations residual_deviance
  <chr>                                                  <int>             <dbl>
1 Poisson comparison: rurality + year + quarter           1938          3942801.
  residual_df dispersion_ratio warnings error
        <int>            <dbl> <chr>    <chr>
1        1921            2052. ""       <NA> 
```

## Residual Limitations

- State-level structural covariates are time-invariant in this analysis.
- Disease burden variables are Medicare FFS-based proxies and are not Medicaid-specific prevalence estimates.
- Medicaid expansion timing is included, but other time-varying state policies are not yet modelled.
- Cluster-robust standard errors address repeated observations by state, but the models remain ecological state-quarter analyses.

## Recommended Next Steps

- Review source definitions and covariate validity before final modelling.
- Consider state fixed effects or random effects depending on the estimand.
- Evaluate product-specific outcomes, including single-agent SGLT2 inhibitors and empagliflozin/dapagliflozin.
- Compare CVD physician density with primary care and total physician density specifications.
- Add region or other geographic controls if available and analytically justified.
- Pre-specify the final estimand and sensitivity analysis set before manuscript modelling.

## Outputs

- `for_analysis/model_outputs/model_input_cleaned_all_products.csv`
- `for_analysis/model_outputs/key_results_summary.csv`
- `for_analysis/model_outputs/model_diagnostics_summary.csv`
- `for_analysis/model_outputs/poisson_overdispersion_check.csv`
- `for_analysis/model_outputs/plots/`

## Sensitivity analyses using single-agent and empagliflozin/dapagliflozin outcomes

A narrow sensitivity workflow joined single-agent SGLT2 and empagliflozin/dapagliflozin state-quarter prescribing outcomes onto the existing master table by `state`, `year`, and `quarter`.

- Updated sensitivity master table: `for_analysis/master_state_quarter_sglt2_covariates_with_sensitivity_outcomes_poc.csv`.
- Existing all-product outcome columns were renamed in the updated master table to `sglt2_prescriptions_all_products`, `sglt2_units_all_products`, and `sglt2_prescriptions_all_products_per_10000`.
- Missing sensitivity prescribing and unit counts after the join were set to 0 only when valid Medicaid enrolment was present.
- Sensitivity prescribing rates per 10,000 were recalculated using the master-table `medicaid_enrolment_quarter_avg` denominator.
- Medicaid enrolment and covariates were not zero-filled.
- Only the fully adjusted negative binomial model was fit for each outcome; the staged model sequence was not rerun for sensitivity outcomes.
- Q5 most urban remained the rurality reference group, and SVI was scaled per 0.1 increase.
- State-clustered robust standard errors were used when available.

Key sensitivity results:

```
# A tibble: 12 × 10
   outcome                       exposure             
   <fct>                         <fct>                
 1 All products                  Rurality             
 2 All products                  SVI                  
 3 All products                  Medicaid expansion   
 4 All products                  CVD physician density
 5 Single-agent SGLT2 inhibitors Rurality             
 6 Single-agent SGLT2 inhibitors SVI                  
 7 Single-agent SGLT2 inhibitors Medicaid expansion   
 8 Single-agent SGLT2 inhibitors CVD physician density
 9 Empagliflozin/dapagliflozin   Rurality             
10 Empagliflozin/dapagliflozin   SVI                  
11 Empagliflozin/dapagliflozin   Medicaid expansion   
12 Empagliflozin/dapagliflozin   CVD physician density
   comparison_or_unit             term                           irr conf_low
   <chr>                          <chr>                        <dbl>    <dbl>
 1 Q1 most rural vs Q5 most urban rurality_quintile1           0.788    0.462
 2 Per 0.1 increase               svi_2022_per_0_1             0.868    0.784
 3 Active vs not active           medicaid_expansion_active    1.71     1.37 
 4 Per 1 CVD physician per 100k   cvd_physicians_per_100k_2023 0.992    0.956
 5 Q1 most rural vs Q5 most urban rurality_quintile1           0.808    0.475
 6 Per 0.1 increase               svi_2022_per_0_1             0.863    0.781
 7 Active vs not active           medicaid_expansion_active    1.72     1.38 
 8 Per 1 CVD physician per 100k   cvd_physicians_per_100k_2023 0.993    0.958
 9 Q1 most rural vs Q5 most urban rurality_quintile1           0.728    0.376
10 Per 0.1 increase               svi_2022_per_0_1             0.845    0.758
11 Active vs not active           medicaid_expansion_active    1.58     1.27 
12 Per 1 CVD physician per 100k   cvd_physicians_per_100k_2023 0.974    0.924
   conf_high    p_value se_type              model_status
       <dbl>      <dbl> <chr>                <chr>       
 1     1.34  0.382      cluster_robust_state succeeded   
 2     0.96  0.00613    cluster_robust_state succeeded   
 3     2.14  0.00000299 cluster_robust_state succeeded   
 4     1.03  0.647      cluster_robust_state succeeded   
 5     1.37  0.432      cluster_robust_state succeeded   
 6     0.953 0.00381    cluster_robust_state succeeded   
 7     2.15  0.0000019  cluster_robust_state succeeded   
 8     1.03  0.703      cluster_robust_state succeeded   
 9     1.41  0.345      cluster_robust_state succeeded   
10     0.942 0.00236    cluster_robust_state succeeded   
11     1.97  0.0000496  cluster_robust_state succeeded   
12     1.03  0.316      cluster_robust_state succeeded   
```

Model diagnostics:

```
# A tibble: 3 × 9
  outcome                       model_status model_error model_warnings
  <chr>                         <chr>        <chr>       <chr>         
1 All products                  succeeded    <NA>        ""            
2 Single-agent SGLT2 inhibitors succeeded    <NA>        ""            
3 Empagliflozin/dapagliflozin   succeeded    <NA>        ""            
  n_observations    aic theta converged se_type             
           <int>  <dbl> <dbl> <lgl>     <chr>               
1           1938 34267.  3.55 TRUE      cluster_robust_state
2           1938 34087.  3.62 TRUE      cluster_robust_state
3           1938 32917.  2.01 TRUE      cluster_robust_state
```

Sensitivity outputs:

- `for_analysis/model_outputs/sensitivity_full_model_all_products.csv`
- `for_analysis/model_outputs/sensitivity_full_model_single_agent.csv`
- `for_analysis/model_outputs/sensitivity_full_model_empa_dapa.csv`
- `for_analysis/model_outputs/sensitivity_outcome_comparison_key_results.csv`
- `for_analysis/model_outputs/plots/sensitivity_outcome_comparison_forest_plot.png`

## Region-adjusted sensitivity analysis

Census region was used as a geographic sensitivity adjustment to assess whether the rurality and SVI associations were partly explained by broad regional differences in Medicaid policy environment, prescribing norms, or access patterns.

- Source/mapping: standard U.S. Census Bureau four-region and nine-division classification. The input master table is required to contain matching `census_region` and `census_division` values.
- Input master table: `for_analysis/master_state_quarter_sglt2_covariates_with_sensitivity_outcomes_poc.csv`.
- Validated region master table copy: `for_analysis/master_state_quarter_sglt2_covariates_with_region_poc.csv`.
- All 51 states/DC matched to Census region and division; no PR or XX rows were present.
- The model used the same fully adjusted negative binomial specification as Model 6, with Census region added and Northeast as the region reference.
- The staged modelling sequence was not rerun.

Key findings:

- SVI remained statistically significant in the region-adjusted model: IRR 0.898 (95% CI 0.806-1).
- The Q1 most rural vs Q5 most urban estimate in the region-adjusted model was IRR 1.017 (95% CI 0.634-1.632).
- The Medicaid expansion estimate in the region-adjusted model was IRR 1.53 (95% CI 1.182-1.979).

Original vs region-adjusted comparison:

```
# A tibble: 4 × 6
  exposure                       original_full_model_irr original_full_model_ci
  <chr>                                            <dbl> <chr>                 
1 Q1 most rural vs Q5 most urban                   0.788 0.788 (0.462-1.345)   
2 SVI per 0.1 increase                             0.868 0.868 (0.784-0.96)    
3 Medicaid expansion active                        1.71  1.711 (1.366-2.143)   
4 CVD physicians per 100k                          0.992 0.992 (0.956-1.028)   
  region_adjusted_model_irr region_adjusted_model_ci
                      <dbl> <chr>                   
1                     1.02  1.017 (0.634-1.632)     
2                     0.898 0.898 (0.806-1)         
3                     1.53  1.53 (1.182-1.979)      
4                     1.00  1.005 (0.967-1.044)     
  interpretation_change                               
  <chr>                                               
1 Region adjustment moved the point estimate upward.  
2 Little material change in point estimate.           
3 Region adjustment moved the point estimate downward.
4 Little material change in point estimate.           
```

Region-adjusted key results:

```
# A tibble: 10 × 8
   term                         exposure             
   <chr>                        <chr>                
 1 rurality_quintile1           Rurality             
 2 rurality_quintile2           Rurality             
 3 rurality_quintile3           Rurality             
 4 rurality_quintile4           Rurality             
 5 svi_2022_per_0_1             SVI                  
 6 medicaid_expansion_active    Medicaid expansion   
 7 cvd_physicians_per_100k_2023 CVD physician density
 8 census_regionMidwest         Census region        
 9 census_regionSouth           Census region        
10 census_regionWest            Census region        
   comparison_or_unit               irr conf_low conf_high p_value
   <chr>                          <dbl>    <dbl>     <dbl>   <dbl>
 1 Q1 most rural vs Q5 most urban 1.02     0.634     1.63  0.944  
 2 Q2 vs Q5                       1.08     0.731     1.6   0.696  
 3 Q3 vs Q5                       0.839    0.61      1.15  0.279  
 4 Q4 vs Q5                       0.893    0.64      1.25  0.504  
 5 Per 0.1 increase               0.898    0.806     1     0.0494 
 6 Active vs not active           1.53     1.18      1.98  0.00122
 7 Per 1 CVD physician per 100k   1.00     0.967     1.04  0.815  
 8 Midwest vs Northeast           0.863    0.643     1.16  0.326  
 9 South vs Northeast             0.626    0.459     0.853 0.00303
10 West vs Northeast              0.94     0.588     1.50  0.796  
   interpretation                                                               
   <chr>                                                                        
 1 Q5 most urban is the reference; IRR < 1 indicates lower prescribing than Q5. 
 2 Q5 most urban is the reference; IRR < 1 indicates lower prescribing than Q5. 
 3 Q5 most urban is the reference; IRR < 1 indicates lower prescribing than Q5. 
 4 Q5 most urban is the reference; IRR < 1 indicates lower prescribing than Q5. 
 5 IRR corresponds to each 0.1 higher state-level SVI.                          
 6 IRR compares active Medicaid expansion state-quarters with non-active state-…
 7 IRR corresponds to each additional CVD physician per 100,000 population.     
 8 Northeast is the Census region reference group.                              
 9 Northeast is the Census region reference group.                              
10 Northeast is the Census region reference group.                              
```

Convergence and missingness:

```
# A tibble: 3 × 10
  outcome                       model_status model_error model_warnings
  <chr>                         <chr>        <chr>       <chr>         
1 All products                  succeeded    <NA>        ""            
2 Single-agent SGLT2 inhibitors succeeded    <NA>        ""            
3 Empagliflozin/dapagliflozin   succeeded    <NA>        ""            
  n_observations    aic theta converged se_type             
           <int>  <dbl> <dbl> <lgl>     <chr>               
1           1938 34161.  3.75 TRUE      cluster_robust_state
2           1938 33982.  3.82 TRUE      cluster_robust_state
3           1938 32805.  2.13 TRUE      cluster_robust_state
  formula                                                                       
  <chr>                                                                         
1 sglt2_prescriptions_all_products ~ rurality_quintile + svi_2022_per_0_1 + med…
2 sglt2_prescriptions_single_agent ~ rurality_quintile + svi_2022_per_0_1 + med…
3 sglt2_prescriptions_empa_dapa ~ rurality_quintile + svi_2022_per_0_1 + medica…
```

Outputs:

- `for_analysis/model_outputs/region_adjusted_full_model_coefficients.csv`
- `for_analysis/model_outputs/region_adjusted_full_model_robust_coefficients.csv`
- `for_analysis/model_outputs/region_adjusted_key_results.csv`
- `for_analysis/model_outputs/region_adjusted_vs_original_key_results.csv`
- `for_analysis/model_outputs/region_adjusted_sensitivity_outcome_comparison.csv`
- `for_analysis/model_outputs/plots/region_adjusted_full_model_forest_plot.png`
