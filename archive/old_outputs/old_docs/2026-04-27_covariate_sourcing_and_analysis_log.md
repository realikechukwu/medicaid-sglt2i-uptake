# Research Activity Log: Covariate Sourcing and Analysis Decisions

**Date:** 27 April 2026  
**Project:** Medicaid SDUD SGLT2 inhibitor uptake analysis  
**Working project folder:** `/Users/ikechukwuchukwudi/Documents/Academic/IMT-ACF Folder/Papers - Active/r-analysis-sglt2`  
**Log location intended in project:** `/docs/2026-04-27_covariate_sourcing_and_analysis_log.md`

---

## 1. Purpose of this log

This document summarises the work completed so far to construct the covariate dataset for the Medicaid SDUD SGLT2 inhibitor uptake project. It records the data sources identified, files downloaded or generated, folder locations used, cleaning decisions made, and the current analysis plan.

The main research question is whether state-level rurality and socioeconomic deprivation were associated with lower Medicaid uptake of SGLT2 inhibitors after the expansion of SGLT2 inhibitor indications into heart failure and chronic kidney disease.

---

## 2. Current primary outcome dataset

The primary prescribing outcome has already been derived from Medicaid State Drug Utilization Data (SDUD), using FDA NDC-derived SGLT2 inhibitor lookup tables.

The main current outcome file is:

```text
for_analysis/sglt2_state_quarter_rates_all_products_50dc_excluding_2020.csv
```

This file contains state-quarter SGLT2 inhibitor prescribing rates for:

```text
50 U.S. states + District of Columbia
2015–2019 and 2021–2025
2020 excluded
PR and XX excluded
```

The primary unit of analysis is the **state-quarter**.

The main rate is:

```text
SGLT2i prescriptions per 10,000 Medicaid beneficiaries per quarter
```

The denominator is average monthly Medicaid enrolment within the corresponding state-quarter.

Formula:

```text
Quarterly SGLT2i prescribing rate =
quarterly SGLT2i prescriptions / average monthly Medicaid enrolment within state-quarter × 10,000
```

Fee-for-service utilisation (`FFSU`) and managed care organisation utilisation (`MCOU`) were already combined in the processed SDUD state-quarter files.

---

## 3. Key analytic exclusions

### 3.1 Exclusion of 2020

The downloaded 2020 SDUD file only contained data for quarter 4. Because quarters 1–3 were absent, 2020 was excluded from the main analysis to avoid incomplete calendar-year ascertainment.

The included years are:

```text
2015, 2016, 2017, 2018, 2019, 2021, 2022, 2023, 2024, 2025
```

### 3.2 Exclusion of PR and XX

The SDUD-derived outputs initially included non-state reporting codes:

```text
PR = Puerto Rico
XX = unknown / non-state / aggregate reporting code
```

For the primary state-level analysis, the analytic dataset was restricted to:

```text
50 U.S. states + District of Columbia
```

Puerto Rico, XX, territories, national totals, and non-state reporting areas are excluded from the main analysis because the planned state-level covariates are not consistently available or interpretable for those units.

---

## 4. Folder structure and key file locations

The project uses the following folders.

### 4.1 Raw data folders

```text
data_raw/
data_raw/sdud/
data_raw/medicaid_enrolment/
data_raw/covariates/
data_raw/covariates/downloaded_cv/
```

`data_raw/sdud/` contains annual SDUD CSV files.

`data_raw/medicaid_enrolment/` contains the CMS Medicaid enrolment file.

`data_raw/covariates/downloaded_cv/` contains AHRF dashboard Excel files downloaded for physician workforce measures.

### 4.2 Analysis-ready / working covariate folder

```text
for_analysis/
for_analysis/covariates/
```

This folder currently contains cleaned or manually downloaded analysis covariate files, including:

```text
for_analysis/ahrf_physician_density_2023_50dc.csv
for_analysis/mmd_disease_burden_2023_50dc.csv
for_analysis/sglt2_state_quarter_rates_all_products_50dc_excluding_2020.csv
```

`for_analysis/covariates/` contains downloaded CMS Mapping Medicare Disparities disease burden CSVs:

```text
for_analysis/covariates/mmd_data_hf_ihd.csv
for_analysis/covariates/mmd_data_dm.csv
for_analysis/covariates/mmd_data_ckd.csv
```

### 4.3 Documentation folder

This log should be saved in:

```text
docs/2026-04-27_covariate_sourcing_and_analysis_log.md
```

---

## 5. Medicaid enrolment denominator

### Source

CMS Data.Medicaid.gov MBES source:

```text
Medicaid Enrollment - New Adult Group
```

Direct file used:

```text
data_raw/medicaid_enrolment/medicaid-enrollment-new-adult-group-02052026.csv
```

Although the dataset title refers to the “New Adult Group”, the file includes total Medicaid enrolment. The denominator used is:

```text
Total Medicaid Enrollees
```

The VIII/new adult group columns are not used for the main denominator.

### Construction

The file reports monthly counts of unduplicated individuals enrolled in each state Medicaid programme during the month.

For each state-quarter, the denominator is calculated as the mean of the three monthly total Medicaid enrolment counts in that quarter:

```text
Q1 = mean(January, February, March)
Q2 = mean(April, May, June)
Q3 = mean(July, August, September)
Q4 = mean(October, November, December)
```

This avoids summing monthly enrolment counts, which would count the same enrolled beneficiaries repeatedly across months. The resulting denominator represents average Medicaid enrolment during the quarter.

### Cleaned output

The quarterly enrolment file is:

```text
data_processed/medicaid_enrolment_state_quarter.csv
```

A state-year file also exists:

```text
data_processed/medicaid_enrolment_state_year.csv
```

The quarterly denominator is preferred for the primary analysis because the SDUD prescribing outcome is naturally quarterly.

---

## 6. Physician workforce covariates

### Source

HRSA Area Health Resources Files (AHRF) dashboard exports were downloaded as Excel files.

Raw downloaded files are stored in:

```text
data_raw/covariates/downloaded_cv/
```

Files present:

```text
AHRFDashboard.xlsx
AHRFDashboard (1).xlsx
AHRFDashboard (2).xlsx
```

The three AHRF files correspond to:

```text
M.D., All M.D.
M.D., Primary Care
M.D., Cardiovascular Disease
```

Each file includes:

```text
State/Territory
Physician count
Population, All (County Level File)
Rate per 100,000 population
Source
```

### Cleaning decision

An R script was created to read the Excel files, identify the physician type, extract the state-level table, and merge them into one wide table. AHRF file parsing required skipping the metadata rows and using the `AHRF Geo Data` worksheet.

A technical issue occurred because `population` was initially matched too broadly and also captured the rate column `rate_per_100_000_population`. This was fixed by matching column names that start with `population` and `rate`.

### Cleaned output

The cleaned physician density file is:

```text
for_analysis/ahrf_physician_density_2023_50dc.csv
```

It contains 51 rows, one per state/DC, with columns including:

```text
state
state_name
population
number_physicians
physicians_per_100k
physicians_per_100k_calculated
number_primary_care_physicians
primary_care_physicians_per_100k
primary_care_physicians_per_100k_calculated
number_cvd_physicians
cvd_physicians_per_100k
cvd_physicians_per_100k_calculated
cvd_physicians_source
primary_care_physicians_source
physicians_source
```

The calculated rates closely matched the AHRF-provided rates, with only negligible rounding differences.

### Analysis decision

Physician workforce covariates will be treated as **time-invariant 2023 state-level structural access covariates**.

Main candidate physician access covariates:

```text
cvd_physicians_per_100k
primary_care_physicians_per_100k
physicians_per_100k
```

Because these measures are likely correlated, the preferred approach is not to include all physician density variables in the same primary model. The current plan is to use cardiovascular disease physician density as the main specialist-access covariate and explore primary care or total physician density in sensitivity models.

---

## 7. Disease burden covariates

### Source

CMS Mapping Medicare Disparities by Population tool:

```text
https://data.cms.gov/tools/mapping-medicare-disparities-by-population
```

The downloaded files are in:

```text
for_analysis/covariates/
```

Files:

```text
mmd_data_hf_ihd.csv
mmd_data_dm.csv
mmd_data_ckd.csv
```

These represent:

```text
Heart Failure and Non-Ischemic Heart Disease
Diabetes
Chronic Kidney Disease
```

The selected settings used in the CMS tool were:

```text
Population: Medicare FFS only
Year: 2023
Geography: State/Territory
Measure: Prevalence
Adjustment: Unsmoothed age-sex adjusted
Analysis: Within State/Territory
Domain: Primary chronic conditions
Sex: All
Age: All
Race and Ethnicity: All
Dual Eligible: Dual & non-dual
Medicare Eligibility: All
```

### Important interpretation

The `primary_value` column is the prevalence percentage.

The `primary_denominator` field sometimes shows:

```text
10,000+
```

This does not mean the prevalence is per 10,000. It is a denominator size category indicating that the denominator population was at least 10,000 Medicare FFS beneficiaries.

### Cleaning decision

The CMS MMD disease burden files were cleaned into a wide file with one row per state/DC.

An initial coding issue occurred because the CMS file used a column called `state` for full state names, while the state crosswalk also used `state` for abbreviations. This was fixed by using `state_abbr` in the crosswalk before renaming the final output column to `state`.

A second issue occurred when attempting to dynamically create disease-specific column names inside the cleaning helper function. This was simplified by first creating a generic `value` column and then explicitly renaming it after each file was cleaned.

### Cleaned output

The cleaned disease burden file is:

```text
for_analysis/mmd_disease_burden_2023_50dc.csv
```

It includes:

```text
state
source_year
medicare_ffs_hf_ihd_prevalence_2023
medicare_ffs_diabetes_prevalence_2023
medicare_ffs_ckd_prevalence_2023
disease_burden_source
disease_burden_measure
disease_burden_population
```

### Analysis decision

Disease burden covariates will be treated as **time-invariant 2023 state-level disease burden proxies**.

The current decision is to use the CMS MMD disease burden variables together rather than mixing CMS heart failure burden with PLACES diabetes/CKD estimates. This improves internal consistency because HF/IHD, diabetes, and CKD are all drawn from the same source, year, population, and adjustment method.

However, these are Medicare FFS-based estimates, not Medicaid-specific prevalence estimates. They will be described as proxies for broader state-level disease burden among older/Medicare FFS beneficiaries.

Recommended variable naming in analysis:

```text
medicare_ffs_hf_ihd_prevalence_2023
medicare_ffs_diabetes_prevalence_2023
medicare_ffs_ckd_prevalence_2023
```

The HF variable should not be described simply as HF prevalence because the CMS condition is:

```text
Heart Failure and Non-Ischemic Heart Disease
```

Preferred manuscript wording:

```text
Medicare FFS heart failure/non-ischaemic heart disease prevalence
```

or:

```text
Medicare FFS HF/IHD burden
```

---

## 8. SVI covariate

### Source

CDC/ATSDR Social Vulnerability Index.

Files currently available include:

```text
SVI_2022_US_county.csv
svi_state_aggregates_by_source_year.csv
```

Current uploaded/generated state aggregate file:

```text
svi_state_aggregates_by_source_year.csv
```

This file includes state-level SVI aggregate values by source year, with 51 states/DC available for source years:

```text
2014, 2016, 2018, 2020, 2022
```

### Analysis decision

For the current primary analysis, SVI will be treated as a **time-invariant structural deprivation/social vulnerability covariate**, using the latest available SVI source year:

```text
SVI 2022
```

This choice is pragmatic and aligns with the use of 2022/2023 snapshots for other structural covariates. It also avoids mixing nearest-year estimates into a quarterly prescribing model unless needed.

Possible sensitivity analysis:

```text
Use nearest available SVI source year for each analysis year
```

For example:

```text
2015 → 2014 or 2016 SVI
2016–2017 → 2016 SVI
2018–2019 → 2018 SVI
2021 → 2020 SVI
2022–2025 → 2022 SVI
```

But the current preferred main model uses 2022 SVI as a fixed state-level structural covariate.

---

## 9. Rurality / RUCC covariate

### Source

USDA Rural-Urban Continuum Codes.

File available:

```text
Ruralurbancontinuumcodes2023.csv
```

Current location:

```text
for_analysis/
```

or uploaded into the working covariate data folder depending on the local project copy.

### Analysis decision

Rurality will be based on 2023 RUCC-derived state-level rurality. It will be treated as a **time-invariant structural rurality measure**.

The planned rurality exposure will be based on the percentage of people living in non-metropolitan areas or a RUCC-derived state-level rurality measure.

The current preferred primary exposure is:

```text
rurality quintile
```

defined such that:

```text
Quintile 1 = most rural
Quintile 5 = most urban
```

This improves interpretability compared with a purely continuous rurality measure.

The most urban quintile, Q5, should be the reference category in regression models. This allows the main IRR interpretation to be:

```text
Prescribing rate in more rural states compared with the most urban states
```

Example interpretation:

```text
IRR for Q1 vs Q5 = SGLT2i prescribing rate in the most rural states compared with the most urban states
```

### Planned sensitivity analysis

A continuous rurality measure should also be tested, for example:

```text
per 10 percentage-point increase in non-metropolitan population share
```

This will check whether results are robust to categorisation.

### Note on quintiles

Because there are only 51 jurisdictions, each rurality quintile contains around 10 states. This is acceptable, but estimates may become less precise if the model includes many correlated state-level covariates. Rurality is likely correlated with region, deprivation, Medicaid expansion status, disease burden, and physician density. Staged models are therefore preferred.

---

## 10. Medicaid expansion status

### Source

A Medicaid expansion status file is available:

```text
medicaid_expansion_status.csv
```

Current location:

```text
for_analysis/
```

or equivalent local covariate folder.

### Analysis decision

Medicaid expansion status will be treated as a **time-varying policy covariate**.

This differs from the structural covariates because Medicaid expansion changed during the study period and directly affects Medicaid eligibility, enrolment, and access to covered prescriptions.

The preferred construction is:

```text
medicaid_expansion_active = 1 if expansion was active in the state-quarter
medicaid_expansion_active = 0 otherwise
```

If exact quarterly coding is not available, state-year coding may be used with a clear rule:

```text
expansion active in any part of the year
```

or:

```text
expansion active for the full year
```

Quarterly coding is preferred because the main outcome is state-quarter.

---

## 11. Current modelling plan

### Primary dataset

The main modelling dataset should be based on:

```text
for_analysis/sglt2_state_quarter_rates_all_products_50dc_excluding_2020.csv
```

and merged with covariates from:

```text
for_analysis/ahrf_physician_density_2023_50dc.csv
for_analysis/mmd_disease_burden_2023_50dc.csv
svi_state_aggregates_by_source_year.csv
Ruralurbancontinuumcodes2023.csv
medicaid_expansion_status.csv
```

### Primary outcome

```text
Quarterly SGLT2i prescriptions per 10,000 Medicaid beneficiaries
```

For regression, the preferred approach remains count-based:

```text
Outcome: quarterly SGLT2i prescription count
Offset: log(quarterly Medicaid enrolment)
Model: negative binomial regression
```

The rate variable is useful for description, figures, and intuitive interpretation, but the model can use prescription counts with enrolment as an offset.

### Primary exposure

```text
RUCC-derived rurality quintile
```

coded:

```text
Q1 = most rural
Q5 = most urban
```

Reference group:

```text
Q5, most urban
```

### Key covariates

Time-varying:

```text
Medicaid expansion status
time period / year / quarter
```

Time-invariant structural covariates:

```text
2023 RUCC-derived rurality
2022 SVI
2023 AHRF physician density
2023 CMS MMD HF/IHD, diabetes, CKD burden
Census region/division
```

### Suggested staged model strategy

Model 1:

```text
rurality quintile + time
```

Model 2:

```text
rurality quintile + time + Medicaid expansion + Census region/division + SVI
```

Model 3:

```text
Model 2 + disease burden + physician density
```

This staged approach helps avoid overpacking the model and allows assessment of whether rurality associations are attenuated by deprivation, region, disease burden, or workforce access.

---

## 12. Sensitivity analyses

Planned sensitivity analyses include:

```text
1. Single-agent SGLT2 inhibitors only
2. Empagliflozin + dapagliflozin only
3. Excluding 2025, or restricting to complete years through 2024
4. Using rurality as a continuous variable rather than quintiles
5. Using nearest-year SVI rather than fixed 2022 SVI, if easily implementable
6. Testing primary care physician density or total physician density instead of cardiovascular disease physician density
```

---

## 13. Important limitations to document

### 13.1 Time-invariant covariates

Several covariates are measured using recent snapshots and applied across the 2015–2025 outcome period. This may introduce temporal mismatch.

This applies to:

```text
2023 RUCC/rurality
2022 SVI
2023 AHRF physician density
2023 CMS MMD disease burden
```

These should be interpreted as proxies for broad between-state structural differences, not exact year-specific exposures.

### 13.2 Medicare FFS disease burden

CMS MMD disease burden measures are based on Medicare FFS beneficiaries, not Medicaid beneficiaries. They are used as state-level disease burden proxies and may not directly represent disease prevalence among Medicaid beneficiaries.

### 13.3 HF/IHD condition definition

The CMS MMD condition is:

```text
Heart Failure and Non-Ischemic Heart Disease
```

This is not a pure heart failure prevalence measure. The variable should be labelled accordingly.

### 13.4 RUCC/rurality at state level

RUCC is county-based. Any state-level rurality measure derived from RUCC involves aggregation. State-level rurality may mask major within-state rural/urban differences.

### 13.5 Ecological design

The analysis is state-level and cannot infer individual-level prescribing probability or patient-level access. Findings should be interpreted as state-level associations.

### 13.6 2020 exclusion

2020 is excluded because the available SDUD file only contains Q4. This may remove an important transition year during the COVID-19 period and during evolving SGLT2i indications.

### 13.7 2025 partial data

The current quarterly rate file appears to include 2025 Q1–Q2 only, likely reflecting available enrolment denominator data. This is acceptable for quarterly analysis if denominators are complete for included quarters, but a sensitivity analysis through 2024 only is recommended.

---

## 14. Current final decision for analysis using available data

The current agreed analysis plan is:

```text
Use state-quarter as the primary unit of analysis.
Use all SGLT2 inhibitor-containing products as the primary outcome.
Use single-agent and empagliflozin/dapagliflozin datasets for sensitivity analyses.
Exclude 2020.
Restrict to 50 states + DC.
Exclude PR and XX.
Use quarterly Medicaid enrolment denominators.
Use RUCC-derived rurality quintiles as the primary rurality exposure.
Code rurality quintiles so Q1 = most rural and Q5 = most urban.
Use Q5 as the rurality reference group.
Treat Medicaid expansion as time-varying.
Treat SVI, RUCC/rurality, physician density, and disease burden as time-invariant structural covariates using 2022/2023 source data.
Use CMS MMD disease burden variables together rather than mixing CMS HF burden with PLACES diabetes/CKD.
Use staged models to avoid overadjustment and to assess attenuation.
```

---

## 15. Next steps

Immediate next steps:

```text
1. Finalise state-level RUCC-derived rurality variable and create rurality quintiles.
2. Merge AHRF physician density, CMS MMD disease burden, SVI 2022, RUCC 2023, and Medicaid expansion status into the quarterly SGLT2 rate file.
3. Create a clean modelling dataset without source/provenance text columns.
4. Keep a separate audit/provenance dataset with source columns.
5. Run descriptive summaries by year-quarter and rurality quintile.
6. Fit negative binomial regression models with Medicaid enrolment as offset.
7. Run sensitivity analyses.
8. Update the methods document with the exact covariate construction code and final variable names.
```
