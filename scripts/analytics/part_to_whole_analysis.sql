
/*
===============================================================================
PART-TO-WHOLE ANALYSIS
===============================================================================
Purpose:
    Analyze the contribution of individual business segments to overall sales.

Analyses:
    1. Sales contribution by product category.
    2. Sales contribution by customer country.

Metrics:
    - Total sales for each segment.
    - Overall sales across all segments.
    - Percentage contribution to overall sales.

Notes:
    - Unmatched dimension records are retained through LEFT JOIN.
    - NULLIF prevents division-by-zero errors.
    - Percentage calculations use decimal arithmetic.
    - Percentages are rounded to two decimal places.
===============================================================================
*/


/*
===============================================================================
1. SALES CONTRIBUTION BY PRODUCT CATEGORY
===============================================================================
Purpose:
    Calculate each product category's contribution to overall sales.

Output Grain:
    One row per product category.
===============================================================================
*/

;WITH category_sales AS (
    SELECT
        p.category,
        SUM(fs.sales_amount) AS total_sales
    FROM gold.fact_sales AS fs
    LEFT JOIN gold.dim_products AS p
        ON p.product_key = fs.product_key
    GROUP BY
        p.category
)

SELECT
    category,
    total_sales,

    -- Calculate overall sales across all categories.
    SUM(total_sales) OVER () AS overall_sales,

    -- Calculate each category's percentage contribution.
    CAST(
        ROUND(
            100.0 * total_sales
            / NULLIF(SUM(total_sales) OVER (), 0),
            2
        ) AS DECIMAL(10, 2)
    ) AS sales_percentage

FROM category_sales
ORDER BY
    sales_percentage DESC,
    category ASC;


/*
===============================================================================
2. SALES CONTRIBUTION BY CUSTOMER COUNTRY
===============================================================================
Purpose:
    Calculate each customer country's contribution to overall sales.

Output Grain:
    One row per customer country.
===============================================================================
*/

;WITH country_sales AS (
    SELECT
        c.country,
        SUM(fs.sales_amount) AS total_sales
    FROM gold.fact_sales AS fs
    LEFT JOIN gold.dim_customers AS c
        ON c.customer_key = fs.customer_key
    GROUP BY
        c.country
)

SELECT
    country,
    total_sales,

    -- Calculate overall sales across all countries.
    SUM(total_sales) OVER () AS overall_sales,

    -- Calculate each country's percentage contribution.
    CAST(
        ROUND(
            100.0 * total_sales
            / NULLIF(SUM(total_sales) OVER (), 0),
            2
        ) AS DECIMAL(10, 2)
    ) AS sales_percentage

FROM country_sales
ORDER BY
    sales_percentage DESC,
    country ASC;
