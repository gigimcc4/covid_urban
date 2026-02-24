# COVID-19 Urbanization & Development Analysis

Exploratory analysis of how country-level development (HDI), urbanization, population density, and age structure relate to COVID-19 case rates and fatality outcomes across 182 countries.

## Key Finding

**Human Development Index (HDI) is the dominant predictor of reported COVID-19 case rates.** Urbanization, population density, and age structure add little predictive value once HDI is accounted for. This likely reflects the role of testing infrastructure — higher-HDI countries detected more cases per capita, which also deflated their apparent case fatality rates.

## Data

Source: [Google Health COVID-19 Open Data](https://health.google.com/covid-19/open-data/raw-data)

Three source datasets (not included in repo due to size):

| File | Description | Size |
|------|-------------|------|
| `demographics.csv` | Population, HDI, age structure, urbanization by location | 1.5 MB |
| `epidemiology.csv` | Daily confirmed cases, deaths, recoveries, testing | 521 MB |
| `hospitalizations.csv` | Daily hospitalization, ICU, ventilator counts | 66 MB |

These are joined into `joined_data.parquet` (~12.5M rows, 37 columns) by `join_data.R`.

See [`codebook.md`](codebook.md) for full variable definitions, types, and missingness rates.

### Joined Dataset Summary

| Metric | Value |
|--------|-------|
| Rows | 12,548,844 |
| Columns | 37 |
| Date range | 2020-01-01 to 2022-12-30 |
| Total locations | 20,906 |
| Country-level locations | 232 |

**Key variable coverage (% non-missing):**

| Variable | Coverage |
|----------|----------|
| `new_confirmed` | 99.4% |
| `new_deceased` | 93.0% |
| `population` | 97.0% |
| `new_recovered` | 31.7% |
| `new_tested` | 25.5% |
| `new_hospitalized_patients` | 13.1% |
| `human_development_index` | 41.6% |

**Note:** Recovery, testing, and hospitalization data have high missingness because many countries did not report these metrics. HDI and urbanization data are primarily available at the country level. Analyses in this project filter to country-level records where key variables are present.

## Scripts

| Script | Description |
|--------|-------------|
| `join_data.R` | Reads CSVs, joins on `location_key` and `date`, saves as parquet |
| `explore.R` | HDI vs case fatality rate and cases per 100k (EDA) |
| `explore_urbanization.R` | Urbanization and density vs case rates and early growth speed |
| `regression.R` | Frequentist multiple regression with diagnostics |
| `bayesian_regression.R` | Bayesian regression using `brms` with posterior summaries |
| `loo_comparison.R` | LOO cross-validation comparing 5 nested models |

## Analysis Summary

### Exploratory
- Higher-HDI countries reported far more cases per capita (r = 0.74) but had lower case fatality rates (r = -0.34)
- Urbanization correlated with case rates (r = 0.47) but this was largely confounded by HDI

### Multiple Regression
- HDI alone explains ~74% of variance in log case rates (R² = 0.74)
- Urbanization, density, and age structure are not significant after controlling for HDI

### Bayesian Regression
- HDI posterior: 10.73 [95% CI: 8.86, 12.60] — the only predictor whose credible interval excludes zero
- P(HDI effect > 0) = 100%

### LOO Cross-Validation
- **Best model: HDI + Urban** (ELPD = -261.1), essentially tied with HDI only (ELPD = -261.5)
- Adding density and age worsens out-of-sample prediction
- Stacking weights: ~48% HDI only, ~50% HDI + Urban, ~2% Urban only

## Plots

Located in `data/`:

| Plot | Description |
|------|-------------|
| `hdi_vs_cfr.png` | HDI vs case fatality rate scatterplot |
| `hdi_vs_cases_per_100k.png` | HDI vs cases per capita |
| `urban_pct_vs_cases.png` | Urban population share vs case rates |
| `density_vs_cases.png` | Population density vs case rates |
| `urban_vs_early_growth.png` | Urbanization vs days to reach 1,000 cases |
| `regression_diagnostics.png` | Residual diagnostic plots |
| `bayesian_intervals.png` | Posterior credible intervals |
| `bayesian_posteriors.png` | Posterior density distributions |
| `loo_comparison.png` | LOO-CV model comparison |

## Requirements

- R (>= 4.0)
- `tidyverse`, `arrow`, `brms`
