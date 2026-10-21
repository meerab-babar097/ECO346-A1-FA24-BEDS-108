library(tidyverse)

# ---- 1. Your variant ----
REG_LAST2 <- 8                       # last two digits of FA24-BEDS-108
VARIANT   <- REG_LAST2 %% 8
prov      <- c(2, 2, 3, 3, 1, 1, 4, 4)[VARIANT + 1]   # prov_code per variant
area      <- c(1, 2, 1, 2, 1, 2, 1, 2)[VARIANT + 1]   # urban_rural per variant

# ---- 2. Read local copies ----
person <- read_csv("data/pslm_person_subset.csv", show_col_types = FALSE)
hh     <- read_csv("data/pslm_hh_subset.csv",     show_col_types = FALSE)

# ---- 3. Attach weight, province, area from the household file ----
hh_small <- hh %>% select(hhid, hhweight, prov_code, urban_rural)
stopifnot(!anyDuplicated(hh_small$hhid))      # one row per household

d <- person %>%
  inner_join(hh_small, by = "hhid") %>%
  filter(prov_code == prov, urban_rural == area)

# ---- 4. The two samples ----
lit_sample <- d %>% filter(age >= 10, age <= 64, !is.na(literate))
students   <- d %>% filter(ed_total > 0)

# ---- 5. Sanity checks ----
cat("Variant:", VARIANT, "| prov_code:", prov, "| urban_rural:", area, "\n")
cat("Persons in variant:", nrow(d), "\n")
cat("Literacy sample:", nrow(lit_sample), "\n")
cat("Students:", nrow(students), "\n")
cat("Missing weights:", sum(is.na(d$hhweight)), "\n")