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

Using an analysis cutoff of 2026-10-21, the frozen source snapshot
contains 1,856 order-item records dated after the analysis date.

Among completed sales, 457 line items across 259 orders are affected,
representing approximately $26,575.69 in revenue, or 0.98% of total
completed-sale revenue.

Handling:
Flag and exclude future-dated records from metrics as of the analysis
date. The source records were not modified because their root cause
cannot be established from the available dataset.

### Secondary finding: Events before signup

1,720 events occur before the associated user's signup timestamp.

Excluding those records changes session conversion from approximately
40.72425% to 40.72414%, a difference of only -0.00012 percentage points.

Given the negligible KPI impact, the issue is flagged but is not treated
as a material driver of the headline metric.
