# Repo Cleanup Summary

Date: 2026-05-04

## What Changed

- Reorganized raw inputs into typed source folders under `data_raw/`.
- Reorganized processed datasets into `data_processed/ndc_lookup/`, `data_processed/sdud_extracts/`, `data_processed/enrolment/`, and `data_processed/covariates/`.
- Rebuilt the final master tables under `for_analysis/master/`.
- Rebuilt the final model outputs under:
  - `for_analysis/model_outputs/tables/`
  - `for_analysis/model_outputs/figures/`
  - `for_analysis/model_outputs/diagnostics/`
- Archived superseded, duplicate, exploratory, and proof-of-concept files under `archive/`.
- Replaced the old script set with a clean numbered run order plus `scripts/run_all.R`.
- Updated `README.md`.
- Created `docs/data_dictionary/data_dictionary.md`.
- Created this cleanup summary and the file move plan under `docs/logs/`.

## Final Structure

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
  old_outputs/
  old_scripts/
  poc_outputs/
  duplicate_files/
```

## Files Moved

- Raw FDA NDC inputs moved to `data_raw/ndc_lookup/`.
- Raw AHRF, MMD, RUCC, SVI, and Medicaid expansion inputs moved into `data_raw/covariates/` subfolders.
- Final processed NDC, SDUD extract, enrolment, and covariate files moved into `data_processed/` subfolders.
- Final analysis tables, diagnostics, and figures moved into `for_analysis/model_outputs/` subfolders.
- Protocol, methods, audit, and modelling logs moved into `docs/` subfolders.
- 123 files are currently preserved under `archive/`.

## Files Kept

- Raw SDUD annual CSVs remain in `data_raw/sdud/`.
- Final processed data required to reproduce the master analysis remain in `data_processed/`.
- Final master tables remain in `for_analysis/master/`.
- Final paper/abstract tables, figures, and diagnostics remain in `for_analysis/model_outputs/`.
- Original superseded files remain available in `archive/`.

## Files Created

- `scripts/00_setup.R`
- `scripts/01_build_sglt2_ndc_lookup.R`
- `scripts/02_extract_sglt2_from_sdud.R`
- `scripts/03_build_medicaid_enrolment_denominators.R`
- `scripts/04_clean_covariates.R`
- `scripts/05_build_master_analysis_table.R`
- `scripts/06_model_main_analysis.R`
- `scripts/07_model_sensitivity_outcomes.R`
- `scripts/08_model_region_adjusted_sensitivity.R`
- `scripts/09_make_final_tables_and_figures.R`
- `scripts/run_all.R`
- `docs/2026-05_repo_cleanup_audit.md`
- `docs/logs/2026-05_file_move_plan.md`
- `docs/logs/2026-05_repo_cleanup_audit.md`
- `docs/logs/2026-05_repo_cleanup_summary.md`
- `docs/data_dictionary/data_dictionary.md`
- Final master, model, diagnostic, and figure outputs in their final folders.

## Acceptance Checks

- `scripts/run_all.R` exists and completed successfully.
- All final numbered scripts exist.
- Final master table exists.
- Final sensitivity master has 1,938 rows, 48 columns, and 38 year-quarters.
- Master keys are unique by `state`, `year`, and `quarter`.
- `medicaid_enrolment_quarter_avg` is present.
- `medicaid_enrolment` and `medicaid_enrolment_avg` are absent from the final master.
- PR and XX are absent.
- 2020 is absent.
- `census_region` and `census_division` are present.
- `sglt2_prescriptions_single_agent` and `sglt2_prescriptions_empa_dapa` are present.
- Final model tables exist.
- Final figures `fig1` through `fig9` exist.
- `README.md` exists.
- `docs/data_dictionary/data_dictionary.md` exists.
- Superseded proof-of-concept outputs are archived, not deleted.

## Remaining Manual Tasks

- Review archived documentation in `archive/old_outputs/old_docs/` for any prose that should be merged into the current protocol or methods draft.
- Confirm whether raw SDUD files should remain local only; `.gitignore` currently excludes `data_raw/sdud/`.
- Review model tables for manuscript-specific formatting before journal submission.

## Rerun Command

From the repository root:

```bash
Rscript scripts/run_all.R
```
