library(tidyverse)
library(readxl)
library(janitor)
library(here)
library(skimr)
# Check project root
here()
list.files(here("data_raw"))
# ============================================================
# Build SGLT2 inhibitor 11-digit NDC list from FDA NDC files
# Files: product.txt and package.txt
# ============================================================


# File paths
product_file <- here("data_raw", "product.txt")
package_file <- here("data_raw", "package.txt")

# Check files exist
file.exists(product_file)
file.exists(package_file)

# Read files
product <- read_tsv(
  product_file,
  col_types = cols(.default = col_character()),
  show_col_types = FALSE
)

package <- read_tsv(
  package_file,
  col_types = cols(.default = col_character()),
  show_col_types = FALSE
)

# Check column names
names(product)
names(package)

# ============================================================
# Define SGLT2 inhibitor search terms
# ============================================================

sglt2_terms <- c(
  # Generic names
  "CANAGLIFLOZIN",
  "DAPAGLIFLOZIN",
  "EMPAGLIFLOZIN",
  "ERTUGLIFLOZIN",
  "BEXAGLIFLOZIN",
  "SOTAGLIFLOZIN",
  
  # Brand names
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

# ============================================================
# Find SGLT2i products in product.txt
# ============================================================

sglt2_products <- product %>%
  mutate(
    search_text = str_to_upper(
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
  ) %>%
  filter(str_detect(search_text, sglt2_pattern)) %>%
  mutate(
    sglt2_drug = case_when(
      str_detect(search_text, "EMPAGLIFLOZIN|JARDIANCE|SYNJARDY|GLYXAMBI|TRIJARDY") ~ "empagliflozin",
      str_detect(search_text, "DAPAGLIFLOZIN|FARXIGA|XIGDUO|QTERN") ~ "dapagliflozin",
      str_detect(search_text, "CANAGLIFLOZIN|INVOKANA|INVOKAMET") ~ "canagliflozin",
      str_detect(search_text, "ERTUGLIFLOZIN|STEGLATRO|SEGLUROMET|STEGLUJAN") ~ "ertugliflozin",
      str_detect(search_text, "BEXAGLIFLOZIN|BRENZAVVY") ~ "bexagliflozin",
      str_detect(search_text, "SOTAGLIFLOZIN|INZIQ") ~ "sotagliflozin",
      TRUE ~ "manual_check"
    )
  ) %>%
  distinct()

# Inspect products found
sglt2_products %>%
  count(sglt2_drug)

sglt2_products %>%
  select(
    sglt2_drug,
    PRODUCTID,
    PRODUCTNDC,
    PROPRIETARYNAME,
    NONPROPRIETARYNAME,
    SUBSTANCENAME,
    STARTMARKETINGDATE,
    ENDMARKETINGDATE
  ) %>%
  arrange(sglt2_drug, PROPRIETARYNAME) %>%
  print(n = 100)

# ============================================================
# Convert FDA hyphenated NDC package codes to 11-digit NDCs
# ============================================================

ndc_to_11 <- function(ndc) {
  ndc <- as.character(ndc)
  ndc <- str_trim(ndc)
  
  parts <- str_split(ndc, "-", simplify = TRUE)
  
  labeler <- parts[, 1]
  product_code <- parts[, 2]
  package_code <- parts[, 3]
  
  case_when(
    # 4-4-2 format -> add leading zero to labeler
    nchar(labeler) == 4 & nchar(product_code) == 4 & nchar(package_code) == 2 ~
      paste0(str_pad(labeler, 5, side = "left", pad = "0"), product_code, package_code),
    
    # 5-3-2 format -> add leading zero to product code
    nchar(labeler) == 5 & nchar(product_code) == 3 & nchar(package_code) == 2 ~
      paste0(labeler, str_pad(product_code, 4, side = "left", pad = "0"), package_code),
    
    # 5-4-1 format -> add leading zero to package code
    nchar(labeler) == 5 & nchar(product_code) == 4 & nchar(package_code) == 1 ~
      paste0(labeler, product_code, str_pad(package_code, 2, side = "left", pad = "0")),
    
    # already looks complete
    TRUE ~ paste0(labeler, product_code, package_code)
  )
}

# ============================================================
# Join SGLT2 products to package file
# ============================================================
sglt2_ndcs <- package %>%
  select(
    PRODUCTID,
    PRODUCTNDC,
    NDCPACKAGECODE,
    PACKAGEDESCRIPTION
  ) %>%
  inner_join(
    sglt2_products %>%
      select(
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
  ) %>%
  mutate(
    ndc_11 = ndc_to_11(NDCPACKAGECODE),
    ndc_11 = str_pad(ndc_11, width = 11, side = "left", pad = "0"),
    
    active_currently = if_else(
      is.na(ENDMARKETINGDATE) | ENDMARKETINGDATE == "",
      TRUE,
      FALSE
    ),
    
    combination_product = case_when(
      str_detect(str_to_upper(NONPROPRIETARYNAME), "METFORMIN|LINAGLIPTIN|SITAGLIPTIN") ~ TRUE,
      str_detect(str_to_upper(PROPRIETARYNAME), "SYNJARDY|GLYXAMBI|TRIJARDY|XIGDUO|QTERN|INVOKAMET|SEGLUROMET|STEGLUJAN") ~ TRUE,
      TRUE ~ FALSE
    )
  ) %>%
  select(
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
  ) %>%
  distinct() %>%
  arrange(sglt2_drug, PROPRIETARYNAME, NDCPACKAGECODE)



# Inspect NDCs found
sglt2_ndcs %>%
  count(sglt2_drug)

sglt2_ndcs %>%
  count(sglt2_drug, PROPRIETARYNAME, NONPROPRIETARYNAME, combination_product) %>%
  arrange(sglt2_drug, PROPRIETARYNAME) %>%
  print(n = 200)

# Check NDC length
sglt2_ndcs %>%
  mutate(ndc_length = nchar(ndc_11)) %>%
  count(ndc_length)

# ============================================================
# Save outputs
# ============================================================

dir.create(here("data_processed"), showWarnings = FALSE)

write_csv(
  sglt2_products,
  here("data_processed", "sglt2_products_found.csv")
)

write_csv(
  sglt2_ndcs,
  here("data_processed", "sglt2_ndc_11_digit_list.csv")
)

saveRDS(
  sglt2_ndcs,
  here("data_processed", "sglt2_ndc_11_digit_list.rds")
)

# Open in RStudio viewer
View(sglt2_products)
View(sglt2_ndcs)

names(sglt2_ndcs)
