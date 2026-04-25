# State-Level Medicaid SGLT2 Inhibitor Uptake Project

This folder contains an R-based workflow to extract sodium-glucose cotransporter-2 inhibitor (SGLT2i) utilization from U.S. Medicaid State Drug Utilization Data (SDUD), convert it into state-quarter prescribing outcomes, and create Medicaid enrolment-normalized rate files for downstream ecological panel analysis.

The intended analysis is a state-level study of SGLT2i uptake in Medicaid, with particular interest in rurality, socioeconomic deprivation, heart failure burden, cardiologist density, Medicaid expansion, and related state-level access covariates.

## Current Bottom Line

The current primary analysis-ready file is:

```text
data_processed/sglt2_state_quarter_rates_all_products_50dc_excluding_2020.csv
```

This file contains quarterly SGLT2i prescription counts and rates per 10,000 Medicaid enrollees for the 50 U.S. states plus DC. It excludes 2020 because the available 2020 SDUD extract contains only Q4. It also excludes PR and XX because they are not part of the 50-state/DC analytic sample. The denominator file currently supports 2015-2019, 2021-2024, and 2025 Q1-Q2. Therefore, the current quarterly rate file has 1,938 data rows: 51 jurisdictions times 38 quarters.

Use this as the main outcome file unless you are rebuilding the extraction pipeline from raw SDUD files.

## Research Aim

The project aims to quantify state-quarter Medicaid SGLT2i prescribing from 2015 to 2025 using a reproducible NDC-based approach. The primary outcome is the SDUD variable `Number of Prescriptions`, aggregated to state-quarter level.

The preferred rate expression is:

```text
SGLT2i prescriptions per 10,000 Medicaid beneficiaries =
  quarterly SGLT2i prescriptions / average quarterly Medicaid enrolment * 10,000
```

For regression modelling, the likely main model is a count model:

```text
Outcome: SGLT2i prescription count
Offset: log(Medicaid enrolment)
Model: negative binomial panel regression
Interpretation: adjusted incidence rate ratio for SGLT2i prescribing rate
```

## Folder Map

```text
.
|-- R-analysis.Rproj
|-- README.md
|-- data_raw/
|   |-- product.txt
|   |-- package.txt
|   `-- medicaid_enrolment/
|       `-- medicaid-enrollment-new-adult-group-02052026.csv
|-- data_processed/
|   |-- sglt2_ndc_11_digit_list.csv
|   |-- sdud_sglt2_row_level_2015_2025.csv
|   |-- sglt2_state_quarter_all_products_2015_2025.csv
|   |-- sglt2_state_quarter_rates_all_products_50dc_excluding_2020.csv
|   |-- sglt2_state_quarter_rates_single_agent_50dc_excluding_2020.csv
|   |-- sglt2_state_quarter_rates_empa_dapa_50dc_excluding_2020.csv
|   |-- sglt2_state_year_rates_all_products_50dc_excluding_2020.csv
|   `-- check_*.csv
|-- docs/
|   |-- analysis.txt
|   |-- protocol.txt
|   |-- medicaid_enrolment_and_rate_construction.md
|   `-- sglt2-medicaid-research-protocol.pdf
|-- scripts/
|   |-- 01_import_inspect.R
|   |-- 02_extract_sglt2_from_sdud.R
|   |-- 03_multiyear_sdud_join.R
|   |-- 03_create_state_quarter_rates.R
|   `-- 03_create_state_year_rates.R
|-- figures/
`-- output/
```

Important current-state note: processed SDUD outputs are present in `data_processed/`, but `data_raw/sdud/` is not currently present in this working folder. To rerun the all-year SDUD extraction from scratch, recreate `data_raw/sdud/` and add the annual SDUD CSV files there.

Expected SDUD raw files from the prior extraction notes were:

```text
data_raw/sdud/StateDrugUtilizationData-2015.csv
data_raw/sdud/StateDrugUtilizationData-2016.csv
data_raw/sdud/StateDrugUtilizationData-2017.csv
data_raw/sdud/StateDrugUtilizationData-2018.csv
data_raw/sdud/StateDrugUtilizationData-2019.csv
data_raw/sdud/sdud-2020-updated.csv
data_raw/sdud/sdud-2021-updated.csv
data_raw/sdud/sdud-2022-updated.csv
data_raw/sdud/sdud-2023-updated.csv
data_raw/sdud/sdud-2024-updated.csv
data_raw/sdud/sdud-2025-updated.csv
```

## Data Sources

### FDA NDC Directory

These source files are in `data_raw/`:

```text
data_raw/product.txt
data_raw/package.txt
```

`product.txt` is used to identify SGLT2i products by generic and proprietary names. `package.txt` is joined to the product file to obtain package-level NDC codes.

The output lookup table is:

```text
data_processed/sglt2_ndc_11_digit_list.csv
```

### Medicaid SDUD

Annual Medicaid SDUD CSVs were used to extract SGLT2i records from 2015 to 2025. SDUD columns were standardized to lowercase snake-case names during the DuckDB extraction. Both fee-for-service (`FFSU`) and managed care (`MCOU`) records were retained and summed in the main outcome.

The main extracted row-level file is:

```text
data_processed/sdud_sglt2_row_level_2015_2025.csv
```

### Medicaid Enrolment Denominator

The Medicaid denominator comes from CMS Data.Medicaid.gov, "Medicaid Enrollment - New Adult Group":

```text
data_raw/medicaid_enrolment/medicaid-enrollment-new-adult-group-02052026.csv
```

Despite the source title, the denominator used here is `Total Medicaid Enrollees`, not the VIII/new adult group enrolment column. Quarterly denominators are calculated as the mean of monthly total Medicaid enrolment within each state-quarter.

Clean denominator outputs:

```text
data_processed/medicaid_enrolment_state_quarter.csv
data_processed/medicaid_enrolment_state_year.csv
```

The February 2026 CMS file includes complete data for 2015-2019 and 2021-2024, and January-June 2025. Current quarterly rate outputs therefore include 2025 Q1-Q2 only.

## SGLT2i Identification Strategy

SGLT2i products were identified from the FDA product file using generic and brand search terms.

Generic terms:

```text
canagliflozin
dapagliflozin
empagliflozin
ertugliflozin
bexagliflozin
sotagliflozin
```

Brand and combination-product terms include:

```text
Invokana
Invokamet
Farxiga
Xigduo
Jardiance
Synjardy
Glyxambi
Trijardy
Steglatro
Segluromet
Steglujan
Brenzavvy
Inziq
Qtern
```

Each FDA product is tagged to a parent SGLT2i drug:

```text
canagliflozin
dapagliflozin
empagliflozin
ertugliflozin
bexagliflozin
sotagliflozin
```

Combination products are retained in the primary outcome and tagged using `combination_product`. Single-agent-only outputs are available for sensitivity analyses because combination products may more strongly reflect diabetes-directed prescribing than heart failure or CKD-directed uptake.

## NDC Conversion

FDA package NDCs appear in hyphenated formats. SDUD uses 11-digit NDCs. The project converts FDA package NDCs into standard 11-digit 5-4-2 format:

```text
4-4-2 -> add leading zero to labeler segment
5-3-2 -> add leading zero to product segment
5-4-1 -> add leading zero to package segment
```

Examples:

```text
82381-2174-1 -> 82381217401
51407-918-30 -> 51407091830
50458-140-01 -> 50458014001
50090-5034-1 -> 50090503401
```

The SDUD join key is:

```text
SDUD NDC = FDA-derived ndc_11
```

## Workflow Scripts

Run scripts from the RStudio project root.

### 1. Build the SGLT2i NDC lookup

```r
source("scripts/01_import_inspect.R")
```

Inputs:

```text
data_raw/product.txt
data_raw/package.txt
```

Outputs:

```text
data_processed/sglt2_products_found.csv
data_processed/sglt2_ndc_11_digit_list.csv
data_processed/sglt2_ndc_11_digit_list.rds
```

### 2. Extract all-year SGLT2i SDUD records

```r
source("scripts/03_multiyear_sdud_join.R")
```

This is the main SDUD extraction script. It uses DuckDB so the full SDUD CSVs do not need to be loaded into R memory all at once.

Inputs:

```text
data_raw/sdud/*.csv
data_processed/sglt2_ndc_11_digit_list.csv
```

Outputs:

```text
data_processed/sdud_sglt2_row_level_2015_2025.csv
data_processed/sglt2_state_quarter_all_products_2015_2025.csv
data_processed/sglt2_state_quarter_single_agent_2015_2025.csv
data_processed/sglt2_state_quarter_empa_dapa_2015_2025.csv
data_processed/sglt2_state_quarter_by_product_type_2015_2025.csv
data_processed/sglt2_state_quarter_by_drug_2015_2025.csv
data_processed/sglt2_national_quarterly_2015_2025.csv
data_processed/check_sglt2_rows_by_year.csv
data_processed/check_sglt2_rows_by_drug.csv
data_processed/check_sglt2_by_utilization_type.csv
```

`scripts/02_extract_sglt2_from_sdud.R` appears to be an earlier single-year exploratory script for 2025. Prefer `03_multiyear_sdud_join.R` for the reproducible all-year extraction.

### 3. Create state-quarter rate files

```r
source("scripts/03_create_state_quarter_rates.R")
```

This is the main rate-construction script. It filters to 50 states plus DC, excludes 2020, merges Medicaid enrolment denominators, fills absent state-quarter SGLT2i records as zero utilization where denominator data exist, and writes all-products and sensitivity rate files.

Main output:

```text
data_processed/sglt2_state_quarter_rates_all_products_50dc_excluding_2020.csv
```

Sensitivity outputs:

```text
data_processed/sglt2_state_quarter_rates_single_agent_50dc_excluding_2020.csv
data_processed/sglt2_state_quarter_rates_empa_dapa_50dc_excluding_2020.csv
data_processed/sglt2_national_quarterly_rates_50dc_excluding_2020.csv
```

### 4. Create secondary state-year rate files

```r
source("scripts/03_create_state_year_rates.R")
```

These are useful for descriptive summaries, but the primary modelling unit is state-quarter.

Outputs:

```text
data_processed/sglt2_state_year_all_products_50dc_excluding_2020.csv
data_processed/sglt2_state_year_rates_all_products_50dc_excluding_2020.csv
data_processed/sglt2_state_year_rates_single_agent_50dc_excluding_2020.csv
data_processed/sglt2_state_year_rates_empa_dapa_50dc_excluding_2020.csv
data_processed/sglt2_national_yearly_rates_50dc_excluding_2020.csv
```

## Main Output Columns

The primary state-quarter rate file contains:

```text
state
year
quarter
sglt2_prescriptions
sglt2_units
sglt2_medicaid_reimbursed
sglt2_total_reimbursed
n_rows
n_ndcs
medicaid_enrolment_quarter_avg
medicaid_enrolment
n_enrolment_months
sglt2_prescriptions_per_10000
sglt2_units_per_10000
sglt2_medicaid_reimbursed_per_10000
sglt2_reimbursement_per_prescription
```

Use `sglt2_prescriptions` as the primary count outcome and `medicaid_enrolment` as the denominator or model offset.

## Key Checks Already Performed

The all-year extraction produced the following row and prescription counts:

```text
2015: 3,663 rows; 616,515 prescriptions
2016: 5,068 rows; 1,163,118 prescriptions
2017: 6,339 rows; 1,635,355 prescriptions
2018: 7,733 rows; 1,940,670 prescriptions
2019: 9,200 rows; 2,380,267 prescriptions
2020: 2,550 rows; 898,960 prescriptions
2021: 10,759 rows; 4,649,351 prescriptions
2022: 11,375 rows; 6,349,754 prescriptions
2023: 11,827 rows; 8,078,822 prescriptions
2024: 12,874 rows; 8,973,157 prescriptions
2025: 12,346 rows; 9,463,396 prescriptions
```

The extraction includes both utilization types:

```text
FFSU: 41,569 rows; 16,659,839 prescriptions
MCOU: 52,165 rows; 29,489,526 prescriptions
```

National quarterly SGLT2i prescribing rates increased from about 6 prescriptions per 10,000 Medicaid enrollees in 2015 Q1 to about 138 prescriptions per 10,000 Medicaid enrollees in 2025 Q2 in the current 50-state/DC rate file.

## Known Caveats

### 2020 is incomplete

The available 2020 SDUD extract contains only Q4. Therefore, 2020 is excluded from the primary rate and modelling files. Keep the raw 2015-2025 extraction for transparency, but do not treat 2020 as a complete calendar year unless a complete 2020 SDUD file is obtained and the extraction is rerun.

Suggested methods language:

```text
The 2020 SDUD extract available for analysis contained only Q4 data; therefore, 2020 was excluded from primary state-quarter modelling to avoid incomplete calendar-year ascertainment.
```

### PR and XX are excluded from the main analytic sample

The full SDUD extracts include reporting codes outside the 50 states plus DC, including `PR` and `XX`. The rate-construction scripts restrict the main analytic sample to `state.abb` plus `DC`.

Suggested methods language:

```text
Analyses were restricted to the 50 U.S. states and the District of Columbia. Puerto Rico and non-state aggregate or unknown reporting records coded as XX were excluded because key state-level covariates were not consistently available or interpretable for these reporting areas.
```

### 2025 denominator coverage is partial

The current CMS enrolment denominator includes monthly data through June 2025. Quarterly rate outputs include 2025 Q1 and Q2 only. 2025 Q3 and Q4 should be added only after denominator data are available.

### Reimbursement variables are gross amounts

`Medicaid Amount Reimbursed` and `Total Amount Reimbursed` are gross pharmacy reimbursement variables and do not account for manufacturer rebates. They are useful for secondary cost-oriented summaries, but they are not the primary uptake outcome.

## Planned Main and Sensitivity Analyses

Main analysis:

```text
All SGLT2i-containing products
FFSU + MCOU combined
50 states + DC only
State-quarter unit of analysis
Exclude 2020
Use Medicaid enrolment as denominator or model offset
```

Sensitivity analyses:

```text
Single-agent SGLT2i products only
Empagliflozin and dapagliflozin only
Exclude 2021 as an additional COVID/transitional-indication sensitivity check
Consider pre/post HF and CKD indication expansion interaction terms
```

## Still To Do

1. Decide whether to redownload or reconstruct a complete 2020 SDUD file. If not, keep excluding 2020.
2. Add state-level covariates for rurality, deprivation, Medicaid expansion, disease burden, provider density, and region.
3. Create a final modelling dataset by merging those covariates into the state-quarter rate file.
4. Run descriptive national and state-level trend plots.
5. Fit negative binomial panel models using `sglt2_prescriptions` as the outcome and `log(medicaid_enrolment)` as the offset.
6. Run sensitivity analyses using the single-agent and empagliflozin/dapagliflozin files.
7. Save final model tables and figures in `output/` and `figures/`.

Potential covariates to merge:

```text
state rurality
state socioeconomic deprivation or SVI
heart failure prevalence
diabetes prevalence
CKD prevalence
cardiologist density
primary care physician density
Medicaid expansion status
Census region or division
state demographic composition
```

## Draft Methods Paragraph

We used Medicaid State Drug Utilization Data (SDUD) to quantify quarterly state-level SGLT2 inhibitor utilization. Annual SDUD CSV files from 2015 to 2025 were processed using a package-level NDC lookup table derived from the FDA NDC Directory product and package files. Products were identified using generic and proprietary names for canagliflozin, dapagliflozin, empagliflozin, ertugliflozin, bexagliflozin, and sotagliflozin, including fixed-dose combination products. FDA package NDCs were converted to the standard 11-digit 5-4-2 claims format and joined to SDUD records using the SDUD NDC field. Fee-for-service and managed care utilization records were combined within state-quarter strata. The primary outcome was the number of Medicaid-reimbursed SGLT2 inhibitor prescriptions per state-quarter. Quarterly prescribing rates were calculated per 10,000 Medicaid enrollees using average monthly total Medicaid enrolment within each state-quarter. Combination products were retained in the primary analysis and excluded in sensitivity analyses. Analyses were restricted to the 50 U.S. states and the District of Columbia; Puerto Rico and non-state aggregate or unknown records coded as XX were excluded. The 2020 SDUD extract available for analysis contained only Q4 data and was excluded from primary modelling.

## Useful Reference Docs

Read these when restarting the project:

```text
docs/analysis.txt
docs/medicaid_enrolment_and_rate_construction.md
docs/protocol.txt
docs/sglt2-medicaid-research-protocol.pdf
```

`docs/analysis.txt` contains the detailed extraction narrative. `docs/medicaid_enrolment_and_rate_construction.md` explains the denominator and rate construction. `docs/protocol.txt` and the PDF describe the scientific rationale and planned ecological panel study.
