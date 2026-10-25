# Peek Senior Data Analyst Case Study

Senior Data Analyst case study using the public TheLook Ecommerce dataset, focused on business health, retention, churn, data quality, and practical AI applications.

## Overview

**Dataset:** `bigquery-public-data.thelook_ecommerce`

**Tools:**
- BigQuery / GoogleSQL
- Looker Studio

**SQL:** [`/sql/part1_queries.sql`](./sql/part1_queries.sql)

**Dashboard:** [Looker Studio Dashboard](https://datastudio.google.com/reporting/53d6cdce-cd25-44c7-a218-c10a6c7c38cb)

---

## How to Run

1. Create a BigQuery dataset for the analysis.
2. Update the project references in `/sql/part1_queries.sql` if needed.
3. Run the SQL file from top to bottom.

On the first run, the script creates local snapshot tables from the public TheLook source.

The snapshot tables use `CREATE TABLE IF NOT EXISTS`, so subsequent executions preserve the same source snapshot while rebuilding the analytical models.

Because the public TheLook synthetic dataset can change over time, a new first-time execution against the public source may produce different absolute values from those reported here.

---

## Scope and Metric Definitions

**Analysis as-of date:** `2026-10-21`

**Final snapshot timestamp:** `2026-10-23 18:18:57 UTC`

**Reporting period:** February 2019 – September 2026

**Latest mature 90-day churn month:** June 2026

### Core definitions

- **Completed sale:** `status = 'Complete' AND returned_at IS NULL`
- **Revenue:** Sum of `sale_price`
- **COGS:** Inventory item cost
- **Gross profit:** Revenue - COGS
- **Gross margin:** Gross profit / Revenue
- **Order month:** Month of `order_items.created_at`
- **Active customer:** Customer with at least one completed order during the month
- **New customer:** Active customer whose first-ever completed order occurred during that month
- **Returning customer:** Active customer whose first-ever completed order occurred before that month
- **90-day churn:** Active customer with no completed order during the 90 calendar days following the end of the active month
- **90-day repeat rate:** `1 - churn_rate_90d`
- **Session conversion:** Distinct purchase sessions / distinct department sessions

Recent months without a complete 90-day observation window are explicitly right-censored and return `NULL` churn metrics.

---

## Data Quality

### Top finding — Future-dated completed order items

Using the `2026-10-21` analysis cutoff, the final snapshot contains:

- **931** future-dated completed-sale line items
- **622** affected orders
- **$56,991.84** in affected revenue
- **2.14%** of total completed-sale revenue

These records are excluded from metrics evaluated as of the analysis date.

The source records themselves are not modified because their root cause cannot be established from the available dataset.

### Source reproducibility

During reconciliation, the public TheLook source changed between query runs, including historical totals.

An `as_of_date` alone was therefore not sufficient to guarantee reproducibility.

To keep all submitted metrics internally consistent, the final pipeline creates local snapshot tables once and preserves them across subsequent runs.

Additional data-quality checks, including duplicate IDs, timestamp sequencing, referential integrity, financial fields, future dates, and incomplete reporting periods, are included in `/sql/part1_queries.sql`.

---

# Part 2 — Product & Business Analysis

## Dashboard

The Looker Studio dashboard contains three views:

1. **Business health:** Revenue, gross profit, and orders over time
2. **Retention mix:** New vs. returning revenue alongside 90-day churn
3. **Decision view:** Recent 12 mature months vs. the preceding 12 months

[Open the Looker Studio dashboard](https://datastudio.google.com/reporting/53d6cdce-cd25-44c7-a218-c10a6c7c38cb)

---

## Executive Takeaway

**Growth remains acquisition-led, but repeat behavior is improving rather than weakening.**

Comparison of the most recent 12 mature months with the preceding 12 months:

| Metric | Previous 12 months | Recent 12 months | Change |
|---|---:|---:|---:|
| Revenue | $485,657.86 | $782,974.30 | +61.2% |
| Avg. monthly returning revenue share | 11.90% | 15.07% | +3.17 pp |
| 90-day repeat rate | 3.26% | 5.05% | +1.79 pp |
| 90-day churn | 96.74% | 94.95% | -1.79 pp |

Approximately **85% of recent revenue still comes from new customers**, confirming that acquisition remains the primary growth engine.

However, the hypothesis that repeat behavior is weakening is not supported by the observed trend:

- returning revenue share increased,
- 90-day repeat improved,
- 90-day churn declined.

The main opportunity is therefore not reversing a deterioration in retention, but improving retention from a still-low base.

These results are descriptive and should not be interpreted as evidence that acquisition growth caused the observed changes in retention.

---

## Recommended Action

### Prioritize first-to-second purchase activation

I would prioritize a targeted post-purchase program for first-time customers during the first 90 days after their initial completed purchase.

Potential interventions could include:

- post-purchase communication,
- relevant product recommendations,
- targeted re-engagement.

**Primary success metric:** 90-day repeat rate  
**Secondary metrics:** Returning revenue share and incremental gross profit

Where possible, I would use a randomized holdout group to measure incremental impact rather than attributing changes based only on before/after trends.

### Keep acquisition growth, but measure retention quality

Acquisition should continue to be supported, but the monthly growth scorecard should include:

- 90-day repeat rate
- returning revenue share

This allows acquisition to be evaluated not only on customer volume, but also on the quality of the customers it generates.

---

## Analytical Limitations

The 90-day churn definition uses the end of the active month as the observation anchor. Customers without a completed purchase during the following 90 calendar days are classified as churned.

This creates right censoring, so July–September 2026 are excluded from mature churn comparisons.

A production analysis could refine the measure using purchase-level anchors, customer/product purchase cadence, cohort analysis, or survival methods.

The analysis is observational; causal conclusions would require an experiment or stronger causal design.

---

# Part 3 — AI Workflow and AI Use

## 3.1 Proposed AI Workflow — Exception-Driven Partner Insights Copilot

I would build an exception-driven analytics copilot to help analysts and partner-facing teams prioritize accounts requiring attention.

Rather than asking an LLM to review every dashboard, deterministic SQL would first identify material changes or unusual combinations of metrics.

The AI layer would only process those flagged exceptions.

### Inputs

Trusted, precomputed partner-level metrics such as:

- revenue growth,
- gross margin,
- conversion,
- returning revenue share,
- 90-day repeat rate,
- churn.

SQL would also provide the deterministic reason the account was flagged.

Customer-level PII would not be passed to the model.

### Output

For each flagged account, the model would return a structured brief containing:

1. the most important observed changes,
2. why the case deserves attention,
3. follow-up questions to investigate,
4. additional data needed before reaching a conclusion.

The LLM would **not** calculate KPIs or determine which accounts should be flagged.

### Representative System Prompt

> You are an analytics copilot supporting a partner-facing team. Use only the supplied metrics and context. Do not calculate or invent missing values. Clearly separate observed facts from hypotheses. Do not claim causality unless causal evidence is explicitly provided. If the data is insufficient to explain a change, state that and recommend what should be investigated next. Prioritize the most decision-relevant changes and return the output in the required structured format.

### Guardrails and Human Review

- KPIs and exception thresholds are calculated deterministically in SQL.
- Only approved aggregate data is provided to the model.
- Partner data is tenant-scoped.
- Structured outputs allow numerical statements to be reconciled programmatically.
- Unsupported causal explanations are rejected or flagged.
- PII and unnecessary customer-level data are excluded.
- The model cannot modify source data or trigger external actions.
- An analyst reviews the brief before external communication or business action.

The objective is to reduce triage and synthesis time, not replace analytical judgment.

### Evaluation

I would compare the AI workflow against both the existing analyst process and a deterministic rules-and-template baseline.

Key measures would include:

- factual / numerical error rate,
- reviewer acceptance rate,
- editing required,
- analyst time saved,
- percentage of surfaced exceptions judged useful,
- adoption,
- follow-up actions generated.

I would not deploy or would pause the AI layer if it fails to materially outperform a deterministic approach, if factual accuracy falls below the agreed threshold, or immediately if a tenant-isolation or privacy failure occurs.

**Principle:** Use AI only where it creates incremental value beyond deterministic analytics.

---

## 3.2 How I Used AI During the Challenge

I used AI primarily as a **reasoning and review assistant**, not as the source of analytical truth.

I retained ownership of the metric definitions, SQL logic, analytical choices, and final conclusions.

AI was most useful for challenging assumptions, identifying edge cases, suggesting validation approaches, and improving documentation.

### Representative Prompt

> Review my approach for monthly new vs. returning customers and 90-day churn in BigQuery. New customers must be based on their first-ever completed purchase, and churn must explicitly handle right censoring. Identify edge cases or logical risks and suggest independent reconciliation checks I can use to validate the implementation.

### Validation

I avoided relying on the model to simply review its own output.

Instead, I used independently testable identities and reconciliations against the underlying data, including:

- `active_customers = new_customers + returning_customers`
- `monthly revenue = revenue_new + revenue_returning`
- immature churn months must return `NULL`
- the latest mature month must match the 90-day observation window
- monthly commerce totals must reconcile to the completed-order-item model

The final pipeline produced **zero reconciliation errors** for these checks.

### One Thing AI Got Wrong

An AI-assisted version of the incomplete-month data-quality check initially classified every record in the current calendar month as part of the incomplete-month issue.

This also included records dated after the `as_of_date`, causing future-dated records to overlap with the incomplete-month classification.

The SQL executed successfully, but reconciliation exposed the logical problem.

I corrected the condition by adding:

`DATE(created_at) <= as_of_date`

This reinforced an important principle:

**Syntactically valid SQL is not necessarily analytically correct.**

### Separate Source Reproducibility Issue

Reconciliation also revealed that the public TheLook dataset changed between query runs.

This was not an AI error; it was a source-reproducibility issue detected through validation.

I therefore moved from relying only on an `as_of_date` to creating local source snapshots once and preserving them across subsequent runs.

My preferred use of AI in analytics is to accelerate reasoning, review, and iteration while keeping metric definitions, deterministic calculations, validation controls, and final judgment outside the model.

---

## Scoping Decisions and Follow-up Analysis

Given the case-study timebox, I prioritized the required metric foundation, retention/churn analysis, three decision-oriented visuals, and a reproducible analytical pipeline.

I intentionally kept the analysis focused rather than adding additional segmentation that was not necessary to answer the two selected business questions.

### What I would add with more time

- **Cohort retention analysis:** Compare repeat behavior by first-purchase cohort to separate lifecycle effects from overall growth trends.
- **Acquisition-quality segmentation:** Break 90-day repeat and returning revenue down by traffic source to identify which acquisition channels generate the highest-quality customers.
- **Customer / market segmentation:** Explore country, category, or other meaningful segments to determine whether the aggregate retention trend is consistent across the business.
- **More granular retention modeling:** Refine the month-end churn definition using purchase-level anchors, customer purchase cadence, or survival analysis.
- **Experiment design:** Define the sample size, treatment/control structure, and guardrails for the proposed first-to-second-purchase program.

The optional cohort-retention stretch was therefore left out of the submitted scope in favor of deeper validation of the required metrics and explicit handling of data-quality and right-censoring issues.
