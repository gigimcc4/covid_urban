library(tidyverse)
library(arrow)
library(brms)

# ─────────────────────────────────────────────────────────────────────────────
# Bayesian Multiple Regression using brms
# Same model as frequentist: Log(Cases per 100k) ~ HDI + Urban + Density + Age
# ─────────────────────────────────────────────────────────────────────────────

joined <- open_dataset("data/joined_data.parquet")

# Build country-level dataset
country <- joined %>%
  filter(nchar(location_key) == 2) %>%
  group_by(location_key) %>%
  summarise(
    total_confirmed    = max(cumulative_confirmed, na.rm = TRUE),
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
    cases_per_100k = total_confirmed / population * 100000,
    pct_urban      = population_urban / (population_urban + population_rural) * 100,
    pct_elderly    = pop_60_plus / population * 100,
    log_density    = log(population_density),
    log_cases      = log(cases_per_100k)
  ) %>%
  filter(
    is.finite(log_cases),
    is.finite(pct_urban),
    is.finite(hdi),
    is.finite(log_density),
    is.finite(pct_elderly),
    total_confirmed >= 1000
  )

cat("Countries:", nrow(country), "\n\n")

# ─── Fit Bayesian model with weakly informative priors ───────────────────────
bayes_model <- brm(
  log_cases ~ pct_urban + hdi + log_density + pct_elderly,
  data    = country,
  family  = gaussian(),
  prior   = c(
    prior(normal(0, 5), class = "b"),        # weakly informative for coefficients
    prior(student_t(3, 0, 2.5), class = "sigma")  # weakly informative for residual SD
  ),
  chains  = 4,
  iter    = 4000,
  warmup  = 1000,
  seed    = 42,
  cores   = 4
)

# ─── Summary ─────────────────────────────────────────────────────────────────
cat("\n═══════════════════════════════════════════════════════════════════\n")
cat("BAYESIAN MODEL SUMMARY\n")
cat("═══════════════════════════════════════════════════════════════════\n\n")
print(summary(bayes_model))

# ─── Posterior intervals plot ────────────────────────────────────────────────
p1 <- mcmc_plot(bayes_model, type = "intervals", prob = 0.5, prob_outer = 0.95) +
  labs(
    title = "Bayesian Posterior Intervals for Predictors",
    subtitle = "Thick = 50% CI, thin = 95% CI; only HDI excludes zero"
  ) +
  theme_minimal()

ggsave("data/bayesian_intervals.png", p1, width = 10, height = 5, dpi = 150)
cat("Plot saved: data/bayesian_intervals.png\n")

# ─── Posterior distributions ─────────────────────────────────────────────────
p2 <- mcmc_plot(bayes_model, type = "areas", prob = 0.95) +
  labs(
    title = "Posterior Distributions of Model Parameters",
    subtitle = "Shaded region = 95% credible interval"
  ) +
  theme_minimal()

ggsave("data/bayesian_posteriors.png", p2, width = 10, height = 6, dpi = 150)
cat("Plot saved: data/bayesian_posteriors.png\n")

# ─── Hypothesis testing: probability that HDI effect is positive ─────────────
cat("\n═══════════════════════════════════════════════════════════════════\n")
cat("HYPOTHESIS TESTS\n")
cat("═══════════════════════════════════════════════════════════════════\n\n")
print(hypothesis(bayes_model, "hdi > 0"))
print(hypothesis(bayes_model, "pct_urban < 0"))
