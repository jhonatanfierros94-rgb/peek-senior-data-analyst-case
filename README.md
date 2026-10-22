# peek-senior-data-analyst-case
Peek Senior Data Analyst case study – SQL, product analytics, retention, churn, and AI.
# Peek Senior Data Analyst Case Study

## Dataset
bigquery-public-data.thelook_ecommerce

## Tools
- BigQuery / GoogleSQL
- Looker Studio

## Analysis
See `/sql/part1_queries.sql`.

## Data quality

### Top finding: Future-dated completed order items

Using an analysis cutoff of 2026-10-21, I identified 292 completed
order items across 194 orders dated after the analysis date.

These records represent approximately $17,945 in revenue, or 0.66%
of total completed-sale revenue.

Handling:
Flag and exclude these records from metrics as of the analysis date.
I did not modify the source records because their root cause cannot
be established from the available dataset.

### Secondary finding: Events before signup

1,846 events occur before the associated user's signup timestamp.

Removing these records changes session conversion from approximately
40.8122% to 40.8106%, a difference of only -0.0016 percentage points.

Given the negligible KPI impact, I flag the issue but do not treat it
as a material driver of the business metrics.
