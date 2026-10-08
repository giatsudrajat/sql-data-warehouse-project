/*
===============================================================================
1. PRODUCT COST SEGMENTATION
===============================================================================

Purpose:
    Classify all products into predefined cost ranges to analyze
    the overall product distribution, regardless of sales activity.

Source Table:
    gold.dim_products

Output Grain:
    One row per product cost segment.

Business Rules:
    - Include all products, whether sold or unsold.
    - Each product is counted once.
    - Products with missing costs are classified as 'Unknown'.
===============================================================================
*/

;WITH product_segments AS (
    SELECT
        p.product_key,
        CASE
            WHEN p.cost IS NULL THEN 'Unknown'
            WHEN p.cost < 100     THEN 'Below 100'
            WHEN p.cost <= 500    THEN '100-500'
            WHEN p.cost <= 1000   THEN '500-1000'
            WHEN p.cost <= 1500   THEN '1000-1500'
            WHEN p.cost <= 2000   THEN '1500-2000'
            ELSE 'Above 2000'
        END AS cost_range
    FROM gold.dim_products AS p
)

SELECT
    cost_range,
    COUNT(*) AS total_products
FROM product_segments
GROUP BY
    cost_range
ORDER BY
    total_products DESC,
    cost_range;

/*
===============================================================================
2. CUSTOMER SPENDING SEGMENTATION
===============================================================================

Purpose:
    Classify customers based on their total spending and purchasing
    lifespan to identify different customer value segments.

Output Grain:
    One row per customer segment.

Business Rules:
    VIP:
        Lifespan >= 12 months AND total spending > 5,000

    Regular:
        Lifespan >= 12 months AND total spending <= 5,000

    Great:
        Lifespan < 12 months AND total spending > 10,000

    New:
        All remaining customers.

Notes:
    - Run report_customers.sql first to create gold.report_customer.
    - Reuse its inclusive lifespan, thresholds, LEFT JOIN, and valid-date filter.
    - total_customers counts known customer keys only.
    - unknown_customer_groups identifies the retained NULL-key bucket; it is not
      a count of distinct customers whose identities are unknown.
===============================================================================
*/

SELECT
    customer_segment,
    COUNT(customer_key) AS total_customers,
    COUNT(*) - COUNT(customer_key) AS unknown_customer_groups
FROM gold.report_customer
GROUP BY
    customer_segment
ORDER BY
    total_customers DESC,
    customer_segment;
