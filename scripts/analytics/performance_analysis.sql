/*
===============================================================================
PRODUCT SALES PERFORMANCE ANALYSIS
===============================================================================
Purpose:
    Analyze product sales performance using:
        1. Historical average sales
        2. Year-over-Year (YoY) comparison
        3. Month-over-Month (MoM) comparison

Database:
    Microsoft SQL Server (T-SQL)

Reporting Grain:
    One row per product_name, period_type, and period_start.

Business Rules:
    - Products are compared using product_name.
    - Different product keys sharing the same name are combined.
    - Only consecutive calendar periods qualify for YoY/MoM comparisons.
    - Missing periods are not automatically treated as zero sales.
    - Percentage changes are NULL when previous-period sales are zero.
    - Historical averages exclude NULL sales values.
    - Historical averages include all available reporting periods.
    - Transactions without a matching, non-NULL product name are excluded.

Assumptions:
    - gold.dim_products.product_key is unique.
    - product_name identifies the intended product comparison grain.
    - Product names are consistent across reporting periods.
    - sales_amount is a valid numeric measure.
===============================================================================
*/

;WITH monthly_sales AS (
    -- Aggregate transactions at the product-name/month grain.
    SELECT
        p.product_name,
        d.month_start AS period_start,
        SUM(f.sales_amount) AS current_sales

    FROM gold.fact_sales AS f

    INNER JOIN gold.dim_products AS p
        ON f.product_key = p.product_key

    CROSS APPLY (
        VALUES (
            DATEFROMPARTS(
                YEAR(f.order_date),
                MONTH(f.order_date),
                1
            )
        )
    ) AS d(month_start)

    WHERE f.order_date IS NOT NULL
      AND p.product_name IS NOT NULL

    GROUP BY
        p.product_name,
        d.month_start
),

annual_sales AS (
    -- Derive annual sales from the monthly aggregates.
    SELECT
        product_name,
        DATEFROMPARTS(
            YEAR(period_start),
            1,
            1
        ) AS period_start,
        SUM(current_sales) AS current_sales

    FROM monthly_sales

    GROUP BY
        product_name,
        YEAR(period_start)
),

period_sales AS (
    -- Standardize yearly and monthly reporting periods.
    SELECT
        'Year' AS period_type,
        product_name,
        period_start,
        DATEADD(YEAR, -1, period_start)
            AS expected_previous_period,
        current_sales

    FROM annual_sales

    UNION ALL

    SELECT
        'Month' AS period_type,
        product_name,
        period_start,
        DATEADD(MONTH, -1, period_start)
            AS expected_previous_period,
        current_sales

    FROM monthly_sales
),

period_history AS (
    -- Calculate historical metrics independently
    -- for each product name and reporting period type.
    SELECT
        ps.period_type,
        ps.product_name,
        ps.period_start,
        ps.expected_previous_period,
        ps.current_sales,

        AVG(
            CAST(ps.current_sales AS DECIMAL(28, 4))
        ) OVER (
            PARTITION BY
                ps.product_name,
                ps.period_type
        ) AS average_sales,

        LAG(ps.period_start) OVER (
            PARTITION BY
                ps.product_name,
                ps.period_type
            ORDER BY
                ps.period_start
        ) AS previous_observed_period,

        LAG(ps.current_sales) OVER (
            PARTITION BY
                ps.product_name,
                ps.period_type
            ORDER BY
                ps.period_start
        ) AS previous_observed_sales

    FROM period_sales AS ps
),

period_comparison AS (
    -- Validate calendar continuity before comparing sales.
    SELECT
        h.period_type,
        h.product_name,
        h.period_start,
        h.current_sales,
        h.average_sales,

        CASE
            WHEN h.previous_observed_period =
                 h.expected_previous_period
                THEN h.previous_observed_sales
        END AS previous_period_sales,

        CASE
            WHEN h.previous_observed_period IS NULL
                THEN 'No Previous Record'

            WHEN h.previous_observed_period <>
                 h.expected_previous_period
                THEN 'Missing Previous Period'

            WHEN h.current_sales IS NULL
              OR h.previous_observed_sales IS NULL
                THEN 'Insufficient Data'

            WHEN h.current_sales > h.previous_observed_sales
                THEN 'Increase'

            WHEN h.current_sales < h.previous_observed_sales
                THEN 'Decrease'

            ELSE 'No Change'
        END AS period_changes

    FROM period_history AS h
)

SELECT
    -- Reporting dimensions
    c.period_type,
    c.period_start,

    YEAR(c.period_start) AS order_year,

    CASE
        WHEN c.period_type = 'Month'
            THEN MONTH(c.period_start)
    END AS order_month,

    c.product_name,

    -- Current-period sales
    c.current_sales,

    -- Historical average comparison
    c.average_sales,

    c.current_sales - c.average_sales AS diff_avg,

    CASE
        WHEN c.current_sales IS NULL
          OR c.average_sales IS NULL
            THEN 'Insufficient Data'

        WHEN c.current_sales < c.average_sales
            THEN 'Under Average'

        WHEN c.current_sales > c.average_sales
            THEN 'Above Average'

        ELSE 'Average'
    END AS average_changes,

    -- Previous calendar-period comparison
    c.previous_period_sales,

    c.current_sales - c.previous_period_sales
        AS diff_previous_period,

    -- NULLIF prevents division by zero.
    ROUND(
        100.0 * (c.current_sales - c.previous_period_sales)
        / NULLIF(c.previous_period_sales, 0),
        2
    ) AS change_pct,

    c.period_changes

FROM period_comparison AS c

ORDER BY
    c.period_type DESC,
    c.product_name,
    c.period_start;
