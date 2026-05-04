# Covariate construction report and limitations

## Purpose

This document describes construction of the state-year covariate dataset used for the Medicaid SDUD SGLT2 inhibitor uptake study. State-year covariates are merged to state-quarter prescribing-rate outcomes by `state` and `year`.

## Analysis years and jurisdiction restrictions

- Analysis years: 2015-2019 and 2021-2025.
- Excluded year: 2020, because the available SDUD source currently contains only Q4.
- Jurisdictions: 50 U.S. states plus the District of Columbia.
- Excluded reporting areas: PR, XX, territories, national totals, and unknown rows.
- Expected state-year grid: 51 jurisdictions x 10 years = 510 rows.

## Sources attempted

- KFF Medicaid Expansion Tracker: https://www.kff.org/medicaid/status-of-state-medicaid-expansion-decisions/
- U.S. Census region/division stable state lookup.
- USDA ERS Rural-Urban Continuum Codes 2023: https://www.ers.usda.gov/data-products/rural-urban-continuum-codes/
- CDC/ATSDR SVI data downloads: https://svi.cdc.gov/dataDownloads/data-download.html
- CDC PLACES county data via Data.CDC.gov Socrata endpoints: https://www.cdc.gov/places/
- CMS Medicare Chronic Conditions / Chronic Conditions Warehouse state-level chronic condition data.
- HRSA Area Health Resources Files: https://data.hrsa.gov/data/download/

## Sources successfully used

- Medicaid expansion: manually coded CSV created at `data_raw/covariates/medicaid_expansion_status.csv`, based on the KFF tracker. Mid-year dates should be manually confirmed before final manuscript submission.
- Census region/division: internal stable lookup in `scripts/04_build_state_year_covariates.R`.
- Rurality: USDA ERS RUCC 2023 county data downloaded to `data_raw/covariates/Ruralurbancontinuumcodes2023.csv`.
- SVI: CDC/ATSDR county SVI CSVs for 2014, 2016, 2018, 2020, and 2022 downloaded to `data_raw/covariates/`.
- Diabetes and CKD: CDC PLACES county data queried from Data.CDC.gov endpoints and saved as filtered raw files in `data_raw/covariates/`.
- Heart failure: no confirmed programmatic state-year file was identified; a manual input template was created.
- Workforce density: no confirmed AHRF field mapping was available locally; a manual input template and expected-field diagnostic were created.

## Source-specific construction details

### Medicaid expansion construction

Source URL: https://www.kff.org/medicaid/status-of-state-medicaid-expansion-decisions/

The script creates or reads `data_raw/covariates/medicaid_expansion_status.csv` with columns `state`, `expansion_adopted`, `expansion_effective_date`, and `notes`. The default covariate is `medicaid_expansion_status`, defined as `medicaid_expansion_status_any_year`: 1 if expansion was active for any month in the calendar year, 0 otherwise. The script also creates `medicaid_expansion_status_full_year`, defined as 1 only if expansion was active on January 1 of the year.

Missing `medicaid_expansion_effective_date` values are expected for states that had not adopted ACA Medicaid expansion by the analysis period.

### Census region/division construction

Census region and division are stable state-level classifications and are manually coded inside the script. They are time-invariant across all analysis years.

### Rurality construction

Source URL: https://www.ers.usda.gov/data-products/rural-urban-continuum-codes/

The script downloads USDA ERS RUCC 2023 county-level data. The primary `rurality_measure` is the percentage of each state's 2020 county population living in nonmetro counties, defined as RUCC codes 4-9. The measure is treated as time-invariant for 2015-2019 and 2021-2025. Additional columns include population-weighted mean RUCC and unweighted mean RUCC.

### SVI construction

Source URL: https://svi.cdc.gov/dataDownloads/data-download.html

The script downloads county-level CDC/ATSDR SVI files for 2014, 2016, 2018, 2020, and 2022. State-level SVI is calculated as a population-weighted mean of county `RPL_THEMES`, using county `E_TOTPOP` as the weight. Each analysis year is matched to the nearest available SVI source year; ties use the earlier source year because source years are sorted before matching. `svi_source_year` records the matched source year.

### Diabetes prevalence construction

Source URL: https://www.cdc.gov/places/

The script queries CDC PLACES county data endpoints for rows with `measureid == DIABETES`. State-level prevalence is calculated as a population-weighted mean of county crude prevalence estimates. The preferred weight is `totalpop18plus`; if unavailable, `totalpopulation` is used. Each analysis year is matched to the nearest available PLACES source year.

### CKD prevalence construction

Source URL: https://www.cdc.gov/places/

The script queries CDC PLACES county data endpoints for rows with `measureid == KIDNEY`. State-level prevalence is calculated using the same method as diabetes. Current PLACES releases may not include CKD, so later analysis years may use the nearest earlier PLACES source year. This is documented in `ckd_prevalence_source` and related source-year columns.

### Heart failure prevalence construction

Preferred source: CMS Medicare Chronic Conditions / Chronic Conditions Warehouse state-level chronic condition data.

No clean, confidently identified state-year heart failure prevalence file was available in the project at construction time. The script creates the expected manual input file `data_raw/covariates/medicare_chronic_conditions_state_year.csv`. Until that file is populated and verified, `hf_prevalence` remains missing. This covariate should be interpreted as Medicare heart failure prevalence, not Medicaid-specific or all-adult prevalence.

### Cardiologist and physician density construction

Preferred source: HRSA Area Health Resources Files (AHRF), https://data.hrsa.gov/data/download/

No local AHRF file and technical documentation were available with confidently identified cardiologist, primary care physician, and population fields. The script creates the expected manual input file `data_raw/covariates/ahrf_state_year_workforce.csv` and writes `data_processed/ahrf_expected_manual_columns.csv`. Until populated and verified, `cardiologists_per_100k` and `primary_care_physicians_per_100k` remain missing.

## Missingness summary

- cardiologists_per_100k: 510 missing (100%); years: 2015;2016;2017;2018;2019;2021;2022;2023;2024;2025; states: AK;AL;AR;AZ;CA;CO;CT;DC;DE;FL;GA;HI;IA;ID;IL;IN;KS;KY;LA;MA;MD;ME;MI;MN;MO;MS;MT;NC;ND;NE;NH;NJ;NM;NV;NY;OH;OK;OR;PA;RI;SC;SD;TN;TX;UT;VA;VT;WA;WI;WV;WY
- hf_prevalence: 510 missing (100%); years: 2015;2016;2017;2018;2019;2021;2022;2023;2024;2025; states: AK;AL;AR;AZ;CA;CO;CT;DC;DE;FL;GA;HI;IA;ID;IL;IN;KS;KY;LA;MA;MD;ME;MI;MN;MO;MS;MT;NC;ND;NE;NH;NJ;NM;NV;NY;OH;OK;OR;PA;RI;SC;SD;TN;TX;UT;VA;VT;WA;WI;WV;WY
- primary_care_physicians_per_100k: 510 missing (100%); years: 2015;2016;2017;2018;2019;2021;2022;2023;2024;2025; states: AK;AL;AR;AZ;CA;CO;CT;DC;DE;FL;GA;HI;IA;ID;IL;IN;KS;KY;LA;MA;MD;ME;MI;MN;MO;MS;MT;NC;ND;NE;NH;NJ;NM;NV;NY;OH;OK;OR;PA;RI;SC;SD;TN;TX;UT;VA;VT;WA;WI;WV;WY
- medicaid_expansion_effective_date: 100 missing (19.6%); years: 2015;2016;2017;2018;2019;2021;2022;2023;2024;2025; states: AL;FL;GA;KS;MS;SC;TN;TX;WI;WY
- diabetes_prevalence: 9 missing (1.8%); years: 2019;2021;2022;2023;2024;2025; states: FL;KY;NJ;PA
- ckd_prevalence: 6 missing (1.2%); years: 2019;2021;2022;2023;2024;2025; states: FL;NJ
- cardiologist_density_source: 0 missing (0%); years: None; states: None
- census_division: 0 missing (0%); years: None; states: None
- census_region: 0 missing (0%); years: None; states: None
- ckd_prevalence_source: 0 missing (0%); years: None; states: None
- diabetes_prevalence_source: 0 missing (0%); years: None; states: None
- hf_prevalence_source: 0 missing (0%); years: None; states: None
- medicaid_expansion_status: 0 missing (0%); years: None; states: None
- physician_density_source: 0 missing (0%); years: None; states: None
- rurality_measure: 0 missing (0%); years: None; states: None
- rurality_measure_source: 0 missing (0%); years: None; states: None
- svi_source_year: 0 missing (0%); years: None; states: None
- svi_state: 0 missing (0%); years: None; states: None

## Diagnostics generated

- data_processed/svi_state_aggregates_by_source_year.csv
- data_processed/places_state_aggregates_diabetes_ckd_by_source_year.csv
- data_processed/ahrf_expected_manual_columns.csv

## Limitations

- Medicaid expansion dates, especially mid-year implementations and Maine retroactivity, should be manually confirmed before final modelling.
- SVI is not annual, so nearest-year matching is used.
- SVI and PLACES county aggregation is population-weighted when population fields are available, but still collapses within-state heterogeneity into a state-level measure.
- PLACES estimates are model-based small-area estimates and should not be interpreted as direct survey estimates.
- CKD may not be available in the newest PLACES releases, so later years may use older nearest-source values.
- Medicare HF prevalence is a proxy for state HF burden and may not reflect Medicaid-specific HF burden.
- Workforce density requires careful AHRF field identification; values are left missing until fields are confirmed.
- Some covariates are time-invariant or nearest-year values, while the outcome is quarterly.
- State-level covariates cannot capture within-state rurality, deprivation, disease burden, or physician-supply gradients.
- 2020 is excluded because SDUD was incomplete in the available source.
- 2025 enrolment is currently available only through Q2 in the denominator source used for the SGLT2 rate files.

## Residual issues for manual review

- Heart failure prevalence is missing because no confirmed CMS Medicare Chronic Conditions state-year source file has been supplied.
- Cardiologist density is missing because no confirmed AHRF workforce input has been supplied.
- Primary care/physician density is missing because no confirmed AHRF workforce input has been supplied.

## Recommended sensitivity analyses

- Repeat main models using single-agent SGLT2 inhibitor products only.
- Repeat main models using empagliflozin/dapagliflozin only.
- Exclude 2021 to assess sensitivity to COVID-era disruption and transitional uptake after HF/CKD indication expansion.
- Compare any-year versus full-year Medicaid expansion status for mid-year expansion states.
- Refit models after replacing proxy or nearest-year covariates with confirmed annual state-year sources if those become available.

