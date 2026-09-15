/*
===============================================================================
Date Range Exploration
===============================================================================
Purpose:
    Explore date coverage and identify potential date-related data quality issues.
===============================================================================
*/


-- ============================================================================
-- Sales Order Date Range
-- ============================================================================

SELECT
    MIN(order_date) AS first_order_date,
    MAX(order_date) AS last_order_date,
    DATEDIFF(
        MONTH,
        MIN(order_date),
        MAX(order_date)
    ) AS order_range_in_months
FROM gold.fact_sales;


-- ============================================================================
-- Sales Date Coverage
-- ============================================================================

SELECT
    COUNT(DISTINCT YEAR(order_date)) AS number_of_years,
    COUNT(DISTINCT FORMAT(order_date, 'yyyy-MM')) AS number_of_months
FROM gold.fact_sales
WHERE order_date IS NOT NULL;


-- ============================================================================
-- Sales Date Quality Check
-- ============================================================================

SELECT
    COUNT(*) AS total_rows,
    COUNT(order_date) AS rows_with_order_date,
    COUNT(*) - COUNT(order_date) AS rows_with_missing_order_date
FROM gold.fact_sales;


-- ============================================================================
-- Future Order Date Check
-- ============================================================================

SELECT
    COUNT(*) AS future_order_count
FROM gold.fact_sales
WHERE order_date > GETDATE();


-- ============================================================================
-- Customer Birthdate Range
-- ============================================================================

SELECT
    MIN(birthdate) AS oldest_birthdate,

    DATEDIFF(
        YEAR,
        MIN(birthdate),
        GETDATE()
    )
    - CASE
        WHEN DATEADD(
            YEAR,
            DATEDIFF(YEAR, MIN(birthdate), GETDATE()),
            MIN(birthdate)
        ) > GETDATE()
            THEN 1
        ELSE 0
      END AS oldest_age,

    MAX(birthdate) AS youngest_birthdate,

    DATEDIFF(
        YEAR,
        MAX(birthdate),
        GETDATE()
    )
    - CASE
        WHEN DATEADD(
            YEAR,
            DATEDIFF(YEAR, MAX(birthdate), GETDATE()),
            MAX(birthdate)
        ) > GETDATE()
            THEN 1
        ELSE 0
      END AS youngest_age

FROM gold.dim_customers;


-- ============================================================================
-- Customer Birthdate Quality Check
-- ============================================================================

SELECT
    COUNT(*) AS total_customers,
    COUNT(birthdate) AS customers_with_birthdate,
    COUNT(*) - COUNT(birthdate) AS customers_with_missing_birthdate
FROM gold.dim_customers;
