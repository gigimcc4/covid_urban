library(tidyverse)
library(arrow)
library(brms)

# ─────────────────────────────────────────────────────────────────────────────
# LOO Cross-Validation: Compare competing Bayesian models
# Which set of predictors best explains COVID-19 case rates?
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

# Shared sampling settings
shared <- list(
  family = gaussian(),
  data   = country,
  prior  = c(
    prior(normal(0, 5), class = "b"),
    prior(student_t(3, 0, 2.5), class = "sigma")
  ),
  chains = 4, iter = 4000, warmup = 1000, seed = 42, cores = 4
)

# ─── Model 1: HDI only ──────────────────────────────────────────────────────
cat("Fitting Model 1: HDI only\n")
m1 <- do.call(brm, c(list(formula = log_cases ~ hdi), shared))

# ─── Model 2: HDI + Urbanization ─────────────────────────────────────────────
cat("Fitting Model 2: HDI + Urban\n")
m2 <- do.call(brm, c(list(formula = log_cases ~ hdi + pct_urban), shared))

# ─── Model 3: HDI + Urbanization + Density ───────────────────────────────────
cat("Fitting Model 3: HDI + Urban + Density\n")
m3 <- do.call(brm, c(list(formula = log_cases ~ hdi + pct_urban + log_density), shared))

# ─── Model 4: Full model (HDI + Urban + Density + Age) ──────────────────────
cat("Fitting Model 4: Full model\n")
m4 <- do.call(brm, c(list(formula = log_cases ~ hdi + pct_urban + log_density + pct_elderly), shared))

# ─── Model 5: Urbanization only (no HDI) — for contrast ─────────────────────
cat("Fitting Model 5: Urban only\n")
m5 <- do.call(brm, c(list(formula = log_cases ~ pct_urban), shared))

# ─── Compute LOO for each model ─────────────────────────────────────────────
cat("\nComputing LOO-CV...\n\n")
loo1 <- loo(m1)
loo2 <- loo(m2)
loo3 <- loo(m3)
loo4 <- loo(m4)
loo5 <- loo(m5)

# ─── Compare all models ─────────────────────────────────────────────────────
cat("═══════════════════════════════════════════════════════════════════\n")
cat("LOO-CV MODEL COMPARISON (higher ELPD = better)\n")
cat("═══════════════════════════════════════════════════════════════════\n\n")

comparison <- loo_compare(loo1, loo2, loo3, loo4, loo5)
print(comparison)

cat("\n═══════════════════════════════════════════════════════════════════\n")
cat("MODEL WEIGHTS (stacking)\n")
cat("═══════════════════════════════════════════════════════════════════\n\n")

weights <- model_weights(m1, m2, m3, m4, m5, weights = "stacking")
print(round(weights, 3))

# ─── Individual LOO summaries ────────────────────────────────────────────────
cat("\n═══════════════════════════════════════════════════════════════════\n")
cat("INDIVIDUAL MODEL ELPD ESTIMATES\n")
cat("═══════════════════════════════════════════════════════════════════\n\n")

models <- list(
  "M1: HDI only"              = loo1,
  "M2: HDI + Urban"           = loo2,
  "M3: HDI + Urban + Density" = loo3,
  "M4: Full"                  = loo4,
  "M5: Urban only"            = loo5
)
for (nm in names(models)) {
  est <- models[[nm]]$estimates
  cat(sprintf("%-30s  ELPD = %7.1f (SE = %.1f)   p_loo = %.1f\n",
              nm, est["elpd_loo","Estimate"], est["elpd_loo","SE"],
              est["p_loo","Estimate"]))
}

# ─── Visualization ───────────────────────────────────────────────────────────
comp_df <- as.data.frame(comparison) %>%
  rownames_to_column("model") %>%
  mutate(
    label = c("M1: HDI only", "M2: HDI + Urban", "M3: HDI + Urban + Density",
              "M4: Full", "M5: Urban only")[match(model, c("m1","m2","m3","m4","m5"))],
    label = fct_reorder(label, elpd_diff)
  )

p <- ggplot(comp_df, aes(x = elpd_diff, y = label)) +
  geom_point(size = 3, color = "steelblue") +
  geom_errorbarh(aes(xmin = elpd_diff - se_diff, xmax = elpd_diff + se_diff),
                 height = 0.2, color = "steelblue") +
  geom_vline(xintercept = 0, linetype = "dashed", color = "gray50") +
  labs(
    title = "LOO-CV Model Comparison",
    subtitle = "Difference in ELPD relative to best model (0 = best); error bars = 1 SE",
    x = "ELPD Difference (relative to best model)",
    y = NULL
  ) +
  theme_minimal()

ggsave("data/loo_comparison.png", p, width = 10, height = 5, dpi = 150)
cat("\nPlot saved: data/loo_comparison.png\n")
