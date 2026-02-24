library(tidyverse)
library(arrow)

# ─────────────────────────────────────────────────────────────────────────────
# Research Question:
# Does a country's Human Development Index (HDI) relate to its COVID-19
# case fatality rate (CFR)? Do wealthier, more developed nations have
# lower fatality rates, or does higher detection inflate their case counts
# and mask true differences?
# ─────────────────────────────────────────────────────────────────────────────

joined <- open_dataset("data/joined_data.parquet")

# Summarise to country level: total cases, deaths, and demographics
country_summary <- joined %>%
  filter(nchar(location_key) == 2) %>%       # country-level rows only
  group_by(location_key) %>%
  summarise(
    total_confirmed = max(cumulative_confirmed, na.rm = TRUE),
    total_deceased  = max(cumulative_deceased, na.rm = TRUE),
    population      = max(population, na.rm = TRUE),
    hdi             = max(human_development_index, na.rm = TRUE),
    pct_age_60_plus = max(population_age_60_69, na.rm = TRUE) +
                      max(population_age_70_79, na.rm = TRUE) +
                      max(population_age_80_and_older, na.rm = TRUE)
  ) %>%
  collect() %>%
  mutate(
    cfr = total_deceased / total_confirmed * 100,  # case fatality rate (%)
    cases_per_100k = total_confirmed / population * 100000,
    pct_elderly = pct_age_60_plus / population * 100
  ) %>%
  filter(
    is.finite(cfr), cfr > 0, cfr < 30,            # remove extreme/invalid
    is.finite(hdi),
    total_confirmed >= 1000                        # minimum case threshold
  )

cat("Countries in analysis:", nrow(country_summary), "\n\n")

# Summary statistics
cat("--- Case Fatality Rate (%) ---\n")
print(summary(country_summary$cfr))

cat("\n--- HDI ---\n")
print(summary(country_summary$hdi))

# ─── Plot 1: HDI vs Case Fatality Rate ──────────────────────────────────────
p1 <- ggplot(country_summary, aes(x = hdi, y = cfr)) +
  geom_point(aes(size = population), alpha = 0.5, color = "steelblue") +
  geom_smooth(method = "loess", se = TRUE, color = "firebrick") +
  scale_size_continuous(labels = scales::comma, range = c(1, 10)) +
  labs(
    title = "Does Development Level Predict COVID-19 Fatality Rates?",
    subtitle = "Each point is a country (min 1,000 cases); size = population",
    x = "Human Development Index (HDI)",
    y = "Case Fatality Rate (%)",
    size = "Population"
  ) +
  theme_minimal()

ggsave("data/hdi_vs_cfr.png", p1, width = 10, height = 6, dpi = 150)
cat("\nPlot saved to data/hdi_vs_cfr.png\n")

# ─── Plot 2: HDI vs Cases per 100k (detection capacity) ─────────────────────
p2 <- ggplot(country_summary, aes(x = hdi, y = cases_per_100k)) +
  geom_point(aes(size = population), alpha = 0.5, color = "darkorange") +
  geom_smooth(method = "loess", se = TRUE, color = "firebrick") +
  scale_y_log10(labels = scales::comma) +
  scale_size_continuous(labels = scales::comma, range = c(1, 10)) +
  labs(
    title = "Higher HDI Countries Detected More Cases Per Capita",
    subtitle = "Suggests testing capacity drives reported case rates",
    x = "Human Development Index (HDI)",
    y = "Confirmed Cases per 100k (log scale)",
    size = "Population"
  ) +
  theme_minimal()

ggsave("data/hdi_vs_cases_per_100k.png", p2, width = 10, height = 6, dpi = 150)
cat("Plot saved to data/hdi_vs_cases_per_100k.png\n")

# ─── Correlation summary ────────────────────────────────────────────────────
cat("\n--- Correlations ---\n")
cat("HDI vs CFR:            ", round(cor(country_summary$hdi, country_summary$cfr, use = "complete.obs"), 3), "\n")
cat("HDI vs Cases per 100k: ", round(cor(country_summary$hdi, country_summary$cases_per_100k, use = "complete.obs"), 3), "\n")
cat("% Elderly vs CFR:      ", round(cor(country_summary$pct_elderly, country_summary$cfr, use = "complete.obs"), 3), "\n")
