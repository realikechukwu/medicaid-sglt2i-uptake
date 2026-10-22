if (!requireNamespace("here", quietly = TRUE)) {
  stop("Install the `here` package before running this script.", call. = FALSE)
}
source(here::here("scripts", "00_setup.R"))

# Manuscript Tables 1-3, supplementary Table S1 and the supplementary
# sequential-model table, laid out as reported, plus the SDUD suppression bound
# quoted in the Methods. Values keep full precision; rounding is applied in the
# manuscript.

tables_dir <- project_path("for_analysis", "model_outputs", "tables")
diagnostics_dir <- project_path("for_analysis", "model_outputs", "diagnostics")
manuscript_dir <- project_path("for_analysis", "manuscript_tables")
ensure_dir(manuscript_dir)
ensure_dir(diagnostics_dir)

master_file <- project_path("for_analysis", "master", "master_state_quarter_sglt2_covariates.csv")
sdud_row_level_file <- project_path("data_processed", "sdud_extracts", "sdud_sglt2_row_level_2015_2025.csv")
state_summary_file <- file.path(tables_dir, "descriptive_state_summary.csv")
svi_trend_file <- file.path(tables_dir, "descriptive_svi_quarterly_trend.csv")
main_key_file <- file.path(tables_dir, "main_model_key_results.csv")
region_key_file <- file.path(tables_dir, "region_adjusted_key_results.csv")
sequential_key_file <- file.path(tables_dir, "sequential_models_key_results.csv")

require_files(
  c(
    master_file, sdud_row_level_file, state_summary_file, svi_trend_file,
    main_key_file, region_key_file, sequential_key_file
  ),
  "manuscript table input file"
)

master <- readr::read_csv(master_file, show_col_types = FALSE) |>
  janitor::clean_names()

# Table S1: Panel A (prescribing and exposures) and Panel B (policy, provider capacity, disease burden).
final_quarter <- master |>
  dplyr::distinct(year, quarter) |>
  dplyr::arrange(dplyr::desc(year), dplyr::desc(quarter)) |>
  dplyr::slice(1)

state_context <- master |>
  dplyr::group_by(state) |>
  dplyr::summarise(
    dplyr::across(
      c(
        rucc_nonmetro_population_share_2023,
        census_region,
        cvd_physicians_per_100k_2023,
        medicare_ffs_hf_ihd_prevalence_2023,
        medicare_ffs_diabetes_prevalence_2023,
        medicare_ffs_ckd_prevalence_2023
      ),
      dplyr::first
    ),
    n_distinct_context = dplyr::n_distinct(
      rucc_nonmetro_population_share_2023,
      census_region,
      cvd_physicians_per_100k_2023,
      medicare_ffs_hf_ihd_prevalence_2023,
      medicare_ffs_diabetes_prevalence_2023,
      medicare_ffs_ckd_prevalence_2023
    ),
    .groups = "drop"
  )

if (any(state_context$n_distinct_context != 1)) {
  stop("Table S1 contextual covariates must be constant within each state.", call. = FALSE)
}

final_expansion <- master |>
  dplyr::semi_join(final_quarter, by = c("year", "quarter")) |>
  dplyr::transmute(state, medicaid_expansion_active_final_quarter = medicaid_expansion_active)

table_s1 <- readr::read_csv(state_summary_file, show_col_types = FALSE) |>
  dplyr::transmute(
    state,
    rurality_quintile,
    svi_2022,
    mean_prescriptions_per_10000,
    median_prescriptions_per_10000,
    min_prescriptions_per_10000,
    max_prescriptions_per_10000,
    total_prescriptions,
    mean_medicaid_enrolment
  ) |>
  dplyr::left_join(dplyr::select(state_context, -n_distinct_context), by = "state") |>
  dplyr::left_join(final_expansion, by = "state") |>
  dplyr::mutate(
    nonmetro_population_pct_2023 = rucc_nonmetro_population_share_2023 * 100,
    final_quarter = paste0(final_quarter$year, " Q", final_quarter$quarter)
  ) |>
  dplyr::select(
    state,
    rurality_quintile,
    svi_2022,
    mean_prescriptions_per_10000,
    median_prescriptions_per_10000,
    min_prescriptions_per_10000,
    max_prescriptions_per_10000,
    total_prescriptions,
    mean_medicaid_enrolment,
    nonmetro_population_pct_2023,
    census_region,
    medicaid_expansion_active_final_quarter,
    final_quarter,
    cvd_physicians_per_100k_2023,
    medicare_ffs_hf_ihd_prevalence_2023,
    medicare_ffs_diabetes_prevalence_2023,
    medicare_ffs_ckd_prevalence_2023
  ) |>
  dplyr::arrange(state)

if (nrow(table_s1) != length(valid_50dc) || anyNA(table_s1)) {
  stop("Table S1 must have one complete row for each of the 50 states and DC.", call. = FALSE)
}

safe_write_csv(table_s1, file.path(manuscript_dir, "table_s1_state_characteristics.csv"))

# Table 1: state characteristics summarised by SVI quintile. Quintiles are
# assigned at state level exactly as for Figure 3 (script 06).
svi_state_quintiles <- table_s1 |>
  dplyr::select(state, svi_2022) |>
  dplyr::arrange(svi_2022, state) |>
  dplyr::mutate(svi_quintile = dplyr::ntile(svi_2022, 5))

table1_states <- table_s1 |>
  dplyr::left_join(dplyr::select(svi_state_quintiles, state, svi_quintile), by = "state")

first_quarter <- master |>
  dplyr::distinct(year, quarter) |>
  dplyr::arrange(year, quarter) |>
  dplyr::slice(1)

last_pre_2020_quarter <- master |>
  dplyr::filter(year < 2020) |>
  dplyr::distinct(year, quarter) |>
  dplyr::arrange(dplyr::desc(year), dplyr::desc(quarter)) |>
  dplyr::slice(1)

pooled_rate <- function(states, period) {
  rows <- master |>
    dplyr::filter(state %in% states) |>
    dplyr::semi_join(period, by = c("year", "quarter"))
  1e4 * sum(rows$sglt2_prescriptions_all_products) / sum(rows$medicaid_enrolment_quarter_avg)
}

# Quartiles use R's default (type 7) definition.
summarise_table1_group <- function(group) {
  pct_nonmetro <- group$nonmetro_population_pct_2023
  quartiles <- function(x) stats::quantile(x, c(0.25, 0.5, 0.75), names = FALSE)
  q_nonmetro <- quartiles(pct_nonmetro)
  q_cvd <- quartiles(group$cvd_physicians_per_100k_2023)
  q_hf <- quartiles(group$medicare_ffs_hf_ihd_prevalence_2023)
  q_dm <- quartiles(group$medicare_ffs_diabetes_prevalence_2023)
  q_ckd <- quartiles(group$medicare_ffs_ckd_prevalence_2023)

  tibble::tribble(
    ~row_id, ~characteristic, ~statistic, ~value,
    "states_n", "States", "n", nrow(group),
    "svi_min", "SVI", "minimum", min(group$svi_2022),
    "svi_max", "SVI", "maximum", max(group$svi_2022),
    "nonmetro_pct_median", "Nonmetro population, %", "median", q_nonmetro[2],
    "nonmetro_pct_p25", "Nonmetro population, %", "25th percentile", q_nonmetro[1],
    "nonmetro_pct_p75", "Nonmetro population, %", "75th percentile", q_nonmetro[3],
    "most_rural_quintile_n", "Most-rural quintile states", "n", sum(group$rurality_quintile == 1),
    "region_northeast_n", "Census region: Northeast", "n", sum(group$census_region == "Northeast"),
    "region_midwest_n", "Census region: Midwest", "n", sum(group$census_region == "Midwest"),
    "region_south_n", "Census region: South", "n", sum(group$census_region == "South"),
    "region_west_n", "Census region: West", "n", sum(group$census_region == "West"),
    "expansion_active_final_quarter_n", "Medicaid expansion active in final quarter", "n", sum(group$medicaid_expansion_active_final_quarter == 1),
    "expansion_active_final_quarter_pct", "Medicaid expansion active in final quarter", "%", 100 * mean(group$medicaid_expansion_active_final_quarter == 1),
    "mean_medicaid_enrolment_millions", "Mean Medicaid enrolment, millions", "sum of state means", sum(group$mean_medicaid_enrolment) / 1e6,
    "total_prescriptions_millions", "Total SGLT2 prescriptions, millions", "sum", sum(group$total_prescriptions) / 1e6,
    "cvd_physicians_median", "CVD physicians per 100,000", "median", q_cvd[2],
    "cvd_physicians_p25", "CVD physicians per 100,000", "25th percentile", q_cvd[1],
    "cvd_physicians_p75", "CVD physicians per 100,000", "75th percentile", q_cvd[3],
    "hf_ihd_median", "HF/IHD prevalence, %", "median", q_hf[2],
    "hf_ihd_p25", "HF/IHD prevalence, %", "25th percentile", q_hf[1],
    "hf_ihd_p75", "HF/IHD prevalence, %", "75th percentile", q_hf[3],
    "diabetes_median", "Diabetes prevalence, %", "median", q_dm[2],
    "diabetes_p25", "Diabetes prevalence, %", "25th percentile", q_dm[1],
    "diabetes_p75", "Diabetes prevalence, %", "75th percentile", q_dm[3],
    "ckd_median", "CKD prevalence, %", "median", q_ckd[2],
    "ckd_p25", "CKD prevalence, %", "25th percentile", q_ckd[1],
    "ckd_p75", "CKD prevalence, %", "75th percentile", q_ckd[3],
    "rate_first_quarter", "Prescribing rate per 10,000", paste0(first_quarter$year, " Q", first_quarter$quarter), pooled_rate(group$state, first_quarter),
    "rate_last_pre_2020_quarter", "Prescribing rate per 10,000", paste0(last_pre_2020_quarter$year, " Q", last_pre_2020_quarter$quarter), pooled_rate(group$state, last_pre_2020_quarter),
    "rate_final_quarter", "Prescribing rate per 10,000", paste0(final_quarter$year, " Q", final_quarter$quarter), pooled_rate(group$state, final_quarter)
  )
}

table1_groups <- c(
  purrr::map(rlang::set_names(1:5, paste0("svi_q", 1:5)), ~ dplyr::filter(table1_states, svi_quintile == .x)),
  list(all_states = table1_states)
)

table1 <- purrr::imap(table1_groups, function(group, group_name) {
  dplyr::rename(summarise_table1_group(group), !!group_name := value)
}) |>
  purrr::reduce(dplyr::left_join, by = c("row_id", "characteristic", "statistic"))

# Guard against drift: Table 1 quintile rates must match the Figure 3 trend file.
svi_trend_final <- readr::read_csv(svi_trend_file, show_col_types = FALSE) |>
  dplyr::semi_join(final_quarter, by = c("year", "quarter")) |>
  dplyr::arrange(svi_quintile)
table1_final_rates <- unlist(table1[table1$row_id == "rate_final_quarter", paste0("svi_q", 1:5)])

if (nrow(svi_trend_final) != 5 || any(abs(table1_final_rates - svi_trend_final$prescriptions_per_10000) > 1e-8)) {
  stop("Table 1 SVI-quintile rates no longer match the Figure 3 trend file.", call. = FALSE)
}

if (anyNA(table1) || table1$all_states[table1$row_id == "states_n"] != length(valid_50dc)) {
  stop("Table 1 must summarise all 50 states and DC without missing values.", call. = FALSE)
}

safe_write_csv(table1, file.path(manuscript_dir, "table1_svi_quintile_summary.csv"))

# Methods: upper bound on prescriptions hidden by SDUD small-cell suppression
# (counts below 11) within the analysed state-quarters, assuming every
# suppressed product row held the maximum possible count of 10.
sdud_rows <- readr::read_csv(
  sdud_row_level_file,
  col_types = readr::cols(
    state = readr::col_character(),
    year = readr::col_integer(),
    quarter = readr::col_integer(),
    suppression_used = readr::col_logical(),
    number_of_prescriptions = readr::col_double(),
    .default = readr::col_skip()
  )
) |>
  dplyr::semi_join(dplyr::distinct(master, state, year, quarter), by = c("state", "year", "quarter"))

if (any(sdud_rows$suppression_used & !is.na(sdud_rows$number_of_prescriptions))) {
  stop("Suppressed SDUD rows unexpectedly carry prescription counts.", call. = FALSE)
}

observed_prescriptions <- sum(sdud_rows$number_of_prescriptions, na.rm = TRUE)

if (abs(observed_prescriptions - sum(master$sglt2_prescriptions_all_products)) > 1e-6) {
  stop("SDUD row-level prescriptions do not sum to the master table total.", call. = FALSE)
}

max_suppressed_count <- 10
n_suppressed_rows <- sum(sdud_rows$suppression_used)
max_hidden_prescriptions <- n_suppressed_rows * max_suppressed_count

suppression_bound <- tibble::tibble(
  n_product_rows = nrow(sdud_rows),
  n_suppressed_rows = n_suppressed_rows,
  pct_rows_suppressed = 100 * n_suppressed_rows / nrow(sdud_rows),
  observed_prescriptions = observed_prescriptions,
  max_count_per_suppressed_row = max_suppressed_count,
  max_hidden_prescriptions = max_hidden_prescriptions,
  max_hidden_pct_of_total = 100 * max_hidden_prescriptions / (observed_prescriptions + max_hidden_prescriptions)
)

safe_write_csv(suppression_bound, file.path(diagnostics_dir, "sdud_suppression_bound.csv"))

# Table 2: primary fully adjusted model (Model 6), state-characteristic coefficients.
table2_terms <- c(
  "rurality_quintile1",
  "rurality_quintile2",
  "rurality_quintile3",
  "rurality_quintile4",
  "svi_2022_per_0_1",
  "medicaid_expansion_active",
  "cvd_physicians_per_100k_2023",
  "medicare_ffs_hf_ihd_prevalence_2023",
  "medicare_ffs_diabetes_prevalence_2023",
  "medicare_ffs_ckd_prevalence_2023"
)

main_key <- readr::read_csv(main_key_file, show_col_types = FALSE) |>
  dplyr::filter(model_id == "main_full")

table2 <- main_key |>
  dplyr::filter(term %in% table2_terms) |>
  dplyr::mutate(term = factor(term, levels = table2_terms)) |>
  dplyr::arrange(term) |>
  dplyr::mutate(term = as.character(term)) |>
  dplyr::select(term, exposure, comparison_or_unit, irr, conf_low, conf_high, p_value)

if (nrow(table2) != length(table2_terms)) {
  stop("Table 2 is missing primary-model terms.", call. = FALSE)
}

safe_write_csv(table2, file.path(manuscript_dir, "table2_primary_model.csv"))

# Table 3: primary versus Census-region-adjusted model for the three central associations.
table3_terms <- c("rurality_quintile1", "svi_2022_per_0_1", "medicaid_expansion_active")

region_key <- readr::read_csv(region_key_file, show_col_types = FALSE)

table3 <- main_key |>
  dplyr::filter(term %in% table3_terms) |>
  dplyr::select(term, exposure, comparison_or_unit, primary_irr = irr, primary_conf_low = conf_low, primary_conf_high = conf_high, primary_p_value = p_value) |>
  dplyr::inner_join(
    region_key |>
      dplyr::select(term, region_adjusted_irr = irr, region_adjusted_conf_low = conf_low, region_adjusted_conf_high = conf_high, region_adjusted_p_value = p_value),
    by = "term"
  ) |>
  dplyr::mutate(term = factor(term, levels = table3_terms)) |>
  dplyr::arrange(term) |>
  dplyr::mutate(term = as.character(term))

if (nrow(table3) != length(table3_terms)) {
  stop("Table 3 is missing primary or region-adjusted terms.", call. = FALSE)
}

safe_write_csv(table3, file.path(manuscript_dir, "table3_primary_vs_region_adjusted.csv"))

# Table S2: national quarterly prescribing.
national_trend <- readr::read_csv(file.path(tables_dir, "descriptive_national_quarterly_trend.csv"), show_col_types = FALSE)

table_s2 <- national_trend |>
  dplyr::arrange(year, quarter) |>
  dplyr::select(year_quarter, total_sglt2_prescriptions, total_medicaid_enrolment, national_prescriptions_per_10000)

safe_write_csv(table_s2, file.path(manuscript_dir, "table_s2_national_quarterly.csv"))

# Tables S3 and S4: quintile quarterly prescribing, one row per quarter.
widen_quintile_trend <- function(trend, quintile_column) {
  trend |>
    dplyr::arrange(year, quarter) |>
    dplyr::transmute(
      year_quarter,
      quintile = .data[[quintile_column]],
      rate = prescriptions_per_10000,
      prescriptions = total_sglt2_prescriptions,
      enrolment = total_medicaid_enrolment
    ) |>
    tidyr::pivot_wider(
      names_from = quintile,
      values_from = c(rate, prescriptions, enrolment),
      names_glue = "{.value}_q{quintile}"
    )
}

rurality_trend <- readr::read_csv(file.path(tables_dir, "descriptive_rurality_quarterly_trend.csv"), show_col_types = FALSE)
svi_trend <- readr::read_csv(svi_trend_file, show_col_types = FALSE)

table_s3 <- widen_quintile_trend(rurality_trend, "rurality_quintile")
table_s4 <- widen_quintile_trend(svi_trend, "svi_quintile")

n_quarters <- dplyr::n_distinct(master$year, master$quarter)
for (quintile_table in list(table_s2, table_s3, table_s4)) {
  if (nrow(quintile_table) != n_quarters || anyNA(quintile_table)) {
    stop("Tables S2-S4 must have one complete row per analysed quarter.", call. = FALSE)
  }
}

safe_write_csv(table_s3, file.path(manuscript_dir, "table_s3_rurality_quintile_quarterly.csv"))
safe_write_csv(table_s4, file.path(manuscript_dir, "table_s4_svi_quintile_quarterly.csv"))

# Table S5: sequential adjustment series (Models 1-7).
table_s5 <- readr::read_csv(sequential_key_file, show_col_types = FALSE)
safe_write_csv(table_s5, file.path(manuscript_dir, "table_s5_sequential_models.csv"))

# Formatted copy of Tables S2-S5 for the supplementary material, with a
# description sheet holding titles and footnotes. The CSVs above remain the
# full-precision record; this workbook is rounded for presentation.
format_p <- function(p) dplyr::if_else(p < 0.001, "<0.001", sprintf("%.3f", p))
format_ci <- function(low, high) paste0(sprintf("%.3f", low), "–", sprintf("%.3f", high))

quintile_headers <- function(trend, quintile_column, label_column) {
  trend |>
    dplyr::distinct(quintile = .data[[quintile_column]], label = .data[[label_column]], n_states) |>
    dplyr::arrange(quintile) |>
    dplyr::mutate(header = paste0(label, " (", n_states, " states)"))
}

format_quintile_sheet <- function(wide, headers) {
  out <- tibble::tibble(Quarter = wide$year_quarter)
  for (measure in c("rate", "prescriptions", "enrolment")) {
    measure_label <- c(
      rate = "Rate per 10,000",
      prescriptions = "Prescriptions",
      enrolment = "Mean monthly enrolment"
    )[[measure]]
    for (i in seq_len(nrow(headers))) {
      values <- wide[[paste0(measure, "_q", headers$quintile[i])]]
      out[[paste0(measure_label, ": ", headers$header[i])]] <- if (measure == "rate") round(values, 1) else round(values)
    }
  }
  out
}

xlsx_s2 <- table_s2 |>
  dplyr::transmute(
    Quarter = year_quarter,
    Prescriptions = total_sglt2_prescriptions,
    `Mean monthly Medicaid enrolment` = round(total_medicaid_enrolment),
    `Rate per 10,000 beneficiaries` = round(national_prescriptions_per_10000, 1)
  )

xlsx_s3 <- format_quintile_sheet(table_s3, quintile_headers(rurality_trend, "rurality_quintile", "rurality_quintile_label"))
xlsx_s4 <- format_quintile_sheet(table_s4, quintile_headers(svi_trend, "svi_quintile", "svi_quintile_label"))

xlsx_s5 <- table_s5 |>
  dplyr::transmute(
    Model = model_label,
    `Adjustment set` = adjustment_set,
    Exposure = exposure,
    Comparison = comparison_or_unit,
    IRR = round(irr, 3),
    `95% CI` = format_ci(conf_low, conf_high),
    `P value` = format_p(p_value)
  )

period_note <- paste0(
  "Data cover ", table_s2$year_quarter[1], "–", dplyr::last(table_s2$year_quarter),
  ", excluding 2020, for the 50 states and the District of Columbia. "
)
rate_note <- "Prescriptions include refills and fixed-dose combinations and pool fee-for-service and managed care utilisation. "

xlsx_description <- tibble::tribble(
  ~Sheet, ~Table, ~Title, ~Notes,
  "Table S2", "Table S2",
  "National quarterly Medicaid SGLT2 prescribing, 2015 Q1–2025 Q2, excluding 2020",
  paste0(
    period_note, rate_note,
    "Enrolment is the sum of state mean monthly Medicaid enrolment in each quarter. ",
    "Rate = prescriptions / enrolment × 10,000. 2020 is excluded because the public State Drug Utilization Data release contained only fourth-quarter data for that year."
  ),
  "Table S3", "Table S3",
  "Quarterly Medicaid SGLT2 prescribing by rurality quintile: rates, prescription counts and enrolment",
  paste0(
    period_note, rate_note,
    "Q1 contains the most rural and Q5 the most urban states, ranked by the share of the 2020 population living in nonmetropolitan counties (2023 Rural–Urban Continuum Codes 4–9). ",
    "Quintile membership is fixed across the study period; the number of states in each quintile is shown in the column headings. ",
    "Rates are pooled quintile prescriptions divided by pooled mean monthly Medicaid enrolment, per 10,000 beneficiaries."
  ),
  "Table S4", "Table S4",
  "Quarterly Medicaid SGLT2 prescribing by state SVI quintile: rates, prescription counts and enrolment",
  paste0(
    period_note, rate_note,
    "Q1 contains the least and Q5 the most socially vulnerable states, ranked by the population-weighted 2022 CDC/ATSDR Social Vulnerability Index. ",
    "Quintiles are descriptive; regression models analysed SVI continuously per 0.1 increase. The number of states in each quintile is shown in the column headings. ",
    "Rates are pooled quintile prescriptions divided by pooled mean monthly Medicaid enrolment, per 10,000 beneficiaries."
  ),
  "Table S5", "Table S5",
  "Associations of rurality, social vulnerability and Medicaid expansion with SGLT2 prescribing across the sequential adjustment series (Models 1–7)",
  paste0(
    "All models are negative binomial regressions with log quarterly mean monthly Medicaid enrolment as an offset, categorical calendar year and quarter, and state-clustered robust 95% confidence intervals. ",
    "Model 1: rurality and time. Model 2: SVI and time. Model 3: rurality, SVI and time. Model 4: Model 3 plus Medicaid expansion. ",
    "Model 5: Model 4 plus cardiovascular physician density. Model 6 (primary; Table 2): Model 5 plus Medicare fee-for-service heart failure/ischaemic heart disease, diabetes and chronic kidney disease prevalence. ",
    "Model 7 (Table 3): Model 6 plus Census region. Rurality reference: Q5 (most urban). ",
    "CI, confidence interval; IRR, incidence rate ratio; SVI, Social Vulnerability Index."
  )
)

writexl::write_xlsx(
  list(
    Description = xlsx_description,
    `Table S2` = xlsx_s2,
    `Table S3` = xlsx_s3,
    `Table S4` = xlsx_s4,
    `Table S5` = xlsx_s5
  ),
  file.path(manuscript_dir, "supplementary_tables_S2_S5.xlsx")
)

message("Wrote manuscript tables to: ", relative_project_path(manuscript_dir))
