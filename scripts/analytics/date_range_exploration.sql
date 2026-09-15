/*
===============================================================================
Date Range Exploration
===============================================================================
Purpose:
    Explore the date coverage of sales data and customer birthdates.

Analysis:
    - Identify the first and last order dates.
    - Calculate the order date range in months.
    - Identify the oldest and youngest customer birthdates.
    - Calculate customer ages based on completed birthdays.
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
-- Customer Age Range
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
