if (!requireNamespace("here", quietly = TRUE)) {
  stop("Install the `here` package before running this script.", call. = FALSE)
}
source(here::here("scripts", "00_setup.R"))

# Checks every value reported in the manuscript (docs/manuscript_reported_values.csv)
# against the regenerated outputs. A value passes when the regenerated number,
# rounded to the printed precision, equals the printed number.

reference_file <- project_path("docs", "manuscript_reported_values.csv")
report_file <- project_path("docs", "logs", "manuscript_value_check.csv")
require_files(reference_file, "manuscript reference values")

reference <- readr::read_csv(reference_file, col_types = readr::cols(.default = readr::col_character()))

source_tables <- purrr::map(
  rlang::set_names(unique(reference$file)),
  ~ readr::read_csv(project_path(.x), col_types = readr::cols(.default = readr::col_character()))
)

decimal_places <- function(x) {
  ifelse(grepl("\\.", x), nchar(sub("^[^.]*\\.", "", x)), 0L)
}

lookup_value <- function(file, key_column, key_value, value_column, transform) {
  data <- source_tables[[file]]

  if (transform == "row_count") {
    return(as.character(nrow(data)))
  }

  # Composite keys are written as "col_a|col_b" with values "value_a|value_b".
  key_columns <- strsplit(key_column, "|", fixed = TRUE)[[1]]
  key_values <- strsplit(key_value, "|", fixed = TRUE)[[1]]
  matched <- data
  for (i in seq_along(key_columns)) {
    matched <- matched[matched[[key_columns[i]]] == key_values[i], , drop = FALSE]
  }
  if (nrow(matched) != 1 || !value_column %in% names(matched)) {
    return(NA_character_)
  }

  matched[[value_column]]
}

checks <- reference |>
  dplyr::mutate(
    regenerated = purrr::pmap_chr(
      list(file, key_column, key_value, value_column, transform),
      lookup_value
    ),
    passed = purrr::pmap_lgl(list(transform, reported, regenerated), function(transform, reported, regenerated) {
      if (is.na(regenerated)) {
        return(FALSE)
      }

      if (transform == "text") {
        return(identical(reported, regenerated))
      }

      if (transform == "yesno") {
        return(identical(reported, if (as.numeric(regenerated) == 1) "Yes" else "No"))
      }

      value <- as.numeric(regenerated)
      if (transform == "abs_percent_change") {
        value <- abs(value - 1) * 100
      }

      if (transform == "p_less_than") {
        return(value < as.numeric(reported))
      }

      tolerance <- 0.5 * 10^(-decimal_places(reported)) + 1e-9
      abs(value - as.numeric(reported)) <= tolerance
    })
  )

ensure_dir(dirname(report_file))
readr::write_csv(checks, report_file)

failures <- dplyr::filter(checks, !passed)
summary_counts <- dplyr::count(checks, source, passed)
print(summary_counts, n = Inf)

if (nrow(failures) > 0) {
  print(failures, n = Inf, width = Inf)
  stop(nrow(failures), " manuscript value(s) do not match the regenerated outputs.", call. = FALSE)
}

message("All ", nrow(checks), " manuscript-reported values match the regenerated outputs.")
