# Medicaid SDUD SGLT2 Inhibitor Uptake Study

This R project builds a reproducible state-quarter analysis of Medicaid SGLT2 inhibitor prescribing using State Drug Utilization Data (SDUD), Medicaid enrolment denominators, and state-level covariates.

## Research Question

How does Medicaid SGLT2 inhibitor uptake vary across U.S. states and DC over time, and how is uptake associated with rurality, social vulnerability, Medicaid expansion, physician supply, and disease burden?

## Folder Structure

```text
data_raw/
  ndc_lookup/
  sdud/
  medicaid_enrolment/
  covariates/
    ahrf/
    mmd/
    rucc/
    svi/
    medicaid_expansion/

data_processed/
  ndc_lookup/
  sdud_extracts/
  enrolment/
  covariates/

for_analysis/
  master/
  model_outputs/
    tables/
    figures/
    diagnostics/

docs/
  protocol/
  logs/
  methods/
  data_dictionary/

archive/
```

## Raw Data Required

- FDA NDC Directory: `data_raw/ndc_lookup/product.txt`, `data_raw/ndc_lookup/package.txt`
- Annual SDUD CSVs: `data_raw/sdud/` for 2015-2025
- CMS Medicaid enrolment: `data_raw/medicaid_enrolment/medicaid-enrollment-new-adult-group-02052026.csv`
- AHRF physician dashboards: `data_raw/covariates/ahrf/AHRFDashboard*.xlsx`
- CMS Mapping Medicare Disparities extracts: `data_raw/covariates/mmd/mmd_data_*.csv`
- RUCC 2023 county file: `data_raw/covariates/rucc/Ruralurbancontinuumcodes2023.csv`
- CDC/ATSDR SVI 2022 county file: `data_raw/covariates/svi/SVI_2022_US_county.csv`
- Medicaid expansion status: `data_raw/covariates/medicaid_expansion/medicaid_expansion_status.csv`

## Run Order

From the repository root:

```r
source("scripts/run_all.R")
```

The numbered scripts run in this order:

```text
01_build_sglt2_ndc_lookup.R
02_extract_sglt2_from_sdud.R
03_build_medicaid_enrolment_denominators.R
04_clean_covariates.R
05_build_master_analysis_table.R
06_model_main_analysis.R
07_model_sensitivity_outcomes.R
08_model_region_adjusted_sensitivity.R
09_make_final_tables_and_figures.R
```

## Final Outputs

- Master tables: `for_analysis/master/`
- Final model/descriptive tables: `for_analysis/model_outputs/tables/`
- Final diagnostics: `for_analysis/model_outputs/diagnostics/`
- Final figures: `for_analysis/model_outputs/figures/`
- Logs: `docs/logs/`
- Data dictionary: `docs/data_dictionary/data_dictionary.md`

## Analysis Notes

The analysis excludes 2020 because the available 2020 SDUD extract is incomplete. PR and XX are excluded because the analytic sample is limited to the 50 U.S. states plus DC.

The Medicaid denominator is `medicaid_enrolment_quarter_avg`, defined as average monthly total Medicaid enrolment within the state-quarter. Modelling scripts create `log_medicaid_enrolment = log(medicaid_enrolment_quarter_avg)` and use it as the offset.

Raw SDUD files are several GB and should not be committed. Keep them local in `data_raw/sdud/`; the existing `.gitignore` excludes that folder.
