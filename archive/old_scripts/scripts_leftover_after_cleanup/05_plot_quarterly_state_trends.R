# ============================================================
# Plot quarterly state-level SGLT2 prescribing rate trends
# ============================================================
#
# Uses non-covariate analysis-ready quarterly rate files.
# Outputs figures to figures/ and a compact state trend summary to output/.
# ============================================================

library(tidyverse)
library(here)
library(janitor)
library(lubridate)
library(scales)

dir.create(here("figures"), showWarnings = FALSE)
dir.create(here("output"), showWarnings = FALSE)

rate_files <- tribble(
  ~definition, ~file_path,
  "All SGLT2i products", here(
    "for_analysis",
    "sglt2_state_quarter_rates_all_products_50dc_excluding_2020.csv"
  ),
  "Single-agent products", here(
    "for_analysis",
    "sglt2_state_quarter_rates_single_agent_50dc_excluding_2020.csv"
  ),
  "Empagliflozin/dapagliflozin", here(
    "for_analysis",
    "sglt2_state_quarter_rates_empa_dapa_50dc_excluding_2020.csv"
  )
)

require_columns <- function(data, required, data_label) {
  missing <- setdiff(required, names(data))

  if (length(missing) > 0) {
    message("Available columns in ", data_label, ":")
    print(names(data))
    stop(
      data_label,
      " is missing required column(s): ",
      paste(missing, collapse = ", "),
      call. = FALSE
    )
  }

  invisible(data)
}

read_rate_file <- function(definition, file_path) {
  if (!file.exists(file_path)) {
    stop("Missing input file: ", file_path)
  }

  rates <- read_csv(file_path, show_col_types = FALSE) %>%
    clean_names()

  require_columns(
    rates,
    c(
      "state",
      "year",
      "quarter",
      "sglt2_prescriptions",
      "sglt2_prescriptions_per_10000",
      "medicaid_enrolment_quarter_avg"
    ),
    basename(file_path)
  )

  rates %>%
    mutate(
      definition = definition,
      state = as.character(state),
      year = as.integer(year),
      quarter = as.integer(quarter),
      quarter_date = ymd(paste0(year, "-", (quarter - 1) * 3 + 1, "-01")),
      year_quarter = paste0(year, " Q", quarter),
      sglt2_prescriptions_per_10000 = as.numeric(sglt2_prescriptions_per_10000),
      sglt2_prescriptions = as.numeric(sglt2_prescriptions),
      medicaid_enrolment_quarter_avg = as.numeric(medicaid_enrolment_quarter_avg)
    )
}

rates <- pmap_dfr(rate_files, read_rate_file)

if (any(rates$year == 2020)) {
  stop("2020 is present in the plotting data.")
}

if (any(rates$state %in% c("PR", "XX"))) {
  stop("PR or XX is present in the plotting data.")
}

if (any(is.na(rates$medicaid_enrolment_quarter_avg))) {
  stop("Missing Medicaid enrolment in plotting data.")
}

message("Rows by definition:")
print(rates %>% count(definition, name = "n_rows"))

message("States per year-quarter:")
print(
  rates %>%
    filter(definition == "All SGLT2i products") %>%
    count(year, quarter, name = "n_states"),
  n = Inf
)

plot_theme <- theme_minimal(base_size = 11) +
  theme(
    plot.background = element_rect(fill = "white", color = NA),
    panel.background = element_rect(fill = "white", color = NA),
    legend.background = element_rect(fill = "white", color = NA),
    legend.box.background = element_rect(fill = "white", color = NA),
    panel.grid.minor = element_blank(),
    panel.grid.major = element_line(color = "grey88", linewidth = 0.25),
    strip.text = element_text(face = "bold", size = 8),
    axis.text.x = element_text(angle = 45, hjust = 1),
    plot.title.position = "plot",
    plot.caption.position = "plot",
    legend.position = "bottom"
  )

make_state_facet_plot <- function(data, definition_label, output_slug) {
  plot_data <- data %>%
    filter(definition == definition_label)

  p <- ggplot(
    plot_data,
    aes(x = quarter_date, y = sglt2_prescriptions_per_10000)
  ) +
    geom_line(color = "#2f5d7c", linewidth = 0.45, na.rm = TRUE) +
    geom_point(color = "#2f5d7c", size = 0.75, alpha = 0.8, na.rm = TRUE) +
    geom_vline(
      xintercept = as.numeric(ymd("2021-01-01")),
      color = "grey55",
      linewidth = 0.25,
      linetype = "dashed"
    ) +
    facet_wrap(~ state, ncol = 6, scales = "free_y") +
    scale_x_date(
      breaks = ymd(c("2015-01-01", "2017-01-01", "2019-01-01", "2021-01-01", "2023-01-01", "2025-01-01")),
      labels = date_format("%Y"),
      expand = expansion(mult = c(0.01, 0.03))
    ) +
    scale_y_continuous(labels = label_number(accuracy = 1)) +
    labs(
      title = paste0("Quarterly Medicaid SGLT2i Prescribing Rates by State: ", definition_label),
      subtitle = "Rates are prescriptions per 10,000 Medicaid enrollees. 2020 is excluded because the available SDUD source contains only Q4.",
      x = NULL,
      y = "Prescriptions per 10,000",
      caption = "Dashed line marks 2021 Q1. Y-axes are free within each state to make each state's trend visible."
    ) +
    plot_theme

  png_path <- here("figures", paste0("sglt2_quarterly_rate_state_facets_", output_slug, ".png"))
  pdf_path <- here("figures", paste0("sglt2_quarterly_rate_state_facets_", output_slug, ".pdf"))

  ggsave(png_path, p, width = 15, height = 18, dpi = 300)
  ggsave(pdf_path, p, width = 15, height = 18)

  c(png_path, pdf_path)
}

facet_outputs <- c(
  make_state_facet_plot(rates, "All SGLT2i products", "all_products"),
  make_state_facet_plot(rates, "Single-agent products", "single_agent"),
  make_state_facet_plot(rates, "Empagliflozin/dapagliflozin", "empa_dapa")
)

heatmap_data <- rates %>%
  filter(definition == "All SGLT2i products") %>%
  mutate(
    state = fct_reorder(
      state,
      sglt2_prescriptions_per_10000,
      .fun = median,
      .desc = TRUE,
      .na_rm = TRUE
    ),
    year_quarter = fct_inorder(year_quarter)
  )

heatmap_plot <- ggplot(
  heatmap_data,
  aes(x = year_quarter, y = state, fill = sglt2_prescriptions_per_10000)
) +
  geom_tile(color = "white", linewidth = 0.1) +
  scale_fill_viridis_c(
    option = "mako",
    direction = -1,
    labels = label_number(accuracy = 1),
    na.value = "grey90"
  ) +
  labs(
    title = "State-Quarter Medicaid SGLT2i Prescribing Rate Heatmap",
    subtitle = "All SGLT2i products; prescriptions per 10,000 Medicaid enrollees; 2020 excluded.",
    x = NULL,
    y = NULL,
    fill = "Rate"
  ) +
  theme_minimal(base_size = 10) +
  theme(
    plot.background = element_rect(fill = "white", color = NA),
    panel.background = element_rect(fill = "white", color = NA),
    legend.background = element_rect(fill = "white", color = NA),
    panel.grid = element_blank(),
    axis.text.x = element_text(angle = 90, hjust = 1, vjust = 0.5, size = 6),
    axis.text.y = element_text(size = 7),
    plot.title.position = "plot",
    legend.position = "right"
  )

heatmap_png <- here("figures", "sglt2_quarterly_rate_state_heatmap_all_products.png")
heatmap_pdf <- here("figures", "sglt2_quarterly_rate_state_heatmap_all_products.pdf")
ggsave(heatmap_png, heatmap_plot, width = 15, height = 12, dpi = 300)
ggsave(heatmap_pdf, heatmap_plot, width = 15, height = 12)

national_definition_trends <- rates %>%
  group_by(definition, year, quarter, quarter_date, year_quarter) %>%
  summarise(
    total_prescriptions = sum(sglt2_prescriptions, na.rm = TRUE),
    total_medicaid_enrolment = sum(medicaid_enrolment_quarter_avg, na.rm = TRUE),
    prescriptions_per_10000 = total_prescriptions / total_medicaid_enrolment * 10000,
    .groups = "drop"
  )

national_plot <- ggplot(
  national_definition_trends,
  aes(x = quarter_date, y = prescriptions_per_10000, color = definition)
) +
  geom_line(linewidth = 0.9) +
  geom_point(size = 1.6) +
  geom_vline(
    xintercept = as.numeric(ymd("2021-01-01")),
    color = "grey55",
    linewidth = 0.3,
    linetype = "dashed"
  ) +
  scale_color_manual(
    values = c(
      "All SGLT2i products" = "#1f5a7a",
      "Single-agent products" = "#6a8f2a",
      "Empagliflozin/dapagliflozin" = "#b0584f"
    )
  ) +
  scale_x_date(
    breaks = ymd(c("2015-01-01", "2017-01-01", "2019-01-01", "2021-01-01", "2023-01-01", "2025-01-01")),
    labels = date_format("%Y"),
    expand = expansion(mult = c(0.01, 0.03))
  ) +
  scale_y_continuous(labels = label_number(accuracy = 1)) +
  labs(
    title = "National Quarterly Medicaid SGLT2i Prescribing Rates by Product Definition",
    subtitle = "Rates are prescriptions per 10,000 Medicaid enrollees across the 50 states plus DC. 2020 excluded.",
    x = NULL,
    y = "Prescriptions per 10,000",
    color = NULL
  ) +
  plot_theme

national_png <- here("figures", "sglt2_national_quarterly_rate_trends_by_definition.png")
national_pdf <- here("figures", "sglt2_national_quarterly_rate_trends_by_definition.pdf")
ggsave(national_png, national_plot, width = 11, height = 6.5, dpi = 300)
ggsave(national_pdf, national_plot, width = 11, height = 6.5)

state_summary <- rates %>%
  filter(definition == "All SGLT2i products") %>%
  group_by(state) %>%
  summarise(
    first_observed_quarter = first(year_quarter[order(quarter_date)]),
    first_rate_per_10000 = first(sglt2_prescriptions_per_10000[order(quarter_date)]),
    latest_observed_quarter = last(year_quarter[order(quarter_date)]),
    latest_rate_per_10000 = last(sglt2_prescriptions_per_10000[order(quarter_date)]),
    absolute_change_per_10000 = latest_rate_per_10000 - first_rate_per_10000,
    fold_change = latest_rate_per_10000 / first_rate_per_10000,
    median_rate_per_10000 = median(sglt2_prescriptions_per_10000, na.rm = TRUE),
    max_rate_per_10000 = max(sglt2_prescriptions_per_10000, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  arrange(desc(latest_rate_per_10000))

summary_file <- here("output", "sglt2_state_quarter_rate_trend_summary_all_products_50dc_excluding_2020.csv")
write_csv(state_summary, summary_file)

message("Figures written:")
print(c(facet_outputs, heatmap_png, heatmap_pdf, national_png, national_pdf))

message("Summary file written:")
print(summary_file)
