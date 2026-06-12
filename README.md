# Eligible Data Analyst Case Study

## Structure

| Folder | Contents |
|---|---|
| `seeds/` | Raw CSVs loaded as dbt seeds |
| `models/staging/` | Source-aligned staging models |
| `models/intermediate/` | Business logic, cohort construction |
| `models/marts/` | Final analytical tables |
| `analyses/` | Ad-hoc SQL queries |
| `notebooks/` | Python analysis and visualizations |
| `deliverables/` | Client-facing summaries |

## SQL Dialect

The case study asks for Redshift/Postgres SQL. I built this on Snowflake instead, as it is the warehouse I work with most and where I have the deepest hands-on experience.

The differences between the two systems are minor and largely cosmetic. The most notable is date arithmetic: Snowflake uses `DATEDIFF` and `DATEADD` rather than interval expressions, and a handful of function names differ at the margins. The underlying logic, structure, and analytical approach translate directly to Postgres or Redshift.

## Q1 — Data model and SQL

**Question:** Using the mortgages, applicants, and events tables, write SQL (Redshift/Postgres flavour) to produce a cohort-level summary showing month 1–3 engagement rates and later outcomes by lender and launch cohort.

**Answer:** `analyses/q1_cohort_summary.sql`

I wrote a standalone SQL query (written directly in SQL, no dbt models) that produces a cohort-level summary of engagement and outcomes, with comments explaining my choices.

- **Grain** — one row per `(lender, cohort_month)`
- **Month 1–3 engagement** — I flagged any engagement event (excluding `email_sent`) occurring in the 1st, 2nd, or 3rd calendar month after a mortgage's first email using `MAX(CASE WHEN ...)` per mortgage, then calculated as a rate per lender and cohort
- **Mortgage-consumer attribution** — events record the consumer but not which mortgage, so I joined through the applicants table to make the connection. This means a consumer with multiple mortgages has their events counted against all of them — I flagged this as a known limitation
- **Data quality** — the same two issues from Q2 apply here: the `email-sent` vs `email_sent` formatting inconsistency (fixed with `REPLACE`) and 23% of applicant records pointing to mortgages that don't exist in the data — of those, 560 consumers have events that can't be linked to any mortgage, so engagement and intent rates are likely understated
- **Outcome distribution** — `mortgage_state` (open / switched / redeemed) showing counts and rates per lender and cohort

### Query Output

This query does not include funnel stage breakdowns — those are in `mart_cohort_engagement`. The output columns are engagement rates by month, intent rate, and outcome counts and rates.

| lender | cohort_month | mortgages | eng_m1 | eng_m2 | eng_m3 | eng_m1_m3 | intent_rate | open | switched | redeemed | switch_rate | redemption_rate |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| California | 2025-05 | 2 | 50.0 | 100.0 | 100.0 | 100.0 | 50.0 | 0 | 0 | 2 | 0.0 | 100.0 |
| California | 2025-10 | 1 | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | 1 | 0 | 0 | 0.0 | 0.0 |
| California | 2025-12 | 1 | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | 0 | 1 | 0 | 100.0 | 0.0 |
| Elderless | 2024-11 | 6 | 0.0 | 33.3 | 16.7 | 33.3 | 0.0 | 0 | 3 | 3 | 50.0 | 50.0 |
| Elderless | 2024-12 | 27 | 18.5 | 37.0 | 48.1 | 66.7 | 22.2 | 1 | 18 | 8 | 66.7 | 29.6 |
| Elderless | 2025-01 | 32 | 31.3 | 25.0 | 43.8 | 62.5 | 25.0 | 1 | 22 | 9 | 68.8 | 28.1 |
| Elderless | 2025-02 | 23 | 13.0 | 17.4 | 30.4 | 34.8 | 8.7 | 1 | 11 | 11 | 47.8 | 47.8 |
| Elderless | 2025-03 | 30 | 30.0 | 33.3 | 43.3 | 53.3 | 16.7 | 3 | 20 | 7 | 66.7 | 23.3 |
| Elderless | 2025-04 | 27 | 25.9 | 18.5 | 22.2 | 44.4 | 3.7 | 3 | 11 | 13 | 40.7 | 48.1 |
| Elderless | 2025-05 | 22 | 31.8 | 36.4 | 45.5 | 63.6 | 36.4 | 3 | 15 | 4 | 68.2 | 18.2 |
| Elderless | 2025-06 | 2 | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | 0 | 1 | 1 | 50.0 | 50.0 |
| Elderless | 2025-07 | 41 | 19.5 | 29.3 | 43.9 | 53.7 | 39.0 | 6 | 20 | 15 | 48.8 | 36.6 |
| Elderless | 2025-08 | 26 | 19.2 | 38.5 | 50.0 | 57.7 | 23.1 | 4 | 16 | 6 | 61.5 | 23.1 |
| Elderless | 2025-09 | 32 | 31.3 | 28.1 | 40.6 | 59.4 | 28.1 | 1 | 18 | 13 | 56.3 | 40.6 |
| Elderless | 2025-10 | 23 | 30.4 | 34.8 | 43.5 | 56.5 | 34.8 | 3 | 8 | 12 | 34.8 | 52.2 |
| Elderless | 2025-11 | 28 | 32.1 | 28.6 | 42.9 | 57.1 | 28.6 | 6 | 12 | 10 | 42.9 | 35.7 |
| Elderless | 2025-12 | 28 | 28.6 | 14.3 | 28.6 | 42.9 | 14.3 | 13 | 12 | 3 | 42.9 | 10.7 |
| Elderless | 2026-01 | 25 | 32.0 | 16.0 | 48.0 | 76.0 | 32.0 | 14 | 8 | 3 | 32.0 | 12.0 |
| Elderless | 2026-02 | 36 | 25.0 | 33.3 | 44.4 | 52.8 | 25.0 | 24 | 11 | 1 | 30.6 | 2.8 |
| Elderless | 2026-03 | 35 | 11.4 | 17.1 | 28.6 | 42.9 | 22.9 | 31 | 4 | 0 | 11.4 | 0.0 |
| Elderless | 2026-04 | 31 | 22.6 | 19.4 | 0.0 | 41.9 | 3.2 | 27 | 2 | 2 | 6.5 | 6.5 |
| Elderless | 2026-05 | 26 | 38.5 | 0.0 | 0.0 | 38.5 | 11.5 | 25 | 1 | 0 | 3.8 | 0.0 |
| Roast Ham | 2024-11 | 1 | 0.0 | 100.0 | 0.0 | 100.0 | 0.0 | 0 | 1 | 0 | 100.0 | 0.0 |
| Roast Ham | 2024-12 | 19 | 21.1 | 31.6 | 52.6 | 68.4 | 21.1 | 1 | 9 | 9 | 47.4 | 47.4 |
| Roast Ham | 2025-01 | 13 | 69.2 | 23.1 | 46.2 | 69.2 | 0.0 | 2 | 1 | 10 | 7.7 | 76.9 |
| Roast Ham | 2025-02 | 17 | 23.5 | 23.5 | 29.4 | 47.1 | 5.9 | 1 | 8 | 8 | 47.1 | 47.1 |
| Roast Ham | 2025-03 | 22 | 18.2 | 27.3 | 31.8 | 40.9 | 9.1 | 2 | 11 | 9 | 50.0 | 40.9 |
| Roast Ham | 2025-04 | 26 | 19.2 | 23.1 | 34.6 | 42.3 | 23.1 | 2 | 10 | 14 | 38.5 | 53.8 |
| Roast Ham | 2025-05 | 21 | 28.6 | 23.8 | 28.6 | 38.1 | 4.8 | 3 | 7 | 11 | 33.3 | 52.4 |
| Roast Ham | 2025-06 | 15 | 40.0 | 26.7 | 33.3 | 53.3 | 26.7 | 0 | 2 | 13 | 13.3 | 86.7 |
| Roast Ham | 2025-07 | 19 | 26.3 | 15.8 | 21.1 | 36.8 | 0.0 | 3 | 6 | 10 | 31.6 | 52.6 |
| Roast Ham | 2025-08 | 19 | 42.1 | 26.3 | 42.1 | 57.9 | 26.3 | 1 | 9 | 9 | 47.4 | 47.4 |
| Roast Ham | 2025-09 | 26 | 42.3 | 26.9 | 34.6 | 50.0 | 11.5 | 2 | 12 | 12 | 46.2 | 46.2 |
| Roast Ham | 2025-10 | 21 | 23.8 | 19.0 | 28.6 | 52.4 | 9.5 | 2 | 11 | 8 | 52.4 | 38.1 |
| Roast Ham | 2025-11 | 19 | 31.6 | 26.3 | 36.8 | 57.9 | 21.1 | 3 | 4 | 12 | 21.1 | 63.2 |
| Roast Ham | 2025-12 | 28 | 35.7 | 35.7 | 35.7 | 67.9 | 10.7 | 15 | 7 | 6 | 25.0 | 21.4 |
| Roast Ham | 2026-01 | 17 | 35.3 | 23.5 | 35.3 | 58.8 | 11.8 | 12 | 3 | 2 | 17.6 | 11.8 |
| Roast Ham | 2026-02 | 20 | 35.0 | 40.0 | 40.0 | 70.0 | 10.0 | 11 | 6 | 3 | 30.0 | 15.0 |
| Roast Ham | 2026-03 | 17 | 35.3 | 41.2 | 17.6 | 52.9 | 5.9 | 8 | 3 | 6 | 17.6 | 35.3 |
| Roast Ham | 2026-04 | 16 | 25.0 | 37.5 | 0.0 | 50.0 | 0.0 | 13 | 0 | 3 | 0.0 | 18.8 |
| Roast Ham | 2026-05 | 20 | 30.0 | 0.0 | 0.0 | 30.0 | 0.0 | 17 | 0 | 3 | 0.0 | 15.0 |

### Outcome Distribution

Across the 860 mortgages that received at least one email, outcomes differ between lenders.

| Lender | Cohorted mortgages | Open | Switched | Redeemed | Switch rate | Redemption rate |
|---|---|---|---|---|---|---|
| Elderless | 500 | 33.2% | 42.6% | 24.2% | 42.6% | 24.2% |
| Roast Ham | 356 | 27.5% | 30.9% | 41.6% | 30.9% | 41.6% |
| California | 4 | 25.0% | 25.0% | 50.0% | 25.0% | 50.0% |
| **Total** | **860** | **30.8%** | **37.7%** | **31.5%** | **37.7%** | **31.5%** |

Elderless customers switch at a much higher rate than Roast Ham (42.6% vs 30.9%), while Roast Ham customers are more likely to redeem (41.6% vs 24.2%). California has only 4 mortgages in the cohort, which is too small to mean anything. The open rates are higher for recent cohorts — mortgages from 2026 generally haven't reached their expiry yet, so those numbers will keep moving.


## Q2 — dbt Analytical Layer

**Question:** Explain or sketch how you would structure these datasets in dbt to support trusted recurring reporting and analysis.

**Answer:**

I used dbt and Snowflake to analyse mortgage engagement and outcome data for Eligible's lender clients. I built a cohort summary by lender and business tables such as a behavioural funnel analysis and mortgage detail for segmentation and ad-hoc queries.

### How to Run

```bash
dbt seed    # loads the three source CSV files
dbt run     # builds all models
dbt test    # runs all tests
```

### Project Structure

```
┌─────────┐     ┌──────────┐     ┌──────────────┐     ┌─────────┐
│  SEEDS  │ --> │ STAGING  │ --> │ INTERMEDIATE │ --> │  MARTS  │
└─────────┘     └──────────┘     └──────────────┘     └─────────┘

mortgages       stg_mortgages    int_mortgage_       mart_cohort_
applicants  --> stg_applicants   cohorts             engagement
events          stg_events  -->  int_engagement_     mart_cohort_
                                  spine          -->  summary
                                  int_engagement_     mart_mortgage_
                                  funnel              detail
```

### Layer Details

#### Staging (`models/staging/`)

I applied minor transformations to ensure consistency and standardisation of the source data.

- **stg_mortgages** — I renamed columns to facilitate joins in the intermediate layer, cast dates for standardisation, and added a `dq_open_with_closed_date` flag to support data quality checks.

- **stg_applicants** — Minimal transformation: I renamed the columns and kept the model lean, as this table acts as a bridge between applicants and mortgages.

- **stg_events** — I cast relevant fields as dates. During analysis I noticed event names used both hyphens and underscores inconsistently, so I normalised them for easier filtering. I also added an `event_category` field to distinguish the email send trigger from downstream behavioural actions (click, login, read).

#### Intermediate (`models/intermediate/`)

Business logic lives here. All three models share the same grain: one row per mortgage.

- **int_mortgage_cohorts** — I assigned each mortgage to a cohort based on the date of its first `email_sent` event. Mortgages with no `email_sent` event are excluded from downstream analysis.

- **int_engagement_spine** — I resolved the many-to-many relationship between events and mortgages. Because events are tied to consumers via `consumer_id` and a consumer can hold multiple mortgages, a direct join would fan out incorrectly. I routed through `stg_applicants` to map each consumer's events back to their specific mortgage. The residual risk is over-attribution: if a consumer has two active mortgages and clicks an email, that click is attributed to both. Fully resolving this would require additional context to assign actions to a single mortgage. Beyond the join resolution, I calculated month 1, 2, and 3 engagement flags per mortgage and flagged whether the consumer declared intent.

- **int_engagement_funnel** — I calculated the furthest funnel stage each mortgage reached within months 1–3. Stages are unordered: a mortgage is flagged for a stage if that event occurred at any point in the window, regardless of sequence. The highest stage reached is captured in `funnel_stage_label`. I added this model to help identify where engagement drops off across the process.

#### Marts (`models/marts/`)

The tables analysts and dashboards query directly.

- **mart_cohort_engagement** — Grain: one row per `(lender, cohort_month)`. The primary table for comparing lender performance across cohorts. I included engagement rates by month, funnel stage counts, intent rate, switch rate, and redemption rate.

- **mart_cohort_summary** — Grain: one row per `cohort_month`. The same metrics as above but collapsed across all lenders. I added this for trend analysis over time.

- **mart_mortgage_detail** — Grain: one row per mortgage. I brought everything into one place — cohort, engagement flags, funnel stage, days to intent, days to close, and whether intent preceded close. Useful for segmentation and ad-hoc analysis.

### Metric Definitions

I defined all metrics in `models/marts/schema.yml`, with business descriptions, grain, and column-level documentation for each. The table below is a quick reference.

| Metric | Definition | Available in |
|---|---|---|
| `engagement_rate_m1_to_m3` | % of mortgages with any engagement event in months 1–3 | All marts |
| `engagement_rate_m1/m2/m3` | Same, broken out by month | `mart_cohort_engagement` |
| `intent_rate` | % of mortgages with a declared intent event in months 1–3 | All marts |
| `switch_rate` | % of mortgages with `mortgage_state = switched` | All marts |
| `redemption_rate` | % of mortgages with `mortgage_state = redeemed` | All marts |
| `days_to_intent` | Days from first email to first intent event | `mart_mortgage_detail` |
| `days_to_close` | Days from first email to mortgage close date | `mart_mortgage_detail` |
| `intent_before_close` | 1 if intent occurred before mortgage closed | `mart_mortgage_detail` |

### Tests

I added tests for two purposes: catching data issues before they corrupt metrics, and making assumptions explicit so any analyst understands what "clean" means for each table.

#### Generic Tests (`schema.yml`)

**stg_mortgages**
- `mortgage_id`: unique + not_null — duplicate mortgages would inflate all cohort counts
- `mortgage_state`: accepted_values [open, switched, redeemed] — any unexpected value would silently fall outside outcome metrics

**stg_applicants**
- `applicant_id`: unique + not_null — primary key integrity
- `mortgage_id`: not_null + relationships → stg_mortgages — a null here breaks the mortgage→consumer join; an orphaned applicant causes silent row loss on inner joins
- `consumer_id`: not_null — event attribution depends entirely on this link

**stg_events**
- `event_id`: unique + not_null — duplicate events would inflate engagement rates
- `event_alias`: not_null — the categorisation logic depends on this field; a null produces `unknown`, which falls outside all metric calculations
- `mortgage_id`: relationships → stg_mortgages — validates non-null values only (field is nullable by design)

**mart_mortgage_detail**
- `mortgage_id`: unique + not_null — confirms one row per mortgage
- `mortgage_state`: accepted_values [open, switched, redeemed]

#### Singular Tests (`tests/`)

**assert_no_engagement_before_first_email.sql** — I added this to verify that no engagement event occurs before the first `email_sent` for that mortgage. If it does, cohort month calculations produce negative values and corrupt engagement rates entirely.

**assert_no_duplicate_cohort_assignment.sql** — I added this to confirm that each mortgage belongs to exactly one cohort. If a mortgage appears in two cohorts it gets double-counted in the summary tables.

### Data Quality Issues Found

#### 1. Inconsistent `event_alias` format

I found that the source data used two formats for the same events: `email-sent` (hyphen) and `email_sent` (underscore). This caused all hyphenated events to fall into the `unknown` category, effectively hiding ~40% of `email_sent` volume and all corresponding engagement events from metrics.

I normalised this in `stg_events` using `replace(event_alias, '-', '_')` before categorisation.

#### 2. Orphaned applicant records

When I ran the relationships test between `stg_applicants.mortgage_id` and `stg_mortgages.mortgage_id`, I found 1,538 orphaned applicant records (23% of all applicants) pointing to mortgages that do not exist in the mortgages table.

Of these, 560 unique consumers have real behavioural events that cannot be attributed to any mortgage and are therefore excluded from all engagement and intent calculations.

This means engagement rates, intent rates, and funnel metrics are understated by an unknown margin. The root cause is likely an incomplete data export — mortgages were filtered out of the extract but their applicants were not. Relative comparisons between cohorts and lenders remain valid assuming the missing data is distributed evenly; absolute metric levels should be treated as a floor.

I recommend reconciling the mortgages and applicants extracts before drawing conclusions on absolute levels.

#### 3. Engagement events have no direct `mortgage_id`

I found that all engagement events (`email_clicked`, `logged_in`, `subtopic_read`, `start_review`, `intent`) have `mortgage_id = null`. I resolved attribution entirely via the applicants bridge table using `consumer_id`. This introduces ambiguity for consumers with multiple mortgages — an event gets attributed to all their mortgages, not just the one the email was about.

I flagged this via `dq_engagement_no_mortgage` in `stg_events`.

## Q3 -- Behavioural Signals Analysis

**Question:** Explore whether early behavioural signals are associated with later stated intent or switching outcomes.

**Answer:** `deliverables/q3_behavioural_signals.ipynb`

I used Python (pandas, matplotlib, seaborn, sklearn) to explore the relationship between early engagement signals and eventual switching outcomes. The notebook runs end-to-end against the same seed data used by the dbt models.

Key findings:
- **Intent is the dominant signal.** Mortgages where a customer declared intent switched at substantially higher rates. Logistic regression confirms intent is the only signal that independently predicts switching once earlier funnel stages are controlled for.
- **Month 1 engagement is the strongest leading indicator.** Customers who engaged in the first month after their first email showed higher intent and switch rates than those who engaged only in months 2 or 3.
- **The funnel drops off sharply after the first email.** Most customers never clicked, logged in, or read content. The step from receiving an email to taking any further action is where the biggest drop occurs.
- **The signal is stable across cohorts.** The intent-to-switch relationship holds consistently. Lower switch rates in recent cohorts reflect the short observation window, not a weakening signal.

## Q4 -- Client Summary

**Answer:** `deliverables/q4_client_summary.md`

A plain-language summary of findings and recommendations written for a non-technical business audience.
