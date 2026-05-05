# Analysis-Ready Tables

This folder contains the clean CSVs to use for modelling, descriptive analysis, and figures. These are convenience copies of files generated in `data_processed/`; the scripts still write their full outputs to `data_processed/`.

## Main Table

Use this as the primary state-quarter analysis dataset:

```text
sglt2_state_quarter_rates_all_products_50dc_excluding_2020.csv
```

It contains all SGLT2 inhibitor-containing products, combines FFSU and MCOU utilization, restricts to the 50 U.S. states plus DC, excludes incomplete 2020 data, and includes Medicaid enrolment denominators and prescription rates per 10,000 Medicaid enrollees.

## Sensitivity Tables

```text
sglt2_state_quarter_rates_single_agent_50dc_excluding_2020.csv
sglt2_state_quarter_rates_empa_dapa_50dc_excluding_2020.csv
```

Use the single-agent file to exclude fixed-dose combination products. Use the empagliflozin/dapagliflozin file for the sensitivity analysis focused on the two dominant SGLT2 inhibitors most relevant to heart failure and CKD indication expansion.

## National Summary

```text
sglt2_national_quarterly_rates_50dc_excluding_2020.csv
```

This is a national quarterly trend summary aggregated across the 50 states plus DC. It is useful for descriptive plots and sanity checks, but the main modelling unit remains state-quarter.

## Rebuilding

To regenerate these files from scratch, run:

```r
source("scripts/03_create_state_quarter_rates.R")
```

The script writes the full generated outputs to `data_processed/` and refreshes these four analysis-ready copies automatically.
