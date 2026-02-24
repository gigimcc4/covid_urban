library(tidyverse)
library(arrow)

# Read in all three datasets
demographics <- read_csv("data/demographics.csv")
epidemiology <- read_csv("data/epidemiology.csv")
hospitalizations <- read_csv("data/hospitalizations.csv")

# Join epidemiology and hospitalizations on date + location_key,
# then join demographics on location_key
joined_data <- epidemiology %>%
  full_join(hospitalizations, by = c("date", "location_key")) %>%
  left_join(demographics, by = "location_key")

# Save as parquet for fast, memory-efficient access
write_parquet(joined_data, "data/joined_data.parquet")

cat("Joined data dimensions:", nrow(joined_data), "rows x", ncol(joined_data), "columns\n")
