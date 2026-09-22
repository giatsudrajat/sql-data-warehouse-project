/*
===============================================================================
CHANGE OVER TIME ANALYSIS
===============================================================================
Purpose:
    Analyze monthly sales performance and identify changes in sales over time.

Source Table:
    gold.fact_sales

Business Metrics:
    1. Total Customers      - Unique customers per month
    2. Total Sales          - Total sales revenue per month
    3. Total Sold Products  - Total quantity sold per month
    4. Previous Month Sales - Sales from the previous available period
    5. Sales Change         - Absolute change in sales
    6. Sales Growth (%)     - Percentage change in sales

Data Grain:
    One row per calendar month with recorded sales.

Business Rules:
    - Exclude records with NULL order dates.
    - Count each customer once per month.
    - Aggregate sales and quantity by calendar month.
    - Maintain chronological ordering.
    - Return NULL when previous-period sales are unavailable.
    - Return NULL for growth percentage when previous sales equal zero.

Technical Notes:
    - SQL Server 2022+ is required for DATETRUNC().
    - Missing months are not generated.
    - Previous-period comparisons use the preceding available month.
===============================================================================
*/


/*
===============================================================================
1. MONTHLY SALES PERFORMANCE
===============================================================================
Purpose:
    Aggregate sales performance by calendar month.

Output Grain:
    One row per month.
===============================================================================
*/

SELECT
    DATETRUNC(month, order_date) AS order_month,

    COUNT(DISTINCT customer_key) AS total_customers,
    SUM(sales_amount) AS total_sales,
    SUM(quantity) AS total_sold_products

FROM gold.fact_sales

WHERE order_date IS NOT NULL

GROUP BY
    DATETRUNC(month, order_date)

ORDER BY
    order_month;


/*
===============================================================================
2. MONTHLY SALES CHANGE ANALYSIS
===============================================================================
Purpose:
    Compare monthly sales against the previous available month.

Calculation:
    Sales Change = Current Sales - Previous Sales

    Sales Growth (%) =
        (Current Sales - Previous Sales) / Previous Sales * 100

Output Grain:
    One row per month.

Note:
    LAG() retrieves the previous available row.
    Missing calendar months are not automatically included.
===============================================================================
*/

WITH MonthlySales AS (
    SELECT
        DATETRUNC(month, order_date) AS order_month,

        SUM(sales_amount) AS total_sales

    FROM gold.fact_sales

    WHERE order_date IS NOT NULL

    GROUP BY
        DATETRUNC(month, order_date)
),

SalesWithPrevious AS (
    SELECT
        order_month,
        total_sales,

        LAG(total_sales) OVER (
            ORDER BY order_month
        ) AS previous_month_sales

    FROM MonthlySales
)

SELECT
    order_month,
    total_sales,
    previous_month_sales,

    -- Absolute change compared with the previous available month
    total_sales - previous_month_sales AS sales_change,

    -- Percentage change; NULLIF prevents division by zero
    ROUND(
        100.0 * (total_sales - previous_month_sales)
        / NULLIF(previous_month_sales, 0),
        2
    ) AS sales_growth_pct

FROM SalesWithPrevious

ORDER BY
    order_month;
