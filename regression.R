library(tidyverse)
library(arrow)

# ─────────────────────────────────────────────────────────────────────────────
# Multiple Regression: What country-level factors predict COVID-19 case rates
# after controlling for confounders?
# ─────────────────────────────────────────────────────────────────────────────

joined <- open_dataset("data/joined_data.parquet")

# Build country-level dataset with all predictors
country <- joined %>%
  filter(nchar(location_key) == 2) %>%
  group_by(location_key) %>%
  summarise(
    total_confirmed    = max(cumulative_confirmed, na.rm = TRUE),
    total_deceased     = max(cumulative_deceased, na.rm = TRUE),
    population         = max(population, na.rm = TRUE),
    population_urban   = max(population_urban, na.rm = TRUE),
    population_rural   = max(population_rural, na.rm = TRUE),
    population_density = max(population_density, na.rm = TRUE),
    hdi                = max(human_development_index, na.rm = TRUE),
    pop_60_plus        = max(population_age_60_69, na.rm = TRUE) +
                         max(population_age_70_79, na.rm = TRUE) +
                         max(population_age_80_and_older, na.rm = TRUE)
  ) %>%
  collect() %>%
  mutate(
    cases_per_100k  = total_confirmed / population * 100000,
    deaths_per_100k = total_deceased / population * 100000,
    cfr             = total_deceased / total_confirmed * 100,
    pct_urban       = population_urban / (population_urban + population_rural) * 100,
    pct_elderly     = pop_60_plus / population * 100,
    log_density     = log(population_density),
    log_cases       = log(cases_per_100k)
  ) %>%
  filter(
    is.finite(log_cases),
    is.finite(pct_urban),
    is.finite(hdi),
    is.finite(log_density),
    is.finite(pct_elderly),
    total_confirmed >= 1000
  )

cat("Countries in regression:", nrow(country), "\n\n")

# ─── Model 1: Cases per 100k (log) ~ urbanization + HDI + density + age ─────
model1 <- lm(log_cases ~ pct_urban + hdi + log_density + pct_elderly, data = country)

cat("═══════════════════════════════════════════════════════════════════\n")
cat("MODEL 1: Log(Cases per 100k) ~ Urbanization + HDI + Density + Age\n")
cat("═══════════════════════════════════════════════════════════════════\n\n")
print(summary(model1))

# ─── Model 2: CFR ~ urbanization + HDI + density + age ──────────────────────
country_cfr <- country %>%
  filter(is.finite(cfr), cfr > 0, cfr < 30)

model2 <- lm(cfr ~ pct_urban + hdi + log_density + pct_elderly, data = country_cfr)

cat("\n═══════════════════════════════════════════════════════════════════\n")
cat("MODEL 2: Case Fatality Rate ~ Urbanization + HDI + Density + Age\n")
cat("═══════════════════════════════════════════════════════════════════\n\n")
print(summary(model2))

# ─── Diagnostic plots for Model 1 ───────────────────────────────────────────
png("data/regression_diagnostics.png", width = 1200, height = 1000, res = 150)
par(mfrow = c(2, 2))
plot(model1)
dev.off()
cat("\nDiagnostic plots saved: data/regression_diagnostics.png\n")

# ─── Standardized coefficients for easier comparison ─────────────────────────
cat("\n═══════════════════════════════════════════════════════════════════\n")
cat("STANDARDIZED COEFFICIENTS (Model 1) — comparable effect sizes\n")
cat("═══════════════════════════════════════════════════════════════════\n\n")

country_scaled <- country %>%
  mutate(across(c(pct_urban, hdi, log_density, pct_elderly, log_cases), scale))

model1_std <- lm(log_cases ~ pct_urban + hdi + log_density + pct_elderly, data = country_scaled)
std_coefs <- broom::tidy(model1_std, conf.int = TRUE) %>%
  filter(term != "(Intercept)") %>%
  select(term, estimate, conf.low, conf.high, p.value) %>%
  arrange(desc(abs(estimate)))

print(std_coefs)
