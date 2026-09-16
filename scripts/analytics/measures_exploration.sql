/*
===============================================================================
Measures Exploration
===============================================================================
Script Purpose:
    Explore key business metrics from the Gold Layer to evaluate overall
    sales performance, product coverage, and customer activity.

Source Tables:
    - gold.fact_sales
    - gold.dim_products
    - gold.dim_customers

Measures:
    1. Total Sales
    2. Total Quantity Sold
    3. Average Selling Price
    4. Total Orders
    5. Total Products
    6. Total Customers
    7. Customers Who Placed Orders (Exploration Only)

Report Output:
    Consolidates six core business measures into a two-column report:
    - measure_name
    - measure_value

Notes:
    - Total Orders counts distinct, non-NULL order numbers.
    - Average Selling Price is the unweighted average of non-NULL prices.
    - Product and customer counts use dimension records.
    - SUM(), AVG(), and COUNT(column) ignore NULL values.
    - COUNT(DISTINCT column) counts unique non-NULL values.
    - The consolidated report uses DECIMAL(38, 4) for measure values.
===============================================================================
*/


-- =============================================================================
-- 1. Sales Measures
-- =============================================================================

-- Calculate total recorded sales revenue
SELECT
    SUM(sales_amount) AS total_sales
FROM gold.fact_sales;


-- Calculate total quantity of items sold
SELECT
    SUM(quantity) AS total_sold_quantity
FROM gold.fact_sales;


-- Calculate the unweighted average selling price per fact row
SELECT
    AVG(price) AS average_price
FROM gold.fact_sales;


-- Count all sales rows with a non-NULL order number
SELECT
    COUNT(order_number) AS total_order_records
FROM gold.fact_sales;


-- Count unique orders to avoid counting multiple order lines
SELECT
    COUNT(DISTINCT order_number) AS total_orders
FROM gold.fact_sales;


-- =============================================================================
-- 2. Product Measures
-- =============================================================================

-- Count product records using non-NULL surrogate keys
SELECT
    COUNT(product_key) AS total_products
FROM gold.dim_products;


-- =============================================================================
-- 3. Customer Measures
-- =============================================================================

-- Count customer records using non-NULL surrogate keys
SELECT
    COUNT(customer_key) AS total_customers
FROM gold.dim_customers;


-- Count unique customers who appear in the sales fact table
SELECT
    COUNT(DISTINCT customer_key) AS total_customers_placed_orders
FROM gold.fact_sales;

-- =============================================================================
-- 4. Optimized Business Measures Report
-- =============================================================================

-- Consolidate sales aggregations to reduce repeated fact table references.
-- Aggregate product and customer dimensions independently to preserve
-- the intended grain and avoid unintended row multiplication.
-- Transform the resulting measures into reporting rows using CROSS APPLY.
WITH fact_measures AS (
    SELECT
        SUM(sales_amount) AS total_sales,
        SUM(quantity) AS total_quantity,
        AVG(price) AS average_price,
        COUNT(DISTINCT order_number) AS total_orders
    FROM gold.fact_sales
),

product_measures AS (
    SELECT
        COUNT(DISTINCT product_key) AS total_products
    FROM gold.dim_products
),

customer_measures AS (
    SELECT
        COUNT(customer_key) AS total_customers
    FROM gold.dim_customers
)

SELECT
    metrics.measure_name,
    metrics.measure_value
FROM fact_measures AS f
CROSS JOIN product_measures AS p
CROSS JOIN customer_measures AS c

CROSS APPLY (
    VALUES
        (
            'Total Sales',
            CAST(f.total_sales AS DECIMAL(38, 4))
        ),
        (
            'Quantity',
            CAST(f.total_quantity AS DECIMAL(38, 4))
        ),
        (
            'Average Price',
            CAST(f.average_price AS DECIMAL(38, 4))
        ),
        (
            'Total Orders',
            CAST(f.total_orders AS DECIMAL(38, 4))
        ),
        (
            'Total Products',
            CAST(p.total_products AS DECIMAL(38, 4))
        ),
        (
            'Total Customers',
            CAST(c.total_customers AS DECIMAL(38, 4))
        )
) AS metrics (
    measure_name,
    measure_value
);
