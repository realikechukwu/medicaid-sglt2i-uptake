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
