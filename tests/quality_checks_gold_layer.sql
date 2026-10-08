/*
===============================================================================
Quality Checks
===============================================================================

Script Purpose:
    This script performs quality checks to validate the integrity, consistency,
    and accuracy of the Gold Layer. These checks ensure:

    - Uniqueness of surrogate keys in dimension tables.
    - Referential integrity between fact and dimension tables.
    - Validation of relationships in the data model for analytical purposes.

Usage Notes:
    - Run these checks after the Gold Layer views have been created.
    - Investigate and resolve any discrepancies found during the checks.

===============================================================================
*/


-- ============================================================
-- Checking 'gold.dim_customers'
-- ============================================================

-- Check for Uniqueness of Customer Key in gold.dim_customers
-- Expectation: No results

SELECT
    customer_key,
    COUNT(*) AS duplicate_count
FROM gold.dim_customers
GROUP BY
    customer_key
HAVING COUNT(*) > 1;


-- ============================================================
-- Checking 'gold.dim_products'
-- ============================================================

-- Check for Uniqueness of Product Key in gold.dim_products
-- Expectation: No results

SELECT
    product_key,
    COUNT(*) AS duplicate_count
FROM gold.dim_products
GROUP BY
    product_key
HAVING COUNT(*) > 1;


-- ============================================================
-- Checking 'gold.fact_sales'
-- ============================================================

-- Check the data model connectivity between fact and dimensions
-- Expectation: No results

SELECT
    f.*
FROM gold.fact_sales AS f
LEFT JOIN gold.dim_customers AS c
    ON c.customer_key = f.customer_key
LEFT JOIN gold.dim_products AS p
    ON p.product_key = f.product_key
WHERE c.customer_key IS NULL
   OR p.product_key IS NULL;

-- ============================================================
-- Business-key checks: generated row numbers alone cannot detect
-- duplicated entities or join amplification. Expectation: No results.
-- ============================================================
SELECT customer_id, COUNT(*) AS duplicate_count
FROM gold.dim_customers
GROUP BY customer_id
HAVING COUNT(*) > 1 OR customer_id IS NULL;

SELECT product_number, COUNT(*) AS duplicate_count
FROM gold.dim_products
GROUP BY product_number
HAVING COUNT(*) > 1 OR product_number IS NULL;

SELECT cid, COUNT(*) AS duplicate_count
FROM silver.erp_cust_az12
GROUP BY cid
HAVING COUNT(*) > 1 OR cid IS NULL;

SELECT cid, COUNT(*) AS duplicate_count
FROM silver.erp_loc_a101
GROUP BY cid
HAVING COUNT(*) > 1 OR cid IS NULL;

SELECT id, COUNT(*) AS duplicate_count
FROM silver.erp_px_cat_g1v2
GROUP BY id
HAVING COUNT(*) > 1 OR id IS NULL;

-- Silver-to-Gold reconciliation. Expectation: No results.
-- Count both rows and known revenue values; compare sums as BIGINT.
WITH silver_totals AS (
    SELECT COUNT_BIG(*) AS row_count,
           COUNT_BIG(sls_sales) AS revenue_count,
           SUM(CAST(sls_sales AS BIGINT)) AS total_sales
    FROM silver.crm_sales_details
), gold_totals AS (
    SELECT COUNT_BIG(*) AS row_count,
           COUNT_BIG(sales_amount) AS revenue_count,
           SUM(CAST(sales_amount AS BIGINT)) AS total_sales
    FROM gold.fact_sales
)
SELECT s.row_count AS silver_rows, g.row_count AS gold_rows,
       s.total_sales AS silver_sales, g.total_sales AS gold_sales
FROM silver_totals AS s
CROSS JOIN gold_totals AS g
WHERE s.row_count <> g.row_count
   OR s.revenue_count <> g.revenue_count
   OR COALESCE(s.total_sales, 0) <> COALESCE(g.total_sales, 0);
