# Medicaid SGLT2 Inhibitor Uptake: Social Vulnerability, Rurality and State Policy

[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.23548149.svg)](https://doi.org/10.5281/zenodo.23548149)

Analysis code and outputs for the manuscript:

> Chukwudi IR, Nnamani E, Akpabio NC, Shaka H. **Unequal Diffusion of SGLT2 Inhibitors in Medicaid: The Role of Social Vulnerability and State Policy.**

The pipeline builds a state-quarter panel of Medicaid SGLT2 inhibitor prescribing for the 50 U.S. states and the District of Columbia, 2015 Q1–2025 Q2 (2020 excluded), from public CMS State Drug Utilization Data (SDUD). It links the panel to Medicaid enrolment denominators and state-level covariates, fits negative binomial models, and regenerates every table, figure and number reported in the manuscript from raw public data.

## Research question

How does Medicaid SGLT2 inhibitor prescribing vary across states and over time, and is it associated with state rurality, social vulnerability (CDC/ATSDR SVI), Medicaid expansion, cardiovascular physician supply and cardiometabolic disease burden?

## Reproducing the analysis

Requirements: R ≥ 4.5 with the packages listed in `scripts/00_setup.R` (tidyverse, here, janitor, readxl, lubridate, DBI, duckdb, glue, MASS, broom, sandwich, lmtest, scales, forcats). The exact environment used for the reported results is recorded in [`docs/logs/r_session_info.txt`](docs/logs/r_session_info.txt).

1. Download the SDUD annual files (see [Data sources](#data-sources)) into `data_raw/sdud/`. They are several GB, so they are not included in this repository. All other raw inputs are included.
2. From the repository root (or by opening `medicaid-sglt2i-uptake.Rproj`), run:

```r
source("scripts/run_all.R")
```

A full run takes under a minute on a recent laptop. The final step, `12_verify_manuscript_values.R`, compares each of the 844 values reported in the manuscript ([`docs/manuscript_reported_values.csv`](docs/manuscript_reported_values.csv)) with the regenerated outputs. It stops with an error if any value no longer matches. The latest check is in [`docs/logs/manuscript_value_check.csv`](docs/logs/manuscript_value_check.csv).

The pipeline is deterministic: repeated runs from the same raw files produce byte-identical outputs.

## Pipeline

| Script | Purpose |
|---|---|
| `00_setup.R` | Packages, shared helpers, model-fitting and validation functions |
| `01_build_sglt2_ndc_lookup.R` | SGLT2 inhibitor NDC list from the FDA NDC Directory |
| `02_extract_sglt2_from_sdud.R` | Extract SGLT2 rows from annual SDUD files (DuckDB); state-quarter totals |
| `03_build_medicaid_enrolment_denominators.R` | Quarterly mean monthly Medicaid enrolment |
| `04_clean_covariates.R` | Rurality (RUCC), SVI, AHRF physician density, MMD disease burden, expansion status, Census region |
| `05_build_master_analysis_table.R` | Master state-quarter analysis table (1,938 rows) |
| `06_model_main_analysis.R` | Descriptive trends, primary model (Model 6), continuous-rurality sensitivity, Figures 1–4 and S1–S3 |
| `07_model_sensitivity_outcomes.R` | Restricted-outcome sensitivity models (single-agent; empagliflozin/dapagliflozin) |
| `08_model_region_adjusted_sensitivity.R` | Census-region-adjusted models (Model 7) |
| `09_model_sequential_series.R` | Sequential adjustment series (Models 1–5) and the Models 1–7 comparison |
| `10_make_manuscript_tables.R` | Tables 1–3 and the supplementary sequential-model table, in manuscript layout |
| `11_check_final_outputs.R` | Confirms all expected outputs exist and the master table passes integrity checks |
| `12_verify_manuscript_values.R` | Checks every manuscript-reported value against regenerated outputs |

## Manuscript to output map

Values in the output files keep full precision. Rounding is applied only in the manuscript.

| Manuscript item | Output file | Script |
|---|---|---|
| Table 1 (Panels A and B): state characteristics | `for_analysis/manuscript_tables/table1_state_characteristics.csv` | 06, 10 |
| Table 2: primary fully adjusted model | `for_analysis/manuscript_tables/table2_primary_model.csv` | 06, 10 |
| Table 3: primary vs Census-region-adjusted model | `for_analysis/manuscript_tables/table3_primary_vs_region_adjusted.csv` | 06, 08, 10 |
| Sequential models (Methods; Results/Discussion statements on how SVI changes with adjustment) | `for_analysis/manuscript_tables/table_supplement_sequential_models.csv` | 06, 08, 09 |
| Figure 1: national quarterly prescribing | `for_analysis/model_outputs/figures/fig1_national_quarterly_sglt2_rate.png` | 06 |
| Figure 2: prescribing by rurality quintile | `for_analysis/model_outputs/figures/fig2_rurality_quintile_quarterly_sglt2_rate.png` | 06 |
| Figure 3: prescribing by SVI quintile | `for_analysis/model_outputs/figures/fig3_svi_quintile_quarterly_sglt2_rate.png` | 06 |
| Figure 4: primary model forest plot | `for_analysis/model_outputs/figures/fig7_main_model_forest_plot.png` | 06 |
| Figure 5: region-adjusted model forest plot | `for_analysis/model_outputs/figures/fig9_region_adjusted_forest_plot.png` | 08 |
| Figure S1: state-quarter rates by rurality quintile | `for_analysis/model_outputs/figures/fig4_boxplot_rates_by_rurality_quintile.png` | 06 |
| Figure S2: state SVI vs mean prescribing | `for_analysis/model_outputs/figures/fig5_scatter_svi_vs_state_mean_rate.png` | 06 |
| Figure S3: state-quarter heatmap | `for_analysis/model_outputs/figures/fig6_state_quarter_heatmap_sglt2_rate.png` | 06 |
| Figure S4: restricted-outcome sensitivity | `for_analysis/model_outputs/figures/fig8_sensitivity_outcome_comparison_forest_plot.png` | 07 |
| Table S2: national quarterly prescribing | `for_analysis/model_outputs/tables/descriptive_national_quarterly_trend.csv` | 06 |
| Table S3: rurality-quintile quarterly prescribing | `for_analysis/model_outputs/tables/descriptive_rurality_quarterly_trend.csv` | 06 |
| Table S4: SVI-quintile quarterly prescribing | `for_analysis/model_outputs/tables/descriptive_svi_quarterly_trend.csv` | 06 |
| Restricted-outcome estimates | `for_analysis/model_outputs/tables/sensitivity_outcome_comparison_key_results.csv` | 07 |
| Continuous-rurality sensitivity | `for_analysis/model_outputs/tables/main_model_key_results.csv` (`sensitivity_continuous_rurality`) | 06 |
| Full coefficient tables | `for_analysis/model_outputs/tables/*_coefficients.csv` | 06, 09 |
| Model diagnostics (convergence, theta, AIC, overdispersion) | `for_analysis/model_outputs/diagnostics/` | 06–09 |

## Model specification

All models are negative binomial regressions (`MASS::glm.nb`) of quarterly SGLT2 inhibitor prescription counts. They use log quarterly mean monthly Medicaid enrolment as an offset, categorical calendar year and quarter, and state-clustered robust standard errors (`sandwich::vcovCL`). Rurality quintile 5 (most urban) is the reference. SVI is scaled per 0.1 increase.

| Model | Adjustment set |
|---|---|
| 1 | Rurality + time |
| 2 | SVI + time |
| 3 | Rurality + SVI + time |
| 4 | Model 3 + time-varying Medicaid expansion |
| 5 | Model 4 + CVD physician density |
| 6 (primary) | Model 5 + Medicare FFS HF/IHD, diabetes and CKD prevalence |
| 7 (sensitivity) | Model 6 + Census region |

Restricted-outcome sensitivity analyses repeat Models 6 and 7 for single-agent products (excluding fixed-dose combinations) and for empagliflozin/dapagliflozin-containing products.

## Data sources

All inputs are public. Only the SDUD files must be downloaded separately.

| Input | Location in repository | Source |
|---|---|---|
| State Drug Utilization Data, 2015–2025 | `data_raw/sdud/` (not included; download annual CSVs) | [CMS Medicaid SDUD](https://www.medicaid.gov/medicaid/prescription-drugs/state-drug-utilization-data) |
| FDA National Drug Code Directory | `data_raw/ndc_lookup/` | [FDA NDC Directory](https://www.fda.gov/drugs/drug-approvals-and-databases/national-drug-code-directory) |
| Medicaid enrolment (MBES) | `data_raw/medicaid_enrolment/` | [CMS Medicaid enrolment data](https://www.medicaid.gov/medicaid/national-medicaid-chip-program-information/medicaid-chip-enrollment-data/medicaid-enrollment-data-collected-through-mbes) |
| Rural–Urban Continuum Codes 2023 | `data_raw/covariates/rucc/` | [USDA ERS](https://www.ers.usda.gov/data-products/rural-urban-continuum-codes) |
| Social Vulnerability Index 2022 | `data_raw/covariates/svi/` | [CDC/ATSDR SVI](https://www.atsdr.cdc.gov/place-health/php/svi/) |
| Area Health Resources Files | `data_raw/covariates/ahrf/` | [HRSA AHRF](https://data.hrsa.gov/data/download?AHRF=&data=AHRF) |
| Mapping Medicare Disparities | `data_raw/covariates/mmd/` | [CMS MMD tool](https://www.cms.gov/priorities/health-equity/minority-health/research-data/mapping-medicare-disparities-tool-mmd) |
| Medicaid expansion dates | `data_raw/covariates/medicaid_expansion/` | Coded from [KFF expansion tracker](https://www.kff.org/affordable-care-act/state-indicator/state-activity-around-expanding-medicaid-under-the-affordable-care-act/) |
| Census regions | Coded in `04_clean_covariates.R` | [U.S. Census Bureau](https://www.census.gov/programs-surveys/economic-census/guidance-geographies/levels.html) |

SDUD file names expected by `02_extract_sglt2_from_sdud.R`: `StateDrugUtilizationData-2015.csv` to `StateDrugUtilizationData-2019.csv` and `sdud-2020-updated.csv` to `sdud-2025-updated.csv`. CMS revises SDUD files over time, so a fresh download may differ slightly from the files used here, which were obtained in April 2026. Their SHA-256 checksums are in [`docs/sdud_file_checksums.sha256`](docs/sdud_file_checksums.sha256); from `data_raw/sdud/`, `shasum -a 256 -c ../../docs/sdud_file_checksums.sha256` confirms identical inputs.

## Analysis notes

- 2020 is excluded because the SDUD extract used contained only quarter 4 for that year. Puerto Rico and non-state reporting rows (`XX`) are excluded.
- Fee-for-service and managed-care utilisation are pooled. Missing SGLT2 utilisation in state-quarters with valid enrolment is treated as zero; enrolment and covariates are not imputed.
- Rurality, physician density and disease burden are fixed 2023 state measures; SVI is the 2022 state measure. Medicaid expansion is time-varying by quarter.
- This is a state-level ecological analysis. Associations do not establish individual-level effects or causal policy effects.

## Repository structure

```text
data_raw/            Raw public inputs (SDUD excluded; see above)
data_processed/      Cleaned extracts, denominators and covariates
for_analysis/
  master/            Master state-quarter analysis tables
  model_outputs/     Model tables, figures and diagnostics
  manuscript_tables/ Tables in manuscript layout
docs/
  manuscript_reported_values.csv   Values reported in the manuscript, checked on every run
  logs/              Build and modelling logs, value check, R session info
  data_dictionary/   Variable definitions
  methods/, protocol/              Pre-analysis methods and study protocol
scripts/             Numbered pipeline scripts and run_all.R
```

## Citation and licence

Please cite the article above when using this code. The code is archived on Zenodo: version 1.0.0, which produced the reported results, is [10.5281/zenodo.23548150](https://doi.org/10.5281/zenodo.23548150), and all versions are at [10.5281/zenodo.23548149](https://doi.org/10.5281/zenodo.23548149). Citation metadata is in [`CITATION.cff`](CITATION.cff). The code is released under the [MIT licence](LICENSE). The data remain subject to the terms of their original public sources.
