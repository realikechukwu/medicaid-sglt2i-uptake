# Modelling Log

Date: 2026-05-04

## Main Analysis

- Outcome: `sglt2_prescriptions_all_products`.
- Offset: `log_medicaid_enrolment = log(medicaid_enrolment_quarter_avg)`.
- Model: negative binomial regression.
- Standard errors: state-clustered robust standard errors when available.
- Covariates: rurality quintile, SVI per 0.1, Medicaid expansion active, CVD physician density, Medicare FFS HF/IHD, diabetes, CKD prevalence, year fixed effects, quarter fixed effects.

## Outputs

- `for_analysis/model_outputs/tables/main_model_key_results.csv`
- `for_analysis/model_outputs/tables/main_model_full_coefficients.csv`
- `for_analysis/model_outputs/tables/main_model_full_cluster_robust_coefficients.csv`
- `for_analysis/model_outputs/diagnostics/model_diagnostics_summary.csv`
- `for_analysis/model_outputs/diagnostics/poisson_overdispersion_check.csv`
- `for_analysis/model_outputs/figures/fig1_national_quarterly_sglt2_rate.png` through `fig7_main_model_forest_plot.png`

## Key Results

```
# A tibble: 11 × 11
   model_id                        model_name                     
   <chr>                           <chr>                          
 1 main_full                       Main fully adjusted model      
 2 main_full                       Main fully adjusted model      
 3 main_full                       Main fully adjusted model      
 4 main_full                       Main fully adjusted model      
 5 main_full                       Main fully adjusted model      
 6 main_full                       Main fully adjusted model      
 7 main_full                       Main fully adjusted model      
 8 main_full                       Main fully adjusted model      
 9 main_full                       Main fully adjusted model      
10 main_full                       Main fully adjusted model      
11 sensitivity_continuous_rurality Continuous rurality sensitivity
   exposure             
   <chr>                
 1 Rurality             
 2 Rurality             
 3 Rurality             
 4 Rurality             
 5 SVI                  
 6 Medicaid expansion   
 7 CVD physician density
 8 Disease burden       
 9 Disease burden       
10 Disease burden       
11 Continuous rurality  
   comparison_or_unit                                      
   <chr>                                                   
 1 Q4 vs Q5 most urban                                     
 2 Q3 vs Q5 most urban                                     
 3 Q2 vs Q5 most urban                                     
 4 Q1 most rural vs Q5 most urban                          
 5 Per 0.1 increase                                        
 6 Active vs not active                                    
 7 Per 1 CVD physician per 100k                            
 8 HF/IHD prevalence                                       
 9 Diabetes prevalence                                     
10 CKD prevalence                                          
11 Per 10 percentage-point higher nonmetro population share
   term                                       irr conf_low conf_high    p_value
   <chr>                                    <dbl>    <dbl>     <dbl>      <dbl>
 1 rurality_quintile4                       0.776    0.520     1.16  0.214     
 2 rurality_quintile3                       0.720    0.502     1.03  0.0746    
 3 rurality_quintile2                       0.922    0.603     1.41  0.708     
 4 rurality_quintile1                       0.788    0.462     1.34  0.382     
 5 svi_2022_per_0_1                         0.868    0.784     0.960 0.00613   
 6 medicaid_expansion_active                1.71     1.37      2.14  0.00000299
 7 cvd_physicians_per_100k_2023             0.992    0.956     1.03  0.647     
 8 medicare_ffs_hf_ihd_prevalence_2023      1.04     0.956     1.13  0.384     
 9 medicare_ffs_diabetes_prevalence_2023    1.07     1.01      1.12  0.0124    
10 medicare_ffs_ckd_prevalence_2023         1.03     0.982     1.07  0.241     
11 rucc_nonmetro_population_share_per_10pct 0.933    0.847     1.03  0.161     
   se_type             
   <chr>               
 1 cluster_robust_state
 2 cluster_robust_state
 3 cluster_robust_state
 4 cluster_robust_state
 5 cluster_robust_state
 6 cluster_robust_state
 7 cluster_robust_state
 8 cluster_robust_state
 9 cluster_robust_state
10 cluster_robust_state
11 cluster_robust_state
   interpretation                                                               
   <chr>                                                                        
 1 Q5 most urban is the reference.                                              
 2 Q5 most urban is the reference.                                              
 3 Q5 most urban is the reference.                                              
 4 Q5 most urban is the reference; IRR below 1 indicates lower prescribing.     
 5 IRR for each 0.1 higher state-level SVI.                                     
 6 IRR comparing active expansion state-quarters with non-active state-quarters.
 7 IRR for each additional CVD physician per 100,000 population.                
 8 Medicare FFS state-level prevalence proxy.                                   
 9 Medicare FFS state-level prevalence proxy.                                   
10 Medicare FFS state-level prevalence proxy.                                   
11 Sensitivity model replacing rurality quintile with continuous nonmetro popul…
```

## Sensitivity Outcome Models

- Built `for_analysis/master/master_state_quarter_sglt2_covariates_with_sensitivity_outcomes.csv`.
- Outcomes: all products, single-agent SGLT2 inhibitors, and empagliflozin/dapagliflozin.
- Model specification matches the fully adjusted main model.
- Sensitivity outcome counts are zero-filled only where Medicaid enrolment is valid.

```
# A tibble: 12 × 9
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
   conf_high    p_value se_type             
       <dbl>      <dbl> <chr>               
 1     1.34  0.382      cluster_robust_state
 2     0.960 0.00613    cluster_robust_state
 3     2.14  0.00000299 cluster_robust_state
 4     1.03  0.647      cluster_robust_state
 5     1.37  0.432      cluster_robust_state
 6     0.953 0.00381    cluster_robust_state
 7     2.15  0.00000190 cluster_robust_state
 8     1.03  0.703      cluster_robust_state
 9     1.41  0.345      cluster_robust_state
10     0.942 0.00236    cluster_robust_state
11     1.97  0.0000496  cluster_robust_state
12     1.03  0.316      cluster_robust_state
```

## Region-Adjusted Sensitivity Models

- Added Census region to the fully adjusted negative binomial model.
- Ran region-adjusted models for all-products, single-agent, and empagliflozin/dapagliflozin outcomes.
- Wrote final region-adjusted key and comparison tables.

Region-adjusted all-products key results:

```
# A tibble: 10 × 10
   outcome      exposure              comparison_or_unit            
   <chr>        <chr>                 <chr>                         
 1 All products Rurality              Q1 most rural vs Q5 most urban
 2 All products Rurality              Q2 vs Q5 most urban           
 3 All products Rurality              Q3 vs Q5 most urban           
 4 All products Rurality              Q4 vs Q5 most urban           
 5 All products SVI                   Per 0.1 increase              
 6 All products Medicaid expansion    Active vs not active          
 7 All products CVD physician density Per 1 CVD physician per 100k  
 8 All products Census region         Midwest vs Northeast          
 9 All products Census region         South vs Northeast            
10 All products Census region         West vs Northeast             
   term                           irr conf_low conf_high p_value
   <chr>                        <dbl>    <dbl>     <dbl>   <dbl>
 1 rurality_quintile1           1.02     0.634     1.63  0.944  
 2 rurality_quintile2           1.08     0.731     1.60  0.696  
 3 rurality_quintile3           0.839    0.610     1.15  0.279  
 4 rurality_quintile4           0.893    0.640     1.25  0.504  
 5 svi_2022_per_0_1             0.898    0.806     1.00  0.0494 
 6 medicaid_expansion_active    1.53     1.18      1.98  0.00122
 7 cvd_physicians_per_100k_2023 1.00     0.967     1.04  0.815  
 8 census_regionMidwest         0.863    0.643     1.16  0.326  
 9 census_regionSouth           0.626    0.459     0.853 0.00303
10 census_regionWest            0.940    0.588     1.50  0.796  
   se_type             
   <chr>               
 1 cluster_robust_state
 2 cluster_robust_state
 3 cluster_robust_state
 4 cluster_robust_state
 5 cluster_robust_state
 6 cluster_robust_state
 7 cluster_robust_state
 8 cluster_robust_state
 9 cluster_robust_state
10 cluster_robust_state
   interpretation                                                               
   <chr>                                                                        
 1 Q5 most urban is the reference.                                              
 2 Q5 most urban is the reference.                                              
 3 Q5 most urban is the reference.                                              
 4 Q5 most urban is the reference.                                              
 5 IRR for each 0.1 higher SVI.                                                 
 6 IRR comparing active expansion state-quarters with non-active state-quarters.
 7 IRR for each additional CVD physician per 100,000 population.                
 8 Northeast is the Census region reference.                                    
 9 Northeast is the Census region reference.                                    
10 Northeast is the Census region reference.                                    
```

Region-adjusted sensitivity outcome key results:

```
# A tibble: 30 × 10
   outcome                       exposure             
   <chr>                         <chr>                
 1 All products                  Rurality             
 2 All products                  Rurality             
 3 All products                  Rurality             
 4 All products                  Rurality             
 5 All products                  SVI                  
 6 All products                  Medicaid expansion   
 7 All products                  CVD physician density
 8 All products                  Census region        
 9 All products                  Census region        
10 All products                  Census region        
11 Single-agent SGLT2 inhibitors Rurality             
12 Single-agent SGLT2 inhibitors Rurality             
13 Single-agent SGLT2 inhibitors Rurality             
14 Single-agent SGLT2 inhibitors Rurality             
15 Single-agent SGLT2 inhibitors SVI                  
16 Single-agent SGLT2 inhibitors Medicaid expansion   
17 Single-agent SGLT2 inhibitors CVD physician density
18 Single-agent SGLT2 inhibitors Census region        
19 Single-agent SGLT2 inhibitors Census region        
20 Single-agent SGLT2 inhibitors Census region        
21 Empagliflozin/dapagliflozin   Rurality             
22 Empagliflozin/dapagliflozin   Rurality             
23 Empagliflozin/dapagliflozin   Rurality             
24 Empagliflozin/dapagliflozin   Rurality             
25 Empagliflozin/dapagliflozin   SVI                  
26 Empagliflozin/dapagliflozin   Medicaid expansion   
27 Empagliflozin/dapagliflozin   CVD physician density
28 Empagliflozin/dapagliflozin   Census region        
29 Empagliflozin/dapagliflozin   Census region        
30 Empagliflozin/dapagliflozin   Census region        
   comparison_or_unit             term                           irr conf_low
   <chr>                          <chr>                        <dbl>    <dbl>
 1 Q1 most rural vs Q5 most urban rurality_quintile1           1.02     0.634
 2 Q2 vs Q5 most urban            rurality_quintile2           1.08     0.731
 3 Q3 vs Q5 most urban            rurality_quintile3           0.839    0.610
 4 Q4 vs Q5 most urban            rurality_quintile4           0.893    0.640
 5 Per 0.1 increase               svi_2022_per_0_1             0.898    0.806
 6 Active vs not active           medicaid_expansion_active    1.53     1.18 
 7 Per 1 CVD physician per 100k   cvd_physicians_per_100k_2023 1.00     0.967
 8 Midwest vs Northeast           census_regionMidwest         0.863    0.643
 9 South vs Northeast             census_regionSouth           0.626    0.459
10 West vs Northeast              census_regionWest            0.940    0.588
11 Q1 most rural vs Q5 most urban rurality_quintile1           1.04     0.650
12 Q2 vs Q5 most urban            rurality_quintile2           1.11     0.754
13 Q3 vs Q5 most urban            rurality_quintile3           0.857    0.627
14 Q4 vs Q5 most urban            rurality_quintile4           0.909    0.660
15 Per 0.1 increase               svi_2022_per_0_1             0.891    0.801
16 Active vs not active           medicaid_expansion_active    1.54     1.19 
17 Per 1 CVD physician per 100k   cvd_physicians_per_100k_2023 1.01     0.969
18 Midwest vs Northeast           census_regionMidwest         0.868    0.649
19 South vs Northeast             census_regionSouth           0.634    0.466
20 West vs Northeast              census_regionWest            0.953    0.600
21 Q1 most rural vs Q5 most urban rurality_quintile1           0.943    0.566
22 Q2 vs Q5 most urban            rurality_quintile2           0.916    0.568
23 Q3 vs Q5 most urban            rurality_quintile3           0.774    0.537
24 Q4 vs Q5 most urban            rurality_quintile4           0.835    0.554
25 Per 0.1 increase               svi_2022_per_0_1             0.880    0.786
26 Active vs not active           medicaid_expansion_active    1.38     1.08 
27 Per 1 CVD physician per 100k   cvd_physicians_per_100k_2023 0.970    0.927
28 Midwest vs Northeast           census_regionMidwest         0.659    0.460
29 South vs Northeast             census_regionSouth           0.488    0.345
30 West vs Northeast              census_regionWest            0.750    0.438
   conf_high   p_value se_type             
       <dbl>     <dbl> <chr>               
 1     1.63  0.944     cluster_robust_state
 2     1.60  0.696     cluster_robust_state
 3     1.15  0.279     cluster_robust_state
 4     1.25  0.504     cluster_robust_state
 5     1.00  0.0494    cluster_robust_state
 6     1.98  0.00122   cluster_robust_state
 7     1.04  0.815     cluster_robust_state
 8     1.16  0.326     cluster_robust_state
 9     0.853 0.00303   cluster_robust_state
10     1.50  0.796     cluster_robust_state
11     1.66  0.869     cluster_robust_state
12     1.63  0.596     cluster_robust_state
13     1.17  0.333     cluster_robust_state
14     1.25  0.561     cluster_robust_state
15     0.990 0.0325    cluster_robust_state
16     2.00  0.00108   cluster_robust_state
17     1.05  0.722     cluster_robust_state
18     1.16  0.338     cluster_robust_state
19     0.863 0.00376   cluster_robust_state
20     1.51  0.839     cluster_robust_state
21     1.57  0.821     cluster_robust_state
22     1.48  0.719     cluster_robust_state
23     1.12  0.170     cluster_robust_state
24     1.26  0.387     cluster_robust_state
25     0.985 0.0259    cluster_robust_state
26     1.76  0.0107    cluster_robust_state
27     1.01  0.182     cluster_robust_state
28     0.946 0.0236    cluster_robust_state
29     0.689 0.0000471 cluster_robust_state
30     1.28  0.295     cluster_robust_state
   interpretation                                                               
   <chr>                                                                        
 1 Q5 most urban is the reference.                                              
 2 Q5 most urban is the reference.                                              
 3 Q5 most urban is the reference.                                              
 4 Q5 most urban is the reference.                                              
 5 IRR for each 0.1 higher SVI.                                                 
 6 IRR comparing active expansion state-quarters with non-active state-quarters.
 7 IRR for each additional CVD physician per 100,000 population.                
 8 Northeast is the Census region reference.                                    
 9 Northeast is the Census region reference.                                    
10 Northeast is the Census region reference.                                    
11 Q5 most urban is the reference.                                              
12 Q5 most urban is the reference.                                              
13 Q5 most urban is the reference.                                              
14 Q5 most urban is the reference.                                              
15 IRR for each 0.1 higher SVI.                                                 
16 IRR comparing active expansion state-quarters with non-active state-quarters.
17 IRR for each additional CVD physician per 100,000 population.                
18 Northeast is the Census region reference.                                    
19 Northeast is the Census region reference.                                    
20 Northeast is the Census region reference.                                    
21 Q5 most urban is the reference.                                              
22 Q5 most urban is the reference.                                              
23 Q5 most urban is the reference.                                              
24 Q5 most urban is the reference.                                              
25 IRR for each 0.1 higher SVI.                                                 
26 IRR comparing active expansion state-quarters with non-active state-quarters.
27 IRR for each additional CVD physician per 100,000 population.                
28 Northeast is the Census region reference.                                    
29 Northeast is the Census region reference.                                    
30 Northeast is the Census region reference.                                    
```

## Sequential Adjustment Series

- Models 1-5 fitted in `scripts/09_model_sequential_series.R`; Model 6 is the primary model (script 06) and Model 7 the region-adjusted model (script 08).
- All models: negative binomial, log mean monthly Medicaid enrolment offset, categorical year and quarter, state-clustered robust standard errors.
- Output: `for_analysis/model_outputs/tables/sequential_models_key_results.csv` and `sequential_models_cluster_robust_coefficients.csv`.

```
# A tibble: 37 × 11
   model_id model_label              
   <chr>    <chr>                    
 1 model_1  Model 1                  
 2 model_1  Model 1                  
 3 model_1  Model 1                  
 4 model_1  Model 1                  
 5 model_2  Model 2                  
 6 model_3  Model 3                  
 7 model_3  Model 3                  
 8 model_3  Model 3                  
 9 model_3  Model 3                  
10 model_3  Model 3                  
11 model_4  Model 4                  
12 model_4  Model 4                  
13 model_4  Model 4                  
14 model_4  Model 4                  
15 model_4  Model 4                  
16 model_4  Model 4                  
17 model_5  Model 5                  
18 model_5  Model 5                  
19 model_5  Model 5                  
20 model_5  Model 5                  
21 model_5  Model 5                  
22 model_5  Model 5                  
23 model_5  Model 5                  
24 model_6  Model 6 (primary)        
25 model_6  Model 6 (primary)        
26 model_6  Model 6 (primary)        
27 model_6  Model 6 (primary)        
28 model_6  Model 6 (primary)        
29 model_6  Model 6 (primary)        
30 model_6  Model 6 (primary)        
31 model_7  Model 7 (region-adjusted)
32 model_7  Model 7 (region-adjusted)
33 model_7  Model 7 (region-adjusted)
34 model_7  Model 7 (region-adjusted)
35 model_7  Model 7 (region-adjusted)
36 model_7  Model 7 (region-adjusted)
37 model_7  Model 7 (region-adjusted)
   adjustment_set                                            
   <chr>                                                     
 1 Rurality + time                                           
 2 Rurality + time                                           
 3 Rurality + time                                           
 4 Rurality + time                                           
 5 SVI + time                                                
 6 Rurality + SVI + time                                     
 7 Rurality + SVI + time                                     
 8 Rurality + SVI + time                                     
 9 Rurality + SVI + time                                     
10 Rurality + SVI + time                                     
11 Model 3 + Medicaid expansion                              
12 Model 3 + Medicaid expansion                              
13 Model 3 + Medicaid expansion                              
14 Model 3 + Medicaid expansion                              
15 Model 3 + Medicaid expansion                              
16 Model 3 + Medicaid expansion                              
17 Model 4 + CVD physician density                           
18 Model 4 + CVD physician density                           
19 Model 4 + CVD physician density                           
20 Model 4 + CVD physician density                           
21 Model 4 + CVD physician density                           
22 Model 4 + CVD physician density                           
23 Model 4 + CVD physician density                           
24 Model 5 + Medicare FFS HF/IHD, diabetes and CKD prevalence
25 Model 5 + Medicare FFS HF/IHD, diabetes and CKD prevalence
26 Model 5 + Medicare FFS HF/IHD, diabetes and CKD prevalence
27 Model 5 + Medicare FFS HF/IHD, diabetes and CKD prevalence
28 Model 5 + Medicare FFS HF/IHD, diabetes and CKD prevalence
29 Model 5 + Medicare FFS HF/IHD, diabetes and CKD prevalence
30 Model 5 + Medicare FFS HF/IHD, diabetes and CKD prevalence
31 Model 6 + Census region                                   
32 Model 6 + Census region                                   
33 Model 6 + Census region                                   
34 Model 6 + Census region                                   
35 Model 6 + Census region                                   
36 Model 6 + Census region                                   
37 Model 6 + Census region                                   
   exposure              comparison_or_unit            
   <chr>                 <chr>                         
 1 Rurality              Q1 most rural vs Q5 most urban
 2 Rurality              Q2 vs Q5 most urban           
 3 Rurality              Q3 vs Q5 most urban           
 4 Rurality              Q4 vs Q5 most urban           
 5 SVI                   Per 0.1 increase              
 6 Rurality              Q1 most rural vs Q5 most urban
 7 Rurality              Q2 vs Q5 most urban           
 8 Rurality              Q3 vs Q5 most urban           
 9 Rurality              Q4 vs Q5 most urban           
10 SVI                   Per 0.1 increase              
11 Rurality              Q1 most rural vs Q5 most urban
12 Rurality              Q2 vs Q5 most urban           
13 Rurality              Q3 vs Q5 most urban           
14 Rurality              Q4 vs Q5 most urban           
15 SVI                   Per 0.1 increase              
16 Medicaid expansion    Active vs not active          
17 Rurality              Q1 most rural vs Q5 most urban
18 Rurality              Q2 vs Q5 most urban           
19 Rurality              Q3 vs Q5 most urban           
20 Rurality              Q4 vs Q5 most urban           
21 SVI                   Per 0.1 increase              
22 Medicaid expansion    Active vs not active          
23 CVD physician density Per 1 CVD physician per 100k  
24 Rurality              Q1 most rural vs Q5 most urban
25 Rurality              Q2 vs Q5 most urban           
26 Rurality              Q3 vs Q5 most urban           
27 Rurality              Q4 vs Q5 most urban           
28 SVI                   Per 0.1 increase              
29 Medicaid expansion    Active vs not active          
30 CVD physician density Per 1 CVD physician per 100k  
31 Rurality              Q1 most rural vs Q5 most urban
32 Rurality              Q2 vs Q5 most urban           
33 Rurality              Q3 vs Q5 most urban           
34 Rurality              Q4 vs Q5 most urban           
35 SVI                   Per 0.1 increase              
36 Medicaid expansion    Active vs not active          
37 CVD physician density Per 1 CVD physician per 100k  
   term                           irr conf_low conf_high    p_value
   <chr>                        <dbl>    <dbl>     <dbl>      <dbl>
 1 rurality_quintile1           0.869    0.538     1.40  0.566     
 2 rurality_quintile2           0.858    0.568     1.30  0.465     
 3 rurality_quintile3           0.858    0.571     1.29  0.462     
 4 rurality_quintile4           0.708    0.469     1.07  0.0988    
 5 svi_2022_per_0_1             0.956    0.893     1.02  0.194     
 6 rurality_quintile1           0.770    0.434     1.37  0.373     
 7 rurality_quintile2           0.782    0.500     1.22  0.280     
 8 rurality_quintile3           0.821    0.551     1.22  0.330     
 9 rurality_quintile4           0.688    0.444     1.06  0.0929    
10 svi_2022_per_0_1             0.939    0.857     1.03  0.173     
11 rurality_quintile1           0.880    0.520     1.49  0.633     
12 rurality_quintile2           0.978    0.630     1.52  0.922     
13 rurality_quintile3           0.942    0.671     1.32  0.731     
14 rurality_quintile4           0.753    0.516     1.10  0.143     
15 svi_2022_per_0_1             0.957    0.875     1.05  0.340     
16 medicaid_expansion_active    1.65     1.28      2.13  0.000111  
17 rurality_quintile1           0.982    0.540     1.78  0.953     
18 rurality_quintile2           1.08     0.657     1.78  0.761     
19 rurality_quintile3           1.02     0.703     1.48  0.916     
20 rurality_quintile4           0.826    0.539     1.26  0.379     
21 svi_2022_per_0_1             0.964    0.879     1.06  0.440     
22 medicaid_expansion_active    1.64     1.28      2.10  0.0000900 
23 cvd_physicians_per_100k_2023 1.02     0.968     1.08  0.458     
24 rurality_quintile1           0.788    0.462     1.34  0.382     
25 rurality_quintile2           0.922    0.603     1.41  0.708     
26 rurality_quintile3           0.720    0.502     1.03  0.0746    
27 rurality_quintile4           0.776    0.520     1.16  0.214     
28 svi_2022_per_0_1             0.868    0.784     0.960 0.00613   
29 medicaid_expansion_active    1.71     1.37      2.14  0.00000299
30 cvd_physicians_per_100k_2023 0.992    0.956     1.03  0.647     
31 rurality_quintile1           1.02     0.634     1.63  0.944     
32 rurality_quintile2           1.08     0.731     1.60  0.696     
33 rurality_quintile3           0.839    0.610     1.15  0.279     
34 rurality_quintile4           0.893    0.640     1.25  0.504     
35 svi_2022_per_0_1             0.898    0.806     1.00  0.0494    
36 medicaid_expansion_active    1.53     1.18      1.98  0.00122   
37 cvd_physicians_per_100k_2023 1.00     0.967     1.04  0.815     
   se_type             
   <chr>               
 1 cluster_robust_state
 2 cluster_robust_state
 3 cluster_robust_state
 4 cluster_robust_state
 5 cluster_robust_state
 6 cluster_robust_state
 7 cluster_robust_state
 8 cluster_robust_state
 9 cluster_robust_state
10 cluster_robust_state
11 cluster_robust_state
12 cluster_robust_state
13 cluster_robust_state
14 cluster_robust_state
15 cluster_robust_state
16 cluster_robust_state
17 cluster_robust_state
18 cluster_robust_state
19 cluster_robust_state
20 cluster_robust_state
21 cluster_robust_state
22 cluster_robust_state
23 cluster_robust_state
24 cluster_robust_state
25 cluster_robust_state
26 cluster_robust_state
27 cluster_robust_state
28 cluster_robust_state
29 cluster_robust_state
30 cluster_robust_state
31 cluster_robust_state
32 cluster_robust_state
33 cluster_robust_state
34 cluster_robust_state
35 cluster_robust_state
36 cluster_robust_state
37 cluster_robust_state
```
