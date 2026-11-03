if (!requireNamespace("here", quietly = TRUE)) {
  stop("Install the `here` package before running this script.", call. = FALSE)
}
source(here::here("scripts", "00_setup.R"))

product_file <- project_path("data_raw", "ndc_lookup", "product.txt")
package_file <- project_path("data_raw", "ndc_lookup", "package.txt")
output_file <- project_path("data_processed", "ndc_lookup", "sglt2_ndc_11_digit_list.csv")

require_files(c(product_file, package_file), "FDA NDC input file")

product <- readr::read_tsv(
  product_file,
  col_types = readr::cols(.default = readr::col_character()),
  show_col_types = FALSE
)

package <- readr::read_tsv(
  package_file,
  col_types = readr::cols(.default = readr::col_character()),
  show_col_types = FALSE
)

require_columns(
  product,
  c(
    "PRODUCTID",
    "PRODUCTNDC",
    "PROPRIETARYNAME",
    "NONPROPRIETARYNAME",
    "SUBSTANCENAME",
    "PHARM_CLASSES"
  ),
  "FDA product file"
)

require_columns(
  package,
  c("PRODUCTID", "PRODUCTNDC", "NDCPACKAGECODE", "PACKAGEDESCRIPTION"),
  "FDA package file"
)

sglt2_terms <- c(
  "CANAGLIFLOZIN",
  "DAPAGLIFLOZIN",
  "EMPAGLIFLOZIN",
  "ERTUGLIFLOZIN",
  "BEXAGLIFLOZIN",
  "SOTAGLIFLOZIN",
  "INVOKANA",
  "INVOKAMET",
  "FARXIGA",
  "XIGDUO",
  "JARDIANCE",
  "SYNJARDY",
  "GLYXAMBI",
  "TRIJARDY",
  "STEGLATRO",
  "SEGLUROMET",
  "STEGLUJAN",
  "BRENZAVVY",
  "INZIQ",
  "QTERN"
)

sglt2_pattern <- paste(sglt2_terms, collapse = "|")

ndc_to_11 <- function(ndc) {
  ndc <- stringr::str_trim(as.character(ndc))
  parts <- stringr::str_split(ndc, "-", simplify = TRUE)

  if (ncol(parts) != 3) {
    stop("FDA package NDC must contain three hyphenated parts.", call. = FALSE)
  }

  labeler <- parts[, 1]
  product_code <- parts[, 2]
  package_code <- parts[, 3]

  dplyr::case_when(
    nchar(labeler) == 4 & nchar(product_code) == 4 & nchar(package_code) == 2 ~
      paste0(stringr::str_pad(labeler, 5, side = "left", pad = "0"), product_code, package_code),
    nchar(labeler) == 5 & nchar(product_code) == 3 & nchar(package_code) == 2 ~
      paste0(labeler, stringr::str_pad(product_code, 4, side = "left", pad = "0"), package_code),
    nchar(labeler) == 5 & nchar(product_code) == 4 & nchar(package_code) == 1 ~
      paste0(labeler, product_code, stringr::str_pad(package_code, 2, side = "left", pad = "0")),
    TRUE ~ paste0(labeler, product_code, package_code)
  )
}

sglt2_products <- product |>
  dplyr::mutate(
    search_text = stringr::str_to_upper(
      paste(
        PRODUCTID,
        PRODUCTNDC,
        PROPRIETARYNAME,
        NONPROPRIETARYNAME,
        SUBSTANCENAME,
        PHARM_CLASSES,
        sep = " | "
      )
    )
  ) |>
  dplyr::filter(stringr::str_detect(search_text, sglt2_pattern)) |>
  dplyr::mutate(
    sglt2_drug = dplyr::case_when(
      stringr::str_detect(search_text, "EMPAGLIFLOZIN|JARDIANCE|SYNJARDY|GLYXAMBI|TRIJARDY") ~ "empagliflozin",
      stringr::str_detect(search_text, "DAPAGLIFLOZIN|FARXIGA|XIGDUO|QTERN") ~ "dapagliflozin",
      stringr::str_detect(search_text, "CANAGLIFLOZIN|INVOKANA|INVOKAMET") ~ "canagliflozin",
      stringr::str_detect(search_text, "ERTUGLIFLOZIN|STEGLATRO|SEGLUROMET|STEGLUJAN") ~ "ertugliflozin",
      stringr::str_detect(search_text, "BEXAGLIFLOZIN|BRENZAVVY") ~ "bexagliflozin",
      stringr::str_detect(search_text, "SOTAGLIFLOZIN|INZIQ") ~ "sotagliflozin",
      TRUE ~ "manual_check"
    )
  ) |>
  dplyr::distinct()

if (nrow(sglt2_products) == 0) {
  stop("No SGLT2 products were found in the FDA product file.", call. = FALSE)
}

sglt2_ndcs <- package |>
  dplyr::select(PRODUCTID, PRODUCTNDC, NDCPACKAGECODE, PACKAGEDESCRIPTION) |>
  dplyr::inner_join(
    sglt2_products |>
      dplyr::select(
        sglt2_drug,
        PRODUCTID,
        PRODUCTNDC,
        PROPRIETARYNAME,
        NONPROPRIETARYNAME,
        SUBSTANCENAME,
        DOSAGEFORMNAME,
        ROUTENAME,
        ACTIVE_NUMERATOR_STRENGTH,
        ACTIVE_INGRED_UNIT,
        STARTMARKETINGDATE,
        ENDMARKETINGDATE
      ),
    by = c("PRODUCTID", "PRODUCTNDC")
  ) |>
  dplyr::mutate(
    ndc_11 = stringr::str_pad(ndc_to_11(NDCPACKAGECODE), 11, side = "left", pad = "0"),
    active_currently = is.na(ENDMARKETINGDATE) | ENDMARKETINGDATE == "",
    combination_product = dplyr::case_when(
      stringr::str_detect(stringr::str_to_upper(NONPROPRIETARYNAME), "METFORMIN|LINAGLIPTIN|SITAGLIPTIN") ~ TRUE,
      stringr::str_detect(stringr::str_to_upper(PROPRIETARYNAME), "SYNJARDY|GLYXAMBI|TRIJARDY|XIGDUO|QTERN|INVOKAMET|SEGLUROMET|STEGLUJAN") ~ TRUE,
      TRUE ~ FALSE
    )
  ) |>
  dplyr::select(
    sglt2_drug,
    ndc_11,
    NDCPACKAGECODE,
    PRODUCTNDC,
    PRODUCTID,
    PROPRIETARYNAME,
    NONPROPRIETARYNAME,
    SUBSTANCENAME,
    DOSAGEFORMNAME,
    ROUTENAME,
    ACTIVE_NUMERATOR_STRENGTH,
    ACTIVE_INGRED_UNIT,
    PACKAGEDESCRIPTION,
    STARTMARKETINGDATE,
    ENDMARKETINGDATE,
    active_currently,
    combination_product
  ) |>
  dplyr::distinct() |>
  dplyr::arrange(sglt2_drug, PROPRIETARYNAME, NDCPACKAGECODE)

if (any(nchar(sglt2_ndcs$ndc_11) != 11)) {
  stop("At least one FDA NDC did not convert to 11 digits.", call. = FALSE)
}

if (anyDuplicated(sglt2_ndcs$ndc_11)) {
  stop("Final SGLT2 NDC lookup contains duplicate `ndc_11` values.", call. = FALSE)
}

safe_write_csv(sglt2_ndcs, output_file)

message("Wrote final NDC lookup: ", output_file)
message("Rows: ", nrow(sglt2_ndcs))
