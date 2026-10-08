/*
===============================================================================
Product Report
===============================================================================
Purpose:
    Creates a product-level analytical view containing sales performance,
    customer activity, recency, segmentation, and revenue metrics.

Output Grain:
    One row per known product_key, plus one NULL-key group for unmatched sales.
===============================================================================
*/

CREATE OR ALTER VIEW gold.report_products
AS

WITH base_query AS (
    /*---------------------------------------------------------------------------
    1) Base Query
       Retrieves sales transactions and related product attributes.

       Unmatched sales are retained in one NULL-key group.
       Original product numbers are not exposed by gold.fact_sales.
    ---------------------------------------------------------------------------*/
    SELECT
        fs.order_number,
        fs.order_date,
        fs.customer_key,
        fs.sales_amount,
        fs.quantity,
        fs.product_key,
        p.product_name,
        p.category,
        p.sub_category,
        p.cost
    FROM gold.fact_sales AS fs
    LEFT JOIN gold.dim_products AS p
        ON p.product_key = fs.product_key
    WHERE fs.order_date IS NOT NULL
),

product_aggregation AS (
    /*---------------------------------------------------------------------------
    2) Product Aggregation
       Summarizes sales activity at the product level.
    ---------------------------------------------------------------------------*/
    SELECT
        product_key,
        product_name,
        category,
        sub_category,
        cost,

        -- Inclusive first-to-last-sale span, including months without sales
        DATEDIFF(
            MONTH,
            MIN(order_date),
            MAX(order_date)
        ) + 1 AS lifespan_months,

        MAX(order_date) AS last_sale_date,

        COUNT(DISTINCT order_number) AS total_orders,
        COUNT(DISTINCT customer_key) AS total_customers,

        SUM(CAST(sales_amount AS BIGINT)) AS total_sales,
        SUM(CAST(quantity AS BIGINT)) AS total_quantity,

        -- Weighted average selling price per unit
        CAST(
            SUM(CAST(sales_amount AS DECIMAL(18, 2)))
            / NULLIF(
                SUM(CAST(quantity AS DECIMAL(18, 2))),
                0
            )
            AS DECIMAL(18, 2)
        ) AS avg_selling_price

    FROM base_query
    GROUP BY
        product_key,
        product_name,
        category,
        sub_category,
        cost
)

/*-------------------------------------------------------------------------------
3) Final Query
   Adds recency, product segmentation, and average revenue KPIs.
-------------------------------------------------------------------------------*/
SELECT
    product_key,
    product_name,
    category,
    sub_category,
    cost,

    -- Months since the most recent sale
    DATEDIFF(
        MONTH,
        last_sale_date,
        GETDATE()
    ) AS recency_in_months,

    -- Product performance classification
    CASE
        WHEN total_sales > 50000 THEN 'High-Performer'
        WHEN total_sales >= 10000 THEN 'Mid-Range'
        ELSE 'Low-Performer'
    END AS product_segment,

    last_sale_date,
    lifespan_months,
    total_orders,
    total_customers,
    total_sales,
    total_quantity,
    avg_selling_price,

    -- Average revenue generated per distinct order
    CAST(
        CAST(total_sales AS DECIMAL(18, 2))
        / NULLIF(total_orders, 0)
        AS DECIMAL(18, 2)
    ) AS avg_order_revenue,

    -- Average revenue per month in the inclusive first-to-last-sale span
    CAST(
        CAST(total_sales AS DECIMAL(18, 2))
        / NULLIF(lifespan_months, 0)
        AS DECIMAL(18, 2)
    ) AS avg_monthly_revenue

FROM product_aggregation;
