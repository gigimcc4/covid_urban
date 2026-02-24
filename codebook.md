# Codebook: Joined COVID-19 Dataset

## Overview

- **File:** `data/joined_data.parquet`
- **Rows:** 12,548,844
- **Columns:** 37
- **Grain:** One row per location per date
- **Source:** [Google Health COVID-19 Open Data](https://health.google.com/covid-19/open-data/raw-data)

## Join Keys

| Variable | Type | Description |
|----------|------|-------------|
| `date` | date | Observation date (range: 2020-01-01 to 2022-12-30) |
| `location_key` | string | Location identifier. 2-letter = country (e.g. `US`), longer codes = subnational (e.g. `US_CA`). 232 countries, 20,906 total locations. |

## Epidemiology Variables

Sourced from `epidemiology.csv`. Daily counts and running totals of confirmed cases, deaths, recoveries, and tests.

| Variable | Type | Description | % Missing |
|----------|------|-------------|-----------|
| `new_confirmed` | double | New confirmed cases on this date | 0.6% |
| `new_deceased` | double | New deaths on this date | 7.0% |
| `new_recovered` | double | New recoveries on this date | 68.3% |
| `new_tested` | double | New tests administered on this date | 74.5% |
| `cumulative_confirmed` | double | Total confirmed cases up to this date | 1.8% |
| `cumulative_deceased` | double | Total deaths up to this date | 8.6% |
| `cumulative_recovered` | double | Total recoveries up to this date | 68.2% |
| `cumulative_tested` | double | Total tests up to this date | 76.0% |

**Notes:** Recovery and testing data are sparse because many countries did not report these metrics consistently.

## Hospitalization Variables

Sourced from `hospitalizations.csv`. Daily hospital, ICU, and ventilator utilization.

| Variable | Type | Description | % Missing |
|----------|------|-------------|-----------|
| `new_hospitalized_patients` | double | New hospital admissions on this date | 86.9% |
| `cumulative_hospitalized_patients` | double | Total hospitalizations up to this date | 86.9% |
| `current_hospitalized_patients` | double | Patients currently hospitalized | 98.5% |
| `new_intensive_care_patients` | double | New ICU admissions on this date | 90.9% |
| `cumulative_intensive_care_patients` | double | Total ICU admissions up to this date | 90.9% |
| `current_intensive_care_patients` | double | Patients currently in ICU | 98.5% |
| `new_ventilator_patients` | double | New patients on ventilators on this date | 99.9% |
| `cumulative_ventilator_patients` | double | Total ventilator patients up to this date | 99.9% |
| `current_ventilator_patients` | double | Patients currently on ventilators | 99.6% |

**Notes:** Hospitalization data was only reported by a subset of countries. Ventilator data is almost entirely missing. Use with caution and check per-country availability before analysis.

## Demographic Variables

Sourced from `demographics.csv`. Static population characteristics per location (no date dimension — values are repeated across all dates for a given location).

### Population Counts

| Variable | Type | Description | % Missing |
|----------|------|-------------|-----------|
| `population` | double | Total population | 3.0% |
| `population_male` | double | Male population | 17.7% |
| `population_female` | double | Female population | 17.7% |
| `population_rural` | double | Rural population | 98.3% |
| `population_urban` | double | Urban population | 98.3% |
| `population_largest_city` | double | Population of the largest city | 98.8% |
| `population_clustered` | double | Population living in clustered areas | 99.0% |
| `population_density` | double | People per km² | 92.6% |

**Notes:** Rural/urban splits and density are available primarily at the country level. Subnational locations are mostly missing these fields, which inflates the overall missingness percentages.

### Development Index

| Variable | Type | Description | % Missing |
|----------|------|-------------|-----------|
| `human_development_index` | double | UN Human Development Index (0–1 scale). Higher = more developed. Range in data: 0.354–0.957. | 58.4% |

### Age Distribution

| Variable | Type | Description | % Missing |
|----------|------|-------------|-----------|
| `population_age_00_09` | double | Population aged 0–9 | 18.4% |
| `population_age_10_19` | double | Population aged 10–19 | 18.4% |
| `population_age_20_29` | double | Population aged 20–29 | 18.4% |
| `population_age_30_39` | double | Population aged 30–39 | 18.4% |
| `population_age_40_49` | double | Population aged 40–49 | 18.4% |
| `population_age_50_59` | double | Population aged 50–59 | 18.4% |
| `population_age_60_69` | double | Population aged 60–69 | 18.4% |
| `population_age_70_79` | double | Population aged 70–79 | 18.4% |
| `population_age_80_and_older` | double | Population aged 80+ | 18.5% |

## Derived Variables Used in Analysis

These are not in the parquet file but are computed in the R scripts:

| Variable | Formula | Description |
|----------|---------|-------------|
| `cases_per_100k` | `total_confirmed / population * 100000` | Cumulative cases per 100,000 people |
| `deaths_per_100k` | `total_deceased / population * 100000` | Cumulative deaths per 100,000 people |
| `cfr` | `total_deceased / total_confirmed * 100` | Case fatality rate (%) |
| `pct_urban` | `population_urban / (population_urban + population_rural) * 100` | Urban population share (%) |
| `pct_elderly` | `(pop_60_69 + pop_70_79 + pop_80_plus) / population * 100` | Share of population aged 60+ (%) |
| `log_cases` | `log(cases_per_100k)` | Natural log of cases per 100k (used as regression outcome) |
| `log_density` | `log(population_density)` | Natural log of population density |
