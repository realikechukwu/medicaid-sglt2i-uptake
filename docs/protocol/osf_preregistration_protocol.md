# State-Level Rurality, Deprivation, and Medicaid Uptake of SGLT2 Inhibitors After Expansion of Heart Failure and Kidney Disease Indications in the United States

## Metadata

### Title

**State-Level Rurality, Deprivation, and Medicaid Uptake of SGLT2 Inhibitors After Expansion of Heart Failure and Kidney Disease Indications in the United States**

### Description

SGLT2 inhibitors reduce cardiovascular and renal events in patients with heart failure, chronic kidney disease, and diabetes, but uptake may vary across U.S. Medicaid programmes. This study will examine whether state-level rurality and socioeconomic deprivation are associated with Medicaid SGLT2 inhibitor prescribing after expansion of SGLT2 inhibitor indications into heart failure and kidney disease. We will conduct a repeated state-quarter ecological analysis of Medicaid State Drug Utilization Data from 2015 to 2025. Quarterly SGLT2 inhibitor prescription counts will be modelled using negative binomial regression, with Medicaid enrolment included as an offset. State-level rurality, social vulnerability, Medicaid expansion status, physician density, cardiometabolic disease burden, and Census region/division will be included as covariates.

### Contributors

To be completed in OSF.

### Suggested license

CC-By Attribution 4.0 International.

### Suggested subjects

- Medicine and Health Sciences
- Cardiology
- Endocrinology
- Nephrology
- Epidemiology
- Public Health
- Health Services Research
- Health Policy
- Pharmacoepidemiology

### Suggested tags

```text
SGLT2 inhibitors
Medicaid
rurality
social vulnerability
deprivation
heart failure
chronic kidney disease
diabetes
Medicaid expansion
state drug utilization data
health disparities
pharmacoepidemiology
```

---

# Overview

## Research questions or hypotheses

### Primary research question

Are state-level rurality and socioeconomic deprivation associated with lower Medicaid SGLT2 inhibitor prescribing after expansion of SGLT2 inhibitor indications into heart failure and kidney disease in the United States?

### Secondary research questions

1. What are the national and state-level patterns of Medicaid SGLT2 inhibitor prescribing from 2015 to 2025?

2. Do Medicaid SGLT2 inhibitor prescribing rates differ across RUCC-derived rurality quintiles?

3. Is state-level social vulnerability associated with Medicaid SGLT2 inhibitor prescribing after adjustment for rurality?

4. Is Medicaid expansion status associated with Medicaid SGLT2 inhibitor prescribing?

5. Are associations between rurality, social vulnerability, and SGLT2 inhibitor prescribing robust after adjustment for physician density, cardiometabolic disease burden, and Census region/division?

6. Are findings consistent when the outcome is restricted to single-agent SGLT2 inhibitors and, separately, to empagliflozin/dapagliflozin?

### Hypotheses

1. More rural states will have lower Medicaid SGLT2 inhibitor prescribing rates than more urban states.

2. States with higher social vulnerability will have lower Medicaid SGLT2 inhibitor prescribing rates.

3. Medicaid expansion status will be associated with higher Medicaid SGLT2 inhibitor prescribing rates.

4. Associations between rurality/deprivation and prescribing will persist, although may be attenuated, after adjustment for Medicaid expansion status, physician density, cardiometabolic disease burden, and Census region/division.

## Foreknowledge of data or evidence

This study will use existing publicly available administrative and population-level datasets. The analysis plan should be interpreted in the context of using pre-existing data.

Suggested OSF selection should be made truthfully at submission according to the authors' actual data access and analysis status at the time of registration.

## Explanation of foreknowledge and managing unintended influences

This protocol specifies the planned data sources, inclusion criteria, variable construction, primary model, covariates, and sensitivity analyses before formal manuscript preparation. Because the study uses existing public datasets, the authors will distinguish planned analyses described in this protocol from any subsequent exploratory or post hoc analyses in reporting.

---

# Research Design

## Study type

Non-randomized study.

This is an observational, repeated state-quarter ecological analysis using public administrative datasets.

Additional descriptors:

- Adjustment or control-based design
- Descriptive study
- Pharmacoepidemiologic drug utilization study
- Health services research study

## Intention for causal interpretation

This study is intended to estimate state-level associations, not to establish individual-level or causal effects.

The analysis will assess whether state-level rurality, social vulnerability, and Medicaid expansion status are associated with Medicaid SGLT2 inhibitor prescribing rates. Because states are not randomly assigned to rurality, deprivation, or Medicaid expansion status, estimates will be interpreted as ecological associations rather than causal effects.

## Blinding of experimental treatments

Not applicable. This is not an experimental study.

## Additional blinding during research or analysis

No blinding procedures are planned. The study uses publicly available administrative and population-level datasets.

## Study design

We will conduct a repeated state-quarter ecological analysis of Medicaid State Drug Utilization Data from 2015 to 2025. The unit of analysis will be the state-quarter. Analyses will be restricted to the 50 U.S. states and the District of Columbia.

The year 2020 will be excluded because the available source contains only quarter 4 data. Puerto Rico, territories, unknown/non-state reporting codes, national totals, and other non-state reporting rows will be excluded.

SGLT2 inhibitor prescriptions will be identified using an FDA NDC-derived lookup table for canagliflozin, dapagliflozin, empagliflozin, ertugliflozin, bexagliflozin, and sotagliflozin, including fixed-dose combination products. Fee-for-service and managed care records will be combined within state-quarter strata.

Quarterly prescribing rates will be calculated as prescriptions per 10,000 Medicaid beneficiaries using the mean monthly Medicaid enrolment within each state-quarter. Regression models will use the quarterly number of SGLT2 inhibitor prescriptions as the outcome, with log average Medicaid enrolment included as an offset.

## Randomization

Not applicable. No randomization will be used.

---

# Sampling

## Data collection procedures

This study will use existing public datasets and derived state-level analysis files.

### Medicaid State Drug Utilization Data

Annual Medicaid State Drug Utilization Data files from 2015 to 2025 will be used to identify Medicaid-reimbursed prescription claims for SGLT2 inhibitors. Variables used will include state, year, quarter, utilization type, NDC, product name, units reimbursed, number of prescriptions, and reimbursement amounts.

Fee-for-service utilization and managed care organization utilization records will be combined to capture total Medicaid-reimbursed prescribing within each state-quarter.

### FDA NDC Directory

FDA NDC Directory product and package files will be used to construct an SGLT2 inhibitor NDC lookup table. Product-level records will be searched for SGLT2 inhibitor active ingredients and linked to package-level NDCs. Package NDCs will be converted to 11-digit NDC format and linked to SDUD NDCs.

### Medicaid enrolment

Monthly Medicaid enrolment data from CMS Data.Medicaid.gov will be used to construct state-quarter denominators. The denominator will use total Medicaid enrolment. For each state-quarter, monthly enrolment counts will be averaged to estimate the average Medicaid enrolment during that quarter.

### Rurality

Rurality will be derived from the 2023 USDA Rural-Urban Continuum Codes. Counties with RUCC codes 1–3 will be classified as metropolitan and counties with RUCC codes 4–9 as nonmetropolitan. State rurality will be measured as the proportion of the state population living in nonmetropolitan counties.

### Social vulnerability

Socioeconomic deprivation/social vulnerability will be measured using the CDC/ATSDR Social Vulnerability Index. State-level SVI will be calculated as the population-weighted mean of county-level overall SVI values within each state. The 2022 SVI estimate will be used as the primary structural deprivation measure.

### Physician density

Physician density will be obtained from 2023 HRSA Area Health Resources Files dashboard exports. The main physician density covariate will be cardiovascular disease physicians per 100,000 population. Total physician density and primary care physician density may be used in sensitivity or descriptive analyses.

### Cardiometabolic disease burden

State-level disease burden will be proxied using 2023 CMS Mapping Medicare Disparities prevalence estimates among Medicare fee-for-service beneficiaries. Covariates will include heart failure/non-ischaemic heart disease prevalence, diabetes prevalence, and chronic kidney disease prevalence. These will be used as state-level disease burden proxies rather than Medicaid-specific disease prevalence estimates.

### Medicaid expansion

Medicaid expansion status will be derived from a state-level expansion file containing expansion status and expansion effective dates. Expansion status will be coded as time-varying at the state-quarter level.

### Census region/division

Census region/division will be assigned using the standard U.S. Census state classification. Census region/division will be used to account for broad geographic differences in Medicaid policy, healthcare delivery, and prescribing patterns.

## Sample size

The planned analytic sample will include state-quarter observations for the 50 U.S. states and the District of Columbia.

The study period will include:

```text
2015 Q1-Q4
2016 Q1-Q4
2017 Q1-Q4
2018 Q1-Q4
2019 Q1-Q4
2021 Q1-Q4
2022 Q1-Q4
2023 Q1-Q4
2024 Q1-Q4
2025 Q1-Q2 or all available 2025 quarters with complete denominator data
```

The final number of observations will depend on availability of complete Medicaid enrolment denominators for 2025. The expected unit count is approximately 51 jurisdictions multiplied by the included quarters.

## Sample size rationale

The sample size is determined by the number of eligible state-quarter observations available in public administrative datasets. No formal power calculation will be performed. The analysis will use all eligible state-quarter observations meeting prespecified inclusion criteria.

## Starting and stopping rules

No new data will be collected. Data collection will consist of downloading, cleaning, and linking the prespecified public datasets. The final dataset will include all eligible observations from the prespecified study period with valid state, year, quarter, SGLT2 prescribing data or zero prescribing after linkage, and valid Medicaid enrolment denominator.

---

# Variables

## Manipulated variables

None.

## Measured variables

### Primary outcome

The primary outcome will be the quarterly number of Medicaid-reimbursed SGLT2 inhibitor prescriptions in each state-quarter.

### Descriptive outcome

Quarterly SGLT2 inhibitor prescribing rate:

```text
SGLT2 prescriptions per 10,000 Medicaid beneficiaries
```

### Sensitivity outcomes

1. Quarterly number of single-agent SGLT2 inhibitor prescriptions.
2. Quarterly number of empagliflozin/dapagliflozin prescriptions.

### Primary exposure

State rurality, categorised into quintiles based on a RUCC-derived measure:

```text
Q1 = most rural
Q5 = most urban
```

The most urban quintile will be used as the reference group.

### Secondary exposure

State-level socioeconomic deprivation/social vulnerability, measured using state-level SVI.

### Covariates

Time-varying covariate:

- Medicaid expansion status.

Time-invariant state-level covariates:

- Census region/division.
- Cardiovascular disease physician density.
- Medicare FFS heart failure/non-ischaemic heart disease prevalence.
- Medicare FFS diabetes prevalence.
- Medicare FFS chronic kidney disease prevalence.

Time variables:

- Year.
- Quarter.

Denominator:

- Average Medicaid enrolment within each state-quarter.

## Indices

### SGLT2 prescribing rate

```text
SGLT2 prescribing rate =
quarterly SGLT2 prescriptions / average Medicaid enrolment within state-quarter × 10,000
```

### Rurality index

County RUCC codes will be used to define metropolitan and nonmetropolitan counties:

```text
Metro counties = RUCC 1–3
Nonmetro counties = RUCC 4–9
```

State rurality will be calculated as:

```text
Nonmetro population share =
population living in nonmetro counties / total state population
```

States will be divided into quintiles based on nonmetro population share:

```text
Q1 = highest nonmetro population share, most rural
Q5 = lowest nonmetro population share, most urban
```

### SVI index

State-level SVI will be calculated as the population-weighted mean of county-level SVI values:

```text
State SVI =
sum(county SVI × county population) / sum(county population)
```

SVI will be scaled per 0.1 increase in regression models:

```text
SVI per 0.1 increase = SVI / 0.1
```

### Continuous rurality sensitivity variable

For sensitivity analysis, rurality will be modelled continuously:

```text
Nonmetro population share per 10 percentage points =
nonmetro population share / 0.10
```

---

# Analysis Plan

## Statistical models

Associations between rurality, deprivation, and SGLT2 inhibitor prescribing will be assessed using negative binomial regression at the state-quarter level. The outcome will be the quarterly number of SGLT2 inhibitor prescriptions, with log average Medicaid enrolment in the corresponding state-quarter included as an offset. This will allow estimates to be interpreted as prescribing rate ratios.

### Main model sequence

#### Descriptive analyses

We will first describe:

1. National quarterly SGLT2 inhibitor prescribing rates over time.
2. State-level variation in mean and median prescribing rates.
3. Prescribing trends by rurality quintile.
4. Prescribing trends by SVI quintile.

#### Model 1: rurality and time

```text
SGLT2 prescriptions ~ rurality quintile + year + quarter + offset(log Medicaid enrolment)
```

The most urban rurality quintile will be the reference group.

#### Model 2: social vulnerability and time

```text
SGLT2 prescriptions ~ SVI per 0.1 increase + year + quarter + offset(log Medicaid enrolment)
```

#### Model 3: rurality, social vulnerability, and time

```text
SGLT2 prescriptions ~ rurality quintile + SVI per 0.1 increase + year + quarter + offset(log Medicaid enrolment)
```

#### Model 4: add Medicaid expansion

```text
SGLT2 prescriptions ~ rurality quintile + SVI per 0.1 increase + Medicaid expansion status + year + quarter + offset(log Medicaid enrolment)
```

#### Model 5: add physician density

```text
SGLT2 prescriptions ~ rurality quintile + SVI per 0.1 increase + Medicaid expansion status + CVD physicians per 100,000 + year + quarter + offset(log Medicaid enrolment)
```

#### Model 6: fully adjusted model

```text
SGLT2 prescriptions ~ rurality quintile + SVI per 0.1 increase + Medicaid expansion status + CVD physicians per 100,000 + Medicare FFS HF/IHD prevalence + Medicare FFS diabetes prevalence + Medicare FFS CKD prevalence + year + quarter + offset(log Medicaid enrolment)
```

#### Model 7: region-adjusted sensitivity model

```text
SGLT2 prescriptions ~ rurality quintile + SVI per 0.1 increase + Medicaid expansion status + Census region + CVD physicians per 100,000 + Medicare FFS HF/IHD prevalence + Medicare FFS diabetes prevalence + Medicare FFS CKD prevalence + year + quarter + offset(log Medicaid enrolment)
```

### Sensitivity analyses

Sensitivity analyses will include:

1. Repeating the fully adjusted model after restricting the outcome to single-agent SGLT2 inhibitors.

2. Repeating the fully adjusted model after restricting the outcome to empagliflozin and dapagliflozin only.

3. Modelling rurality continuously per 10 percentage-point increase in nonmetro population share.

4. Restricting the analysis to complete years through 2024.

5. Adding Census region/division to assess whether findings are robust to broad geographic adjustment.

6. If needed, replacing CVD physician density with primary care physician density or total physician density.

### Standard errors

State-clustered robust standard errors will be used to account for repeated quarterly observations within states.

### Model diagnostics

We will assess:

- Model convergence.
- Overdispersion using a Poisson comparison model.
- Negative binomial model fit.
- Missingness in key variables.
- Sensitivity of estimates to alternative outcome definitions and region adjustment.

## Transformations

- Rurality quintile will be treated as a categorical variable, with Q5, the most urban quintile, as reference.
- SVI will be scaled per 0.1 increase.
- Continuous rurality will be scaled per 10 percentage-point increase in nonmetro population share.
- Year and quarter will be modelled as categorical variables.
- Medicaid expansion will be coded as binary and time-varying.
- Disease prevalence variables will be retained as percentage values and interpreted per percentage-point unless rescaled for reporting.
- Medicaid enrolment will be log-transformed for use as an offset.

## Inference criteria

We will report incidence rate ratios, 95% confidence intervals, and two-sided p-values. A two-sided p-value below 0.05 will be considered statistically significant. Interpretation will prioritise effect sizes, confidence intervals, direction and consistency of associations across models, and robustness in sensitivity analyses.

Because the study is ecological and observational, findings will not be interpreted as causal.

## Data inclusion and exclusion

Included observations:

- State-quarter observations from the 50 U.S. states and the District of Columbia.
- Years 2015-2019 and 2021-2025.
- Observations with positive, non-missing Medicaid enrolment.

Excluded observations:

- Year 2020.
- Puerto Rico.
- Territories.
- Unknown/non-state reporting codes such as XX.
- National totals and other non-state reporting units.
- Observations with missing or non-positive Medicaid enrolment.
- Duplicate state-year-quarter rows, if identified.

No outliers will be excluded automatically. Implausible values will be reviewed and any exclusion will be documented.

## Missing data

State-quarters with valid Medicaid enrolment but no matching SGLT2 SDUD records will be treated as zero prescribing. Missing Medicaid enrolment will not be imputed. Missing covariates will not be zero-filled. Regression models will use complete observations for the covariates included in each model.

## Other planned analysis

Additional descriptive outputs will include:

- National quarterly prescribing trend plots.
- Rurality quintile trend plots.
- SVI quintile trend plots.
- State-level summary tables.
- Forest plots of adjusted incidence rate ratios.
- Sensitivity outcome comparison plots.

---

# Other

## Context and additional information

SGLT2 inhibitors were initially used as glucose-lowering therapies but have become central therapies for heart failure and chronic kidney disease. Their expanded indications raise important questions about equitable uptake across Medicaid programmes. This study will evaluate state-level patterns in Medicaid SGLT2 inhibitor prescribing and examine whether rurality, social vulnerability, Medicaid expansion, physician density, disease burden, and region are associated with uptake.

The study is ecological and uses aggregate state-level data. Findings will therefore be interpreted as state-level associations and not as individual-level treatment effects.
