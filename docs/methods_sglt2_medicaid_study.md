# Methods

## Study design and unit of analysis

We will conduct a repeated state-quarter ecological analysis of Medicaid SGLT2 inhibitor prescribing in the United States. The unit of analysis will be the state-quarter. Analyses will be restricted to the 50 U.S. states and the District of Columbia.

The study period will include 2015-2019 and 2021-2025. The year 2020 will be excluded because the available State Drug Utilization Data source contained only quarter 4 data, preventing complete quarterly ascertainment for that year. Puerto Rico, unknown/non-state reporting rows, territories, national totals, and other non-state reporting units will be excluded.

## Data sources

The primary prescribing outcome will be derived from Medicaid State Drug Utilization Data (SDUD), using annual SDUD files from 2015 to 2025. SGLT2 inhibitor products will be identified using a lookup table derived from the FDA National Drug Code (NDC) Directory product and package files. Medicaid enrolment denominators will be obtained from the CMS Data.Medicaid.gov MBES Medicaid enrolment file, using total Medicaid enrolment.

State-level covariates will be derived from the following sources:

- USDA Rural-Urban Continuum Codes (RUCC), 2023, for rurality.
- CDC/ATSDR Social Vulnerability Index (SVI), 2022, for social vulnerability.
- HRSA Area Health Resources Files (AHRF), 2023, for physician density.
- CMS Mapping Medicare Disparities, 2023, for Medicare fee-for-service disease burden measures.
- A manually curated Medicaid expansion status file, using expansion effective dates, for time-varying Medicaid expansion status.
- U.S. Census region/division lookup, if included in sensitivity analysis, for broad geographic adjustment.

## SGLT2 inhibitor identification

SGLT2 inhibitor prescriptions will be identified by linking SDUD NDCs to an FDA NDC-derived SGLT2 inhibitor lookup table. The lookup table will include canagliflozin, dapagliflozin, empagliflozin, ertugliflozin, bexagliflozin, and sotagliflozin. Fixed-dose combination products containing an SGLT2 inhibitor will be included in the primary outcome.

FDA product and package files will be joined using product-level identifiers. Package-level NDCs will be converted to 11-digit NDC format and matched to the SDUD NDC field. The resulting SGLT2 lookup table will include the parent SGLT2 inhibitor, product names, package NDC, 11-digit NDC, and a flag identifying fixed-dose combination products.

Fee-for-service utilization and managed care organization utilization records will be combined within each state-quarter to capture total Medicaid-reimbursed SGLT2 inhibitor prescribing.

## Outcome

The primary outcome will be the quarterly number of Medicaid-reimbursed SGLT2 inhibitor prescriptions in each state-quarter. This will be modelled as a count outcome.

For descriptive analyses, prescribing will also be expressed as prescriptions per 10,000 Medicaid beneficiaries per quarter:

```text
SGLT2 prescriptions per 10,000 Medicaid beneficiaries =
quarterly SGLT2 prescriptions / average quarterly Medicaid enrolment × 10,000
```

Secondary descriptive measures will include SGLT2 units reimbursed, Medicaid amount reimbursed, total amount reimbursed, and reimbursement per prescription.

The primary analysis will include all SGLT2 inhibitor-containing products. Sensitivity analyses will repeat the fully adjusted model after restricting the outcome to single-agent SGLT2 inhibitors and, separately, to empagliflozin/dapagliflozin only.

## Medicaid enrolment denominator

Medicaid enrolment denominators will be constructed from monthly CMS MBES Medicaid enrolment data. The denominator will use the `Total Medicaid Enrollees` field, not the VIII/new adult group enrolment fields.

For each state-quarter, the denominator will be calculated as the mean of the monthly total Medicaid enrolment counts within that quarter:

- Quarter 1: mean of January, February, and March enrolment.
- Quarter 2: mean of April, May, and June enrolment.
- Quarter 3: mean of July, August, and September enrolment.
- Quarter 4: mean of October, November, and December enrolment.

This approach treats monthly enrolment values as monthly enrolment snapshots and avoids summing monthly enrolment counts across months, which would count the same enrolled beneficiaries repeatedly.

## Main exposures

### Rurality

The primary rurality exposure will be derived from the 2023 USDA Rural-Urban Continuum Codes. Counties with RUCC codes 1-3 will be classified as metropolitan, and counties with RUCC codes 4-9 will be classified as nonmetropolitan.

For each state, rurality will be measured as the proportion of the 2020 state population living in nonmetropolitan counties:

```text
Nonmetropolitan population share =
population living in RUCC 4-9 counties / total state population
```

States will then be grouped into quintiles based on nonmetropolitan population share. Quintile 1 will represent the most rural states, with the highest nonmetropolitan population share, and quintile 5 will represent the most urban states, with the lowest nonmetropolitan population share. Quintile 5 will be used as the reference group in regression models.

A sensitivity analysis will model rurality continuously per 10 percentage-point increase in nonmetropolitan population share.

### Social vulnerability

State-level social vulnerability will be measured using the 2022 CDC/ATSDR Social Vulnerability Index. The state-level SVI variable will be calculated as the population-weighted average of county-level overall SVI scores within each state. Higher values indicate greater social vulnerability.

In regression models, SVI will be scaled per 0.1 increase to improve interpretability:

```text
SVI per 0.1 increase = SVI / 0.1
```

## Covariates

### Medicaid expansion status

Medicaid expansion status will be treated as a time-varying policy covariate. For each state-quarter, expansion status will be coded as active if Medicaid expansion was in effect at the start of the quarter. A supplementary variable will also identify whether expansion was active for any part of the quarter.

### Physician density

Physician density will be derived from 2023 HRSA AHRF dashboard exports. The main physician access covariate will be cardiovascular disease physicians per 100,000 population. Primary care physician density and total physician density may be used in sensitivity analyses.

Physician density measures will be treated as time-invariant structural access covariates.

### Disease burden

State-level cardiometabolic disease burden will be proxied using 2023 CMS Mapping Medicare Disparities prevalence estimates among Medicare fee-for-service beneficiaries. Disease burden covariates will include:

- Medicare FFS heart failure/non-ischaemic heart disease prevalence.
- Medicare FFS diabetes prevalence.
- Medicare FFS chronic kidney disease prevalence.

These variables will be treated as time-invariant state-level disease burden proxies. They will not be interpreted as Medicaid-specific disease prevalence. The HF/IHD variable will be labelled as heart failure/non-ischaemic heart disease burden rather than pure heart failure prevalence.

### Census region

A sensitivity model may adjust for Census region to account for broad geographic differences in Medicaid policy, health system structure, prescribing culture, and state-level population characteristics. Census region will be coded using the standard U.S. Census Bureau four-region classification: Northeast, Midwest, South, and West.

## Statistical analysis

Descriptive analyses will summarise national quarterly SGLT2 inhibitor prescribing trends, state-level prescribing variation, prescribing by rurality quintile, and prescribing by SVI quintile. Trends will be presented as prescriptions per 10,000 Medicaid beneficiaries.

The primary modelling approach will use negative binomial regression because the outcome is a count and prescription counts are expected to be overdispersed. The outcome will be the quarterly number of SGLT2 inhibitor prescriptions. The natural log of average quarterly Medicaid enrolment will be included as an offset, allowing model coefficients to be interpreted as prescribing rate ratios.

The main model sequence will be staged:

1. Time trend only.
2. Rurality quintile adjusted for year and quarter.
3. SVI adjusted for year and quarter.
4. Rurality and SVI adjusted for year and quarter.
5. Rurality, SVI, and Medicaid expansion adjusted for year and quarter.
6. Rurality, SVI, Medicaid expansion, and cardiovascular physician density adjusted for year and quarter.
7. Fully adjusted model including rurality, SVI, Medicaid expansion, cardiovascular physician density, Medicare FFS HF/IHD prevalence, diabetes prevalence, CKD prevalence, year, and quarter.
8. Region-adjusted sensitivity model, if Census region is added.

Year and quarter fixed effects will be included to adjust for secular trends and seasonal/quarterly variation. Standard errors will be clustered by state to account for repeated quarterly observations within states.

Results will be reported as incidence rate ratios, interpreted as SGLT2 prescribing rate ratios. An IRR below 1.0 indicates lower prescribing relative to the reference group or per unit increase in a covariate, while an IRR above 1.0 indicates higher prescribing.

## Sensitivity analyses

Sensitivity analyses will include:

1. Repeating the fully adjusted model using single-agent SGLT2 inhibitor prescriptions only.
2. Repeating the fully adjusted model using empagliflozin/dapagliflozin prescriptions only.
3. Modelling rurality continuously per 10 percentage-point increase in nonmetropolitan population share.
4. Restricting the analysis to complete years through 2024.
5. Adding Census region to assess whether findings are robust to broad geographic adjustment.
6. Considering primary care physician density or total physician density in place of cardiovascular physician density, if needed.

## Data validation and quality checks

The analytic dataset will be checked to confirm that each state-quarter appears once, that 2020 is excluded, and that PR, XX, territories, and non-state reporting rows are absent. State counts per year-quarter will be checked to confirm 51 jurisdictions where expected. Medicaid enrolment will be required to be non-missing and positive.

State-quarters with valid Medicaid enrolment but missing SGLT2 prescribing values after joining will be treated as zero prescribing if no matching SGLT2 SDUD records were present. Missing Medicaid enrolment or missing covariates will not be zero-filled.

NDC lookup completeness will be assessed by checking included SGLT2 drugs, single-agent and fixed-dose combination products, distinct NDC counts by drug, and duplicate NDCs. Descriptive checks will examine national trends, top and bottom prescribing states, units per prescription, and reimbursement per prescription to identify implausible outliers.

## Limitations

This is a state-level ecological analysis and cannot infer individual-level prescribing or patient-level access. The outcome reflects prescription claim volume, not unique treated beneficiaries. The denominator is total Medicaid enrolment, not the number of Medicaid beneficiaries eligible for SGLT2 inhibitor therapy.

Several covariates are measured using recent public-source snapshots and treated as time-invariant structural characteristics, including RUCC rurality, SVI, physician density, and disease burden. These variables should be interpreted as proxies for between-state structural differences rather than precise year-specific exposures.

Disease burden measures are derived from Medicare fee-for-service data and may not represent Medicaid-specific disease prevalence. Medicaid expansion status is not randomly assigned and may reflect broader differences in Medicaid generosity, state policy, health system capacity, and prescribing culture. State-level SVI and rurality measures may mask important within-state variation.
