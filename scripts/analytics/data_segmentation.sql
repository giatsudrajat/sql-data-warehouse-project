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
    - Total spending is calculated across all recorded sales.
    - Customer lifespan is measured between the first and last order.
    - DATEDIFF(MONTH) counts calendar-month boundaries.
    - Only customers with recorded sales are included.
    - Only customers with recorded sales and matching customer
    - Dimension records are included.
===============================================================================
*/

;WITH customer_spending AS (
    SELECT
        c.customer_key,
        SUM(fs.sales_amount) AS total_spending,
        MIN(fs.order_date) AS first_order_date,
        MAX(fs.order_date) AS last_order_date,
        DATEDIFF(
            MONTH,
            MIN(fs.order_date),
            MAX(fs.order_date)
        ) AS life_span_months
    FROM gold.fact_sales AS fs
    INNER JOIN gold.dim_customers AS c
        ON fs.customer_key = c.customer_key
    GROUP BY
        c.customer_key
),

customer_segments AS (
    SELECT
        customer_key,
        CASE
            WHEN life_span_months >= 12
                 AND total_spending > 5000
                THEN 'VIP'

            WHEN life_span_months >= 12
                 AND total_spending <= 5000
                THEN 'Regular'

            WHEN life_span_months < 12
                 AND total_spending > 10000
                THEN 'Great'

            ELSE 'New'
        END AS customer_segment
    FROM customer_spending
)

SELECT
    customer_segment,
    COUNT(*) AS total_customers
FROM customer_segments
GROUP BY
    customer_segment
ORDER BY
    total_customers DESC,
    customer_segment;

/*
===============================================================================
END OF DATA SEGMENTATION
===============================================================================
*/
