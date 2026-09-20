/*
===============================================================================
Magnitude Analysis
===============================================================================
Script Purpose:
    Analyze the magnitude and distribution of customers, products,
    revenue, and sold quantities across business dimensions.

Data Sources:
    - gold.dim_customers
    - gold.dim_products
    - gold.fact_sales

Analysis Performed:
    1. Customer distribution by country.
    2. Customer distribution by gender.
    3. Product distribution and percentage by category.
    4. Average product cost by category.
    5. Total revenue by product category.
    6. Total revenue by customer.
    7. Distribution of sold quantities by country.

Assumptions:
    - customer_key uniquely identifies a customer dimension row.
    - product_key uniquely identifies a product dimension row.
    - sales_amount represents the intended revenue measure.
    - quantity represents the intended sold quantity.
    - Missing dimension attributes remain visible as NULL groups.

===============================================================================
*/


-- =============================================================================
-- 1. Customer Distribution by Country
-- =============================================================================

-- Count all customer records, including those with missing country information.
SELECT
    country,
    COUNT(*) AS total_customers
FROM gold.dim_customers
GROUP BY
    country
ORDER BY
    total_customers DESC;


-- =============================================================================
-- 2. Customer Distribution by Gender
-- =============================================================================

-- Include customers with missing gender information in the distribution.
SELECT
    gender,
    COUNT(*) AS total_customers
FROM gold.dim_customers
GROUP BY
    gender
ORDER BY
    total_customers DESC;


-- =============================================================================
-- 3. Product Distribution by Category
-- =============================================================================

-- Calculate each category's contribution to the overall product count.
SELECT
    category,
    COUNT(*) AS total_products_by_category,

    SUM(COUNT(*)) OVER () AS total_products,

    CONCAT(
        CAST(
            COUNT(*) * 100.0
            / NULLIF(SUM(COUNT(*)) OVER (), 0)
            AS INT
        ),
        '%'
    ) AS product_percentage

FROM gold.dim_products
GROUP BY
    category
ORDER BY
    total_products_by_category DESC;


-- =============================================================================
-- 4. Average Product Cost by Category
-- =============================================================================

-- Use decimal arithmetic to preserve fractional precision for integer costs.
-- AVG excludes products with NULL cost values.
SELECT
    category,
    AVG(CAST(cost AS DECIMAL(19, 4))) AS average_cost
FROM gold.dim_products
GROUP BY
    category
ORDER BY
    average_cost DESC;


-- =============================================================================
-- 5. Total Revenue by Product Category
-- =============================================================================

-- Preserve sales without a matching product dimension record.
-- Unmatched products and products with NULL categories appear under NULL.
SELECT
    p.category,
    SUM(fs.sales_amount) AS total_revenue
FROM gold.fact_sales AS fs
LEFT JOIN gold.dim_products AS p
    ON p.product_key = fs.product_key
GROUP BY
    p.category
ORDER BY
    total_revenue DESC;


-- =============================================================================
-- 6. Total Revenue by Customer
-- =============================================================================

-- Group by customer key to avoid combining customers with identical names.
-- Preserve sales without a matching customer dimension record.
SELECT
    fs.customer_key,
    CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
    SUM(fs.sales_amount) AS total_revenue
FROM gold.fact_sales AS fs
LEFT JOIN gold.dim_customers AS c
    ON c.customer_key = fs.customer_key
GROUP BY
    fs.customer_key,
    CONCAT(c.first_name, ' ', c.last_name)
ORDER BY
    total_revenue DESC;


-- =============================================================================
-- 7. Distribution of Sold Items by Country
-- =============================================================================

-- Sum sold quantities rather than counting sales records.
-- Preserve sales without matching customer dimension records.
SELECT
    c.country,
    SUM(fs.quantity) AS total_sold_items
FROM gold.fact_sales AS fs
LEFT JOIN gold.dim_customers AS c
    ON c.customer_key = fs.customer_key
GROUP BY
    c.country
ORDER BY
    total_sold_items DESC;
