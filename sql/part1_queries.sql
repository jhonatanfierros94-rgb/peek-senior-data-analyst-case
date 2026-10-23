-- ============================================================
-- PEEK SENIOR DATA ANALYST CASE STUDY
-- Part 1: SQL
-- TheLook Ecommerce
--
-- Sections should be run in order.
-- Source data is frozen into local snapshot tables to protect
-- the analysis from upstream changes observed during development.
-- ============================================================


-- ============================================================
-- 00. SOURCE SNAPSHOT & ANALYSIS METADATA
--
-- During development, reconciliation checks showed that the
-- public TheLook dataset could change between query runs.
-- To keep all reported metrics internally consistent, the
-- analysis uses local snapshot tables created once and
-- preserved on subsequent runs.
--
-- Analysis as-of date: 2026-10-21
-- ============================================================


CREATE TABLE IF NOT EXISTS
`peek-data-analyst-case-123456.peek_case.snapshot_order_items` AS

SELECT *
FROM
    `bigquery-public-data.thelook_ecommerce.order_items`;


CREATE TABLE IF NOT EXISTS
`peek-data-analyst-case-123456.peek_case.snapshot_inventory_items` AS

SELECT *
FROM
    `bigquery-public-data.thelook_ecommerce.inventory_items`;


CREATE TABLE IF NOT EXISTS
`peek-data-analyst-case-123456.peek_case.snapshot_users` AS

SELECT *
FROM
    `bigquery-public-data.thelook_ecommerce.users`;


CREATE TABLE IF NOT EXISTS
`peek-data-analyst-case-123456.peek_case.snapshot_events` AS

SELECT *
FROM
    `bigquery-public-data.thelook_ecommerce.events`;


CREATE TABLE IF NOT EXISTS
`peek-data-analyst-case-123456.peek_case.snapshot_metadata` AS

SELECT
    CURRENT_TIMESTAMP() AS snapshot_created_at,
    DATE '2026-10-21' AS analysis_as_of_date;

-- ============================================================
-- A1. DATA QUALITY CHECKS
--
-- Returns one summary table with:
--   check_name
--   failed_rows
--   total_rows
--   pct_failed
--
-- Checks cover:
--   - incomplete trailing month
--   - future-dated records
--   - timestamp consistency
--   - duplicate keys
--   - orphaned inventory keys
--   - invalid financial values
-- ============================================================


WITH params AS (

    SELECT
        analysis_as_of_date AS as_of_date

    FROM
        `peek-data-analyst-case-123456.peek_case.snapshot_metadata`

    LIMIT 1
),


order_item_base AS (

    SELECT
        *

    FROM
        `peek-data-analyst-case-123456.peek_case.snapshot_order_items`
),


event_user_base AS (

    SELECT
        e.*,
        u.created_at AS user_created_at

    FROM
        `peek-data-analyst-case-123456.peek_case.snapshot_events` AS e

    INNER JOIN
        `peek-data-analyst-case-123456.peek_case.snapshot_users` AS u

        ON e.user_id = u.id
),


completed_financial_base AS (

    SELECT
        oi.id,
        oi.sale_price,
        ii.cost

    FROM
        `peek-data-analyst-case-123456.peek_case.snapshot_order_items` AS oi

    LEFT JOIN
        `peek-data-analyst-case-123456.peek_case.snapshot_inventory_items` AS ii

        ON oi.inventory_item_id = ii.id

    WHERE
        oi.status = 'Complete'
        AND oi.returned_at IS NULL
)


SELECT
    'incomplete_trailing_month' AS check_name,

    COUNTIF(
        DATE_TRUNC(DATE(created_at), MONTH)
        =
        DATE_TRUNC(
            (SELECT as_of_date FROM params),
            MONTH
        )
        AND DATE(created_at)
            <= (SELECT as_of_date FROM params)
    ) AS failed_rows,

    COUNT(*) AS total_rows,

    SAFE_DIVIDE(
        COUNTIF(
            DATE_TRUNC(DATE(created_at), MONTH)
            =
            DATE_TRUNC(
                (SELECT as_of_date FROM params),
                MONTH
            )
            AND DATE(created_at)
                <= (SELECT as_of_date FROM params)
        ),
        COUNT(*)
    ) AS pct_failed

FROM order_item_base


UNION ALL


SELECT
    'future_dated_order_items',

    COUNTIF(
        DATE(created_at)
        >
        (SELECT as_of_date FROM params)
    ),

    COUNT(*),

    SAFE_DIVIDE(
        COUNTIF(
            DATE(created_at)
            >
            (SELECT as_of_date FROM params)
        ),
        COUNT(*)
    )

FROM order_item_base


UNION ALL


SELECT
    'event_before_user_signup',

    COUNTIF(
        e.created_at < e.user_created_at
    ),

    COUNT(*),

    SAFE_DIVIDE(
        COUNTIF(
            e.created_at < e.user_created_at
        ),
        COUNT(*)
    )

FROM event_user_base AS e


UNION ALL


SELECT
    'future_dated_events',

    COUNTIF(
        DATE(created_at)
        >
        (SELECT as_of_date FROM params)
    ),

    COUNT(*),

    SAFE_DIVIDE(
        COUNTIF(
            DATE(created_at)
            >
            (SELECT as_of_date FROM params)
        ),
        COUNT(*)
    )

FROM
    `peek-data-analyst-case-123456.peek_case.snapshot_events`


UNION ALL


SELECT
    'duplicate_order_item_ids',

    COUNT(*) - COUNT(DISTINCT id),

    COUNT(*),

    SAFE_DIVIDE(
        COUNT(*) - COUNT(DISTINCT id),
        COUNT(*)
    )

FROM order_item_base


UNION ALL


SELECT
    'delivered_before_shipped',

    COUNTIF(
        delivered_at IS NOT NULL
        AND shipped_at IS NOT NULL
        AND delivered_at < shipped_at
    ),

    COUNT(*),

    SAFE_DIVIDE(
        COUNTIF(
            delivered_at IS NOT NULL
            AND shipped_at IS NOT NULL
            AND delivered_at < shipped_at
        ),
        COUNT(*)
    )

FROM order_item_base


UNION ALL


SELECT
    'returned_before_delivered',

    COUNTIF(
        returned_at IS NOT NULL
        AND delivered_at IS NOT NULL
        AND returned_at < delivered_at
    ),

    COUNT(*),

    SAFE_DIVIDE(
        COUNTIF(
            returned_at IS NOT NULL
            AND delivered_at IS NOT NULL
            AND returned_at < delivered_at
        ),
        COUNT(*)
    )

FROM order_item_base


UNION ALL


SELECT
    'orphan_inventory_item',

    COUNTIF(
        ii.id IS NULL
    ),

    COUNT(*),

    SAFE_DIVIDE(
        COUNTIF(
            ii.id IS NULL
        ),
        COUNT(*)
    )

FROM
    `peek-data-analyst-case-123456.peek_case.snapshot_order_items` AS oi

LEFT JOIN
    `peek-data-analyst-case-123456.peek_case.snapshot_inventory_items` AS ii

    ON oi.inventory_item_id = ii.id


UNION ALL


SELECT
    'invalid_completed_price_or_cost',

    COUNTIF(
        sale_price IS NULL
        OR sale_price < 0
        OR cost IS NULL
        OR cost < 0
    ),

    COUNT(*),

    SAFE_DIVIDE(
        COUNTIF(
            sale_price IS NULL
            OR sale_price < 0
            OR cost IS NULL
            OR cost < 0
        ),
        COUNT(*)
    )

FROM completed_financial_base


ORDER BY pct_failed DESC;



-- ============================================================
-- A1.1 TOP DATA QUALITY FINDING: REVENUE IMPACT
--
-- Top actionable finding:
-- Future-dated order items exist after the documented
-- analysis as-of date.
--
-- Quantify how much completed-sale revenue would be
-- overstated if these records were not excluded.
-- ============================================================


WITH params AS (

    SELECT
        analysis_as_of_date AS as_of_date

    FROM
        `peek-data-analyst-case-123456.peek_case.snapshot_metadata`

    LIMIT 1
),


completed_sales AS (

    SELECT
        order_id,
        created_at,
        sale_price

    FROM
        `peek-data-analyst-case-123456.peek_case.snapshot_order_items`

    WHERE
        status = 'Complete'
        AND returned_at IS NULL
)


SELECT
    COUNT(*) AS completed_rows,

    COUNTIF(
        DATE(created_at)
        >
        (SELECT as_of_date FROM params)
    ) AS affected_rows,

    COUNT(
        DISTINCT IF(
            DATE(created_at)
            >
            (SELECT as_of_date FROM params),
            order_id,
            NULL
        )
    ) AS affected_orders,

    SUM(sale_price) AS total_revenue,

    SUM(
        IF(
            DATE(created_at)
            >
            (SELECT as_of_date FROM params),
            sale_price,
            0
        )
    ) AS affected_revenue,

    SAFE_DIVIDE(
        SUM(
            IF(
                DATE(created_at)
                >
                (SELECT as_of_date FROM params),
                sale_price,
                0
            )
        ),
        SUM(sale_price)
    ) AS pct_revenue_affected

FROM completed_sales;



-- ============================================================
-- A2. REUSABLE COMPLETED ORDER ITEMS MODEL
--
-- Single source of truth for completed sales.
--
-- Peek convention:
--   status = 'Complete'
--   returned_at IS NULL
--
-- The view intentionally preserves all completed-sale history.
-- Analytical date cutoffs are applied downstream so the
-- business definition remains separate from reporting windows.
-- ============================================================


CREATE OR REPLACE VIEW
`peek-data-analyst-case-123456.peek_case.completed_order_items` AS

SELECT
    oi.id AS order_item_id,
    oi.order_id,
    oi.user_id,
    oi.product_id,
    oi.inventory_item_id,

    oi.created_at,
    oi.shipped_at,
    oi.delivered_at,

    oi.sale_price,

    ii.cost AS cogs,

    oi.sale_price - ii.cost
        AS gross_profit,

    DATE_TRUNC(
        DATE(oi.created_at),
        MONTH
    ) AS order_month

FROM
    `peek-data-analyst-case-123456.peek_case.snapshot_order_items` AS oi

LEFT JOIN
    `peek-data-analyst-case-123456.peek_case.snapshot_inventory_items` AS ii

    ON oi.inventory_item_id = ii.id

WHERE
    oi.status = 'Complete'
    AND oi.returned_at IS NULL;



-- ============================================================
-- A3. MONTHLY BUSINESS HEALTH
--
-- One row per complete reporting month.
--
-- Reporting window:
--   start_date = first full month available across commerce
--                and event data
--   end_date   = last day of the month before as_of_date
--
-- This explicitly excludes the incomplete trailing month.
-- ============================================================

BEGIN
DECLARE as_of_date DATE;
DECLARE start_date DATE;
DECLARE end_date DATE;


SET as_of_date = (

    SELECT
        analysis_as_of_date

    FROM
        `peek-data-analyst-case-123456.peek_case.snapshot_metadata`

    LIMIT 1
);


SET start_date = (

    WITH source_bounds AS (

        SELECT

            (
                SELECT MIN(DATE(created_at))
                FROM
                    `peek-data-analyst-case-123456.peek_case.snapshot_order_items`
            ) AS first_order_date,

            (
                SELECT MIN(DATE(created_at))
                FROM
                    `peek-data-analyst-case-123456.peek_case.snapshot_events`
            ) AS first_event_date
    )

    SELECT
        GREATEST(

            CASE
                WHEN first_order_date =
                     DATE_TRUNC(first_order_date, MONTH)
                THEN first_order_date

                ELSE DATE_ADD(
                    DATE_TRUNC(first_order_date, MONTH),
                    INTERVAL 1 MONTH
                )
            END,

            CASE
                WHEN first_event_date =
                     DATE_TRUNC(first_event_date, MONTH)
                THEN first_event_date

                ELSE DATE_ADD(
                    DATE_TRUNC(first_event_date, MONTH),
                    INTERVAL 1 MONTH
                )
            END
        )

    FROM source_bounds
);


SET end_date =
    DATE_SUB(
        DATE_TRUNC(as_of_date, MONTH),
        INTERVAL 1 DAY
    );


CREATE OR REPLACE TABLE
`peek-data-analyst-case-123456.peek_case.monthly_health` AS


WITH monthly_commerce AS (

    SELECT
        DATE_TRUNC(
            DATE(created_at),
            MONTH
        ) AS month,

        SUM(sale_price) AS revenue,

        SUM(gross_profit) AS gross_profit,

        COUNT(DISTINCT order_id) AS orders,

        COUNT(*) AS units

    FROM
        `peek-data-analyst-case-123456.peek_case.completed_order_items`

    WHERE
        DATE(created_at)
        BETWEEN start_date AND end_date

    GROUP BY month
),


monthly_sessions AS (

    SELECT
        DATE_TRUNC(
            DATE(created_at),
            MONTH
        ) AS month,

        COUNT(
            DISTINCT IF(
                event_type = 'department',
                session_id,
                NULL
            )
        ) AS department_sessions,

        COUNT(
            DISTINCT IF(
                event_type = 'purchase',
                session_id,
                NULL
            )
        ) AS purchase_sessions

    FROM
        `peek-data-analyst-case-123456.peek_case.snapshot_events`

    WHERE
        DATE(created_at)
        BETWEEN start_date AND end_date

        AND session_id IS NOT NULL

    GROUP BY month
),


combined AS (

    SELECT
        c.month,

        c.revenue,

        c.gross_profit,

        SAFE_DIVIDE(
            c.gross_profit,
            c.revenue
        ) AS gross_margin_pct,

        c.orders,

        c.units,

        SAFE_DIVIDE(
            c.revenue,
            c.orders
        ) AS aov,

        s.department_sessions,

        s.purchase_sessions,

        SAFE_DIVIDE(
            s.purchase_sessions,
            s.department_sessions
        ) AS session_conversion_rate

    FROM monthly_commerce AS c

    LEFT JOIN monthly_sessions AS s
        USING(month)
),


with_previous_month AS (

    SELECT
        *,

        LAG(revenue)
        OVER (
            ORDER BY month
        ) AS previous_month_revenue

    FROM combined
)


SELECT
    month,

    revenue,

    gross_profit,

    gross_margin_pct,

    orders,

    units,

    aov,

    SAFE_DIVIDE(
        revenue - previous_month_revenue,
        previous_month_revenue
    ) AS revenue_mom_growth_pct,

    session_conversion_rate,

    department_sessions,

    purchase_sessions

FROM with_previous_month

ORDER BY month;

END;

-- ============================================================
-- B1. NEW VS RETURNING CUSTOMER MIX
--
-- Active customer:
--   Customer with >= 1 completed order in the month.
--
-- New customer:
--   Active customer whose first-ever completed order occurred
--   in that month.
--
-- Returning customer:
--   Active customer whose first-ever completed order occurred
--   before that month.
-- ============================================================

BEGIN

DECLARE as_of_date DATE;
DECLARE start_date DATE;
DECLARE end_date DATE;


SET as_of_date = (

    SELECT
        analysis_as_of_date

    FROM
        `peek-data-analyst-case-123456.peek_case.snapshot_metadata`

    LIMIT 1
);


SET start_date = (

    WITH source_bounds AS (

        SELECT

            (
                SELECT MIN(DATE(created_at))
                FROM
                    `peek-data-analyst-case-123456.peek_case.snapshot_order_items`
            ) AS first_order_date,

            (
                SELECT MIN(DATE(created_at))
                FROM
                    `peek-data-analyst-case-123456.peek_case.snapshot_events`
            ) AS first_event_date
    )

    SELECT
        GREATEST(

            CASE
                WHEN first_order_date =
                     DATE_TRUNC(first_order_date, MONTH)
                THEN first_order_date

                ELSE DATE_ADD(
                    DATE_TRUNC(first_order_date, MONTH),
                    INTERVAL 1 MONTH
                )
            END,

            CASE
                WHEN first_event_date =
                     DATE_TRUNC(first_event_date, MONTH)
                THEN first_event_date

                ELSE DATE_ADD(
                    DATE_TRUNC(first_event_date, MONTH),
                    INTERVAL 1 MONTH
                )
            END
        )

    FROM source_bounds
);


SET end_date =
    DATE_SUB(
        DATE_TRUNC(as_of_date, MONTH),
        INTERVAL 1 DAY
    );


CREATE OR REPLACE TABLE
`peek-data-analyst-case-123456.peek_case.customer_mix_monthly` AS


WITH customer_history AS (

    SELECT
        user_id,
        created_at,
        sale_price,

        MIN(DATE(created_at))
        OVER (
            PARTITION BY user_id
        ) AS first_purchase_date

    FROM
        `peek-data-analyst-case-123456.peek_case.completed_order_items`

    WHERE
        user_id IS NOT NULL
        AND DATE(created_at) <= as_of_date
),


classified_sales AS (

    SELECT
        DATE_TRUNC(
            DATE(created_at),
            MONTH
        ) AS month,

        user_id,
        sale_price,

        CASE
            WHEN DATE_TRUNC(first_purchase_date, MONTH)
                 =
                 DATE_TRUNC(DATE(created_at), MONTH)
            THEN 'new'

            ELSE 'returning'
        END AS customer_type

    FROM customer_history

    WHERE
        DATE(created_at)
        BETWEEN start_date AND end_date
),


customer_month AS (

    SELECT
        month,
        user_id,
        customer_type,

        SUM(sale_price)
            AS customer_month_revenue

    FROM classified_sales

    GROUP BY
        month,
        user_id,
        customer_type
)


SELECT
    month,

    COUNT(*) AS active_customers,

    COUNTIF(
        customer_type = 'new'
    ) AS new_customers,

    COUNTIF(
        customer_type = 'returning'
    ) AS returning_customers,

    SUM(
        IF(
            customer_type = 'new',
            customer_month_revenue,
            0
        )
    ) AS revenue_new,

    SUM(
        IF(
            customer_type = 'returning',
            customer_month_revenue,
            0
        )
    ) AS revenue_returning,

    SAFE_DIVIDE(
        SUM(
            IF(
                customer_type = 'returning',
                customer_month_revenue,
                0
            )
        ),
        SUM(customer_month_revenue)
    ) AS pct_revenue_from_returning

FROM customer_month

GROUP BY month

ORDER BY month;

END;



-- ============================================================
-- B2. 90-DAY CHURN
--
-- Active customer:
--   Customer with >= 1 completed order in the month.
--
-- Churned customer (90d):
--   Active customer with no completed order during the
--   90 calendar days following the end of that month.
--
-- Right censoring:
--   Months without a complete 90-day observation window
--   are explicitly flagged and churn metrics return NULL.
-- ============================================================

BEGIN

DECLARE as_of_date DATE;
DECLARE start_date DATE;
DECLARE end_date DATE;


SET as_of_date = (

    SELECT
        analysis_as_of_date

    FROM
        `peek-data-analyst-case-123456.peek_case.snapshot_metadata`

    LIMIT 1
);


SET start_date = (

    WITH source_bounds AS (

        SELECT

            (
                SELECT MIN(DATE(created_at))
                FROM
                    `peek-data-analyst-case-123456.peek_case.snapshot_order_items`
            ) AS first_order_date,

            (
                SELECT MIN(DATE(created_at))
                FROM
                    `peek-data-analyst-case-123456.peek_case.snapshot_events`
            ) AS first_event_date
    )

    SELECT
        GREATEST(

            CASE
                WHEN first_order_date =
                     DATE_TRUNC(first_order_date, MONTH)
                THEN first_order_date

                ELSE DATE_ADD(
                    DATE_TRUNC(first_order_date, MONTH),
                    INTERVAL 1 MONTH
                )
            END,

            CASE
                WHEN first_event_date =
                     DATE_TRUNC(first_event_date, MONTH)
                THEN first_event_date

                ELSE DATE_ADD(
                    DATE_TRUNC(first_event_date, MONTH),
                    INTERVAL 1 MONTH
                )
            END
        )

    FROM source_bounds
);


SET end_date =
    DATE_SUB(
        DATE_TRUNC(as_of_date, MONTH),
        INTERVAL 1 DAY
    );


CREATE OR REPLACE TABLE
`peek-data-analyst-case-123456.peek_case.churn_90d_monthly` AS


WITH completed_orders AS (

    SELECT DISTINCT
        order_id,
        user_id,
        DATE(created_at) AS order_date

    FROM
        `peek-data-analyst-case-123456.peek_case.completed_order_items`

    WHERE
        user_id IS NOT NULL
        AND DATE(created_at) <= as_of_date
),


active_customer_month AS (

    SELECT
        DATE_TRUNC(
            order_date,
            MONTH
        ) AS month,

        user_id

    FROM completed_orders

    WHERE
        order_date
        BETWEEN start_date AND end_date

    GROUP BY
        month,
        user_id
),


customer_churn_status AS (

    SELECT
        a.month,
        a.user_id,

        DATE_ADD(
            LAST_DAY(a.month),
            INTERVAL 90 DAY
        ) AS maturity_date,

        COUNT(
            f.order_id
        ) AS next_90d_orders

    FROM active_customer_month AS a

    LEFT JOIN completed_orders AS f

        ON f.user_id = a.user_id

        AND f.order_date > LAST_DAY(a.month)

        AND f.order_date <= DATE_ADD(
            LAST_DAY(a.month),
            INTERVAL 90 DAY
        )

    GROUP BY
        a.month,
        a.user_id
)


SELECT
    month,

    COUNT(*) AS active_customers,

    IF(
        DATE_ADD(
            LAST_DAY(month),
            INTERVAL 90 DAY
        ) <= as_of_date,

        COUNTIF(
            next_90d_orders = 0
        ),

        NULL
    ) AS churned_customers_90d,

    IF(
        DATE_ADD(
            LAST_DAY(month),
            INTERVAL 90 DAY
        ) <= as_of_date,

        SAFE_DIVIDE(
            COUNTIF(
                next_90d_orders = 0
            ),
            COUNT(*)
        ),

        NULL
    ) AS churn_rate_90d,

    DATE_ADD(
        LAST_DAY(month),
        INTERVAL 90 DAY
    ) AS maturity_date,

    DATE_ADD(
        LAST_DAY(month),
        INTERVAL 90 DAY
    ) <= as_of_date
        AS is_mature_90d

FROM customer_churn_status

GROUP BY month

ORDER BY month;

END;



-- ============================================================
-- ANALYSIS OUTPUTS USED BY THE DASHBOARD
-- ============================================================

-- ============================================================
-- DASHBOARD OUTPUT 1: RETENTION MONTHLY
--
-- Combines monthly business health, customer mix,
-- and 90-day churn into one reusable analytical table.
--
-- Churn metrics remain NULL for right-censored months.
-- ============================================================


CREATE OR REPLACE TABLE
`peek-data-analyst-case-123456.peek_case.retention_monthly` AS

SELECT
    h.month,

    -- Business health
    h.revenue,
    h.orders,
    h.units,
    h.aov,

    -- New vs Returning
    m.active_customers,
    m.new_customers,
    m.returning_customers,
    m.revenue_new,
    m.revenue_returning,
    m.pct_revenue_from_returning,

    -- 90-day churn / repeat
    c.churned_customers_90d,
    c.churn_rate_90d,

    CASE
        WHEN c.churn_rate_90d IS NOT NULL
        THEN 1 - c.churn_rate_90d
        ELSE NULL
    END AS repeat_rate_90d,

    c.maturity_date,
    c.is_mature_90d

FROM
    `peek-data-analyst-case-123456.peek_case.monthly_health` AS h

LEFT JOIN
    `peek-data-analyst-case-123456.peek_case.customer_mix_monthly` AS m

    USING(month)

LEFT JOIN
    `peek-data-analyst-case-123456.peek_case.churn_90d_monthly` AS c

    USING(month)

ORDER BY month;

-- ============================================================
-- DASHBOARD OUTPUT 2: RETENTION PERIOD SUMMARY
--
-- Compares the most recent 12 mature months against the
-- preceding 12 mature months for executive storytelling.
-- ============================================================


CREATE OR REPLACE TABLE
`peek-data-analyst-case-123456.peek_case.retention_period_summary` AS


WITH mature_months AS (

    SELECT
        *

    FROM
        `peek-data-analyst-case-123456.peek_case.retention_monthly`

    WHERE
        is_mature_90d = TRUE
),


ranked_months AS (

    SELECT
        *,

        ROW_NUMBER()
        OVER (
            ORDER BY month DESC
        ) AS month_rank

    FROM mature_months
),


periodized AS (

    SELECT
        *,

        CASE
            WHEN month_rank BETWEEN 1 AND 12
                THEN 'Recent 12 months'

            WHEN month_rank BETWEEN 13 AND 24
                THEN 'Previous 12 months'

            ELSE NULL
        END AS comparison_period

    FROM ranked_months
)


SELECT
    comparison_period,

    MIN(month) AS period_start,
    MAX(month) AS period_end,

    SUM(revenue) AS total_revenue,

    AVG(active_customers) AS avg_active_customers,

    AVG(pct_revenue_from_returning)
        AS avg_pct_revenue_from_returning,

    AVG(repeat_rate_90d)
        AS avg_repeat_rate_90d,

    AVG(churn_rate_90d)
        AS avg_churn_rate_90d

FROM periodized

WHERE
    comparison_period IS NOT NULL

GROUP BY comparison_period;
