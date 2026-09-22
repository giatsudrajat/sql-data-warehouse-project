/*
===============================================================================
CUMULATIVE ANALYSIS
===============================================================================
Purpose:
    Analyze yearly sales performance using cumulative calculations.

Source Table:
    gold.fact_sales

Business Metrics:
    1. Total Sales               - Total sales revenue per year
    2. Average Price             - Average recorded price per year
    3. Running Total Sales       - Cumulative sales across years
    4. Cumulative Average Price  - Average of yearly average prices
                                   from the first year to the current year

Data Grain:
    One row per calendar year with recorded sales.

Business Rules:
    - Exclude records with NULL order dates.
    - Aggregate sales and prices by calendar year.
    - Calculate running totals in chronological order.
    - Calculate the cumulative average of yearly average prices.
    - Give each year's average price equal weight.

Technical Notes:
    - Requires SQL Server 2022+ for DATETRUNC().
    - Missing calendar years are not generated.
    - Explicit ROWS frames define cumulative calculations.
===============================================================================
*/

WITH YearlySales AS (
    SELECT
        DATETRUNC(year, order_date) AS order_year,

        SUM(sales_amount) AS total_sales,
        AVG(price) AS avg_price

    FROM gold.fact_sales

    WHERE order_date IS NOT NULL

    GROUP BY
        DATETRUNC(year, order_date)
)

SELECT
    order_year,
    total_sales,
    avg_price,

    -- Accumulate sales from the first year through the current year
    SUM(total_sales) OVER (
        ORDER BY order_year
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS running_total_sales,

    -- Average yearly prices from the first year through the current year
    AVG(avg_price) OVER (
        ORDER BY order_year
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS cumulative_avg_price

FROM YearlySales

ORDER BY
    order_year;
