# Medicaid enrolment and SGLT2i rate construction

## SDUD outcome source

The SGLT2 inhibitor prescribing outcomes are derived from processed Medicaid State Drug Utilization Data (SDUD) files in `data_processed/`. The primary outcome file is `sglt2_state_quarter_all_products_2015_2025.csv`, which contains quarterly state-level SGLT2 inhibitor utilization after matching SDUD National Drug Codes to an FDA NDC-derived SGLT2 inhibitor lookup table.

The processed SDUD state-quarter files already combine fee-for-service utilization (`FFSU`) and managed care organization utilization (`MCOU`).

## Primary analytic unit

The primary unit of analysis is state-quarter, not state-year. The main analysis-ready dataset is:

`data_processed/sglt2_state_quarter_rates_all_products_50dc_excluding_2020.csv`

Annual files, if retained, are secondary descriptive outputs only and are not the primary modelling dataset.

## Analytic exclusions

The analytic files exclude 2020 because the available 2020 SDUD source contains only quarter 4. The analytic sample is restricted to the 50 U.S. states plus the District of Columbia. Puerto Rico (`PR`), unknown/non-state aggregate reporting (`XX`), territories, national totals, and other non-state reporting rows are excluded.

The included analysis years are 2015-2019 and 2021-2025, limited to year-quarters with available Medicaid enrolment denominator data.

## Medicaid enrolment denominator

Medicaid enrolment denominators come from the official CMS Data.Medicaid.gov MBES source, **Medicaid Enrollment - New Adult Group**:

<https://download.medicaid.gov/data/medicaid-enrollment-new-adult-group-02052026.csv>

The raw file is saved in `data_raw/medicaid_enrolment/`, and the cleaned quarterly denominator is saved as `data_processed/medicaid_enrolment_state_quarter.csv`.

The denominator uses `Total Medicaid Enrollees`. It does not use `Total VIII Group Enrollees` or any VIII/new adult group enrolment column.

The MBES source reports monthly counts of unduplicated individuals enrolled in each state's Medicaid program at any time during each month in the quarterly reporting period. Quarterly Medicaid enrolment denominators are calculated as the mean of monthly `Total Medicaid Enrollees` within each state-quarter. In the cleaned file this value is stored as `medicaid_enrolment_quarter_avg` and copied to `medicaid_enrolment` for use as the rate denominator.

The February 2026 CMS MBES release contains complete monthly data for 2015-2019 and 2021-2024, and January-June data for 2025. Therefore, the quarterly denominator covers 2025 Q1 and Q2, while 2025 Q3 and Q4 are excluded from the quarterly rate outputs until denominator data are available.

## Rate formula

SGLT2i prescriptions per 10,000 Medicaid beneficiaries =

`quarterly SGLT2i prescriptions / average quarterly Medicaid enrolment × 10,000`

The same quarterly Medicaid enrolment denominator is used for the all-products primary analysis and for sensitivity files restricted to single-agent products and empagliflozin/dapagliflozin products.
