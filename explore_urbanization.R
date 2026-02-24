library(tidyverse)
library(arrow)

# ─────────────────────────────────────────────────────────────────────────────
# Research Question:
# How did urbanization affect COVID-19 spread? Did countries with higher
# urban population share or population density see faster early case growth?
# ─────────────────────────────────────────────────────────────────────────────

joined <- open_dataset("data/joined_data.parquet")

# ─── Part 1: Country-level urbanization vs total case burden ─────────────────

country_urban <- joined %>%
  filter(nchar(location_key) == 2) %>%
  group_by(location_key) %>%
  summarise(
    total_confirmed   = max(cumulative_confirmed, na.rm = TRUE),
    population        = max(population, na.rm = TRUE),
    population_urban  = max(population_urban, na.rm = TRUE),
    population_rural  = max(population_rural, na.rm = TRUE),
    population_density = max(population_density, na.rm = TRUE),
    hdi               = max(human_development_index, na.rm = TRUE)
  ) %>%
  collect() %>%
  mutate(
    pct_urban = population_urban / (population_urban + population_rural) * 100,
    cases_per_100k = total_confirmed / population * 100000
  ) %>%
  filter(
    is.finite(pct_urban),
    is.finite(cases_per_100k),
    total_confirmed >= 1000
  )

cat("Countries in urbanization analysis:", nrow(country_urban), "\n\n")

# ─── Plot 1: % Urban vs Cases per 100k ──────────────────────────────────────
p1 <- ggplot(country_urban, aes(x = pct_urban, y = cases_per_100k)) +
  geom_point(aes(size = population), alpha = 0.5, color = "steelblue") +
  geom_smooth(method = "loess", se = TRUE, color = "firebrick") +
  scale_y_log10(labels = scales::comma) +
  scale_size_continuous(labels = scales::comma, range = c(1, 10)) +
  labs(
    title = "More Urbanized Countries Reported Higher COVID-19 Case Rates",
    subtitle = "Each point is a country (min 1,000 cases); size = population",
    x = "Urban Population Share (%)",
    y = "Confirmed Cases per 100k (log scale)",
    size = "Population"
  ) +
  theme_minimal()

ggsave("data/urban_pct_vs_cases.png", p1, width = 10, height = 6, dpi = 150)
cat("Plot saved: data/urban_pct_vs_cases.png\n")

# ─── Plot 2: Population Density vs Cases per 100k ───────────────────────────
p2 <- ggplot(country_urban %>% filter(is.finite(population_density)),
             aes(x = population_density, y = cases_per_100k)) +
  geom_point(aes(size = population), alpha = 0.5, color = "darkorange") +
  geom_smooth(method = "loess", se = TRUE, color = "firebrick") +
  scale_x_log10(labels = scales::comma) +
  scale_y_log10(labels = scales::comma) +
  scale_size_continuous(labels = scales::comma, range = c(1, 10)) +
  labs(
    title = "Population Density Shows a Weaker Link to Case Rates",
    subtitle = "Density alone doesn't predict spread as well as urbanization",
    x = "Population Density (people/km², log scale)",
    y = "Confirmed Cases per 100k (log scale)",
    size = "Population"
  ) +
  theme_minimal()

ggsave("data/density_vs_cases.png", p2, width = 10, height = 6, dpi = 150)
cat("Plot saved: data/density_vs_cases.png\n")

# ─── Part 2: Early growth speed by urbanization ─────────────────────────────
# How many days from first case to 1,000 cumulative cases?

early_growth <- joined %>%
  filter(
    nchar(location_key) == 2,
    cumulative_confirmed >= 1
  ) %>%
  select(date, location_key, cumulative_confirmed,
         population, population_urban, population_rural, population_density) %>%
  collect() %>%
  group_by(location_key) %>%
  arrange(date) %>%
  summarise(
    first_case_date   = min(date),
    date_hit_1000     = min(date[cumulative_confirmed >= 1000], na.rm = TRUE),
    population        = max(population, na.rm = TRUE),
    population_urban  = max(population_urban, na.rm = TRUE),
    population_rural  = max(population_rural, na.rm = TRUE),
    population_density = max(population_density, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  mutate(
    days_to_1000 = as.numeric(date_hit_1000 - first_case_date),
    pct_urban = population_urban / (population_urban + population_rural) * 100
  ) %>%
  filter(is.finite(days_to_1000), is.finite(pct_urban), days_to_1000 > 0)

# ─── Plot 3: Urbanization vs speed to 1,000 cases ───────────────────────────
p3 <- ggplot(early_growth, aes(x = pct_urban, y = days_to_1000)) +
  geom_point(aes(size = population), alpha = 0.5, color = "purple4") +
  geom_smooth(method = "loess", se = TRUE, color = "firebrick") +
  scale_size_continuous(labels = scales::comma, range = c(1, 10)) +
  labs(
    title = "Did Urban Countries Reach 1,000 Cases Faster?",
    subtitle = "Days from first confirmed case to 1,000 cumulative cases",
    x = "Urban Population Share (%)",
    y = "Days to Reach 1,000 Cases",
    size = "Population"
  ) +
  theme_minimal()

ggsave("data/urban_vs_early_growth.png", p3, width = 10, height = 6, dpi = 150)
cat("Plot saved: data/urban_vs_early_growth.png\n")

# ─── Correlations ────────────────────────────────────────────────────────────
cat("\n--- Correlations ---\n")
cat("% Urban vs Cases/100k:     ", round(cor(country_urban$pct_urban, country_urban$cases_per_100k, use = "complete.obs"), 3), "\n")
cat("Pop Density vs Cases/100k: ", round(cor(log(country_urban$population_density), country_urban$cases_per_100k, use = "complete.obs"), 3), "\n")
cat("% Urban vs Days to 1,000:  ", round(cor(early_growth$pct_urban, early_growth$days_to_1000, use = "complete.obs"), 3), "\n")
