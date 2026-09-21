/*
===============================================================================
RANKING ANALYSIS
===============================================================================
Purpose:
    Analyze product revenue, customer revenue, and customer order activity.

Database:
    Microsoft SQL Server (T-SQL)

Source Tables:
    gold.fact_sales
    gold.dim_products
    gold.dim_customers

Business Definitions:
    Revenue     = SUM(sales_amount)
    Total Orders = COUNT(DISTINCT order_number)

Ranking Rules:
    TOP:
        Return a fixed number of rows, using entity keys to break ties.

    RANK:
        Assign the same rank to equal revenue values.
        Filtering by rank may return more than N rows.

Data Grain:
    Product rankings  : One row per product_key
    Customer rankings : One row per customer_key

Assumptions:
    Dimension keys are unique.
    Product keys identify the intended product entities.
    Order numbers uniquely identify orders.
    All sales records are included without additional filters.

Notes:
    Revenue and order counts depend on the completeness
    and business definitions of the source fact table.
===============================================================================
*/


/*
===============================================================================
1. TOP 5 PRODUCTS BY REVENUE — TOP
===============================================================================
Business Question:
    Which five products generate the highest total revenue?

Output Grain:
    One row per product_key.

Ranking Rule:
    Return at most five products.
    Break revenue ties using product_key.
===============================================================================
*/

SELECT TOP (5)
    fs.product_key,
    p.product_name,
    SUM(fs.sales_amount) AS total_revenue
FROM gold.fact_sales AS fs
LEFT JOIN gold.dim_products AS p
    ON p.product_key = fs.product_key
GROUP BY
    fs.product_key,
    p.product_name
ORDER BY
    total_revenue DESC,
    fs.product_key ASC;


/*
===============================================================================
2. TOP 5 PRODUCTS BY REVENUE — RANK
===============================================================================
Business Question:
    Which products occupy the five highest competition
    ranking positions by total revenue?

Output Grain:
    One row per product_key.

Ranking Rule:
    Equal revenue values receive the same rank.
    Results may contain more than five products.
===============================================================================
*/

WITH ProductRevenue AS (
    SELECT
        fs.product_key,
        p.product_name,
        SUM(fs.sales_amount) AS total_revenue
    FROM gold.fact_sales AS fs
    LEFT JOIN gold.dim_products AS p
        ON p.product_key = fs.product_key
    GROUP BY
        fs.product_key,
        p.product_name
),
RankedProducts AS (
    SELECT
        product_key,
        product_name,
        total_revenue,
        RANK() OVER (
            ORDER BY total_revenue DESC
        ) AS product_rank
    FROM ProductRevenue
)
SELECT
    product_key,
    product_name,
    total_revenue,
    product_rank
FROM RankedProducts
WHERE product_rank <= 5
ORDER BY
    product_rank ASC,
    product_key ASC;


/*
===============================================================================
3. BOTTOM 5 PRODUCTS BY REVENUE — TOP
===============================================================================
Business Question:
    Which five products generate the lowest total revenue?

Output Grain:
    One row per product_key.

Ranking Rule:
    Return at most five products.
    Break revenue ties using product_key.

Scope:
    Only products represented in fact_sales are included.
===============================================================================
*/

SELECT TOP (5)
    fs.product_key,
    p.product_name,
    SUM(fs.sales_amount) AS total_revenue
FROM gold.fact_sales AS fs
LEFT JOIN gold.dim_products AS p
    ON p.product_key = fs.product_key
GROUP BY
    fs.product_key,
    p.product_name
ORDER BY
    total_revenue ASC,
    fs.product_key ASC;


/*
===============================================================================
4. BOTTOM 5 PRODUCTS BY REVENUE — RANK
===============================================================================
Business Question:
    Which products occupy the five lowest competition
    ranking positions by total revenue?

Output Grain:
    One row per product_key.

Ranking Rule:
    Equal revenue values receive the same rank.
    Results may contain more than five products.

Scope:
    Only products represented in fact_sales are included.
===============================================================================
*/

WITH ProductRevenue AS (
    SELECT
        fs.product_key,
        p.product_name,
        SUM(fs.sales_amount) AS total_revenue
    FROM gold.fact_sales AS fs
    LEFT JOIN gold.dim_products AS p
        ON p.product_key = fs.product_key
    GROUP BY
        fs.product_key,
        p.product_name
),
RankedProducts AS (
    SELECT
        product_key,
        product_name,
        total_revenue,
        RANK() OVER (
            ORDER BY total_revenue ASC
        ) AS product_rank
    FROM ProductRevenue
)
SELECT
    product_key,
    product_name,
    total_revenue,
    product_rank
FROM RankedProducts
WHERE product_rank <= 5
ORDER BY
    product_rank ASC,
    product_key ASC;


/*
===============================================================================
5. TOP 10 CUSTOMERS BY REVENUE — TOP
===============================================================================
Business Question:
    Which ten customers generate the highest total revenue?

Output Grain:
    One row per customer_key.

Ranking Rule:
    Return at most ten customers.
    Break revenue ties using customer_key.
===============================================================================
*/

SELECT TOP (10)
    fs.customer_key,
    CONCAT(
        c.first_name,
        ' ',
        c.last_name
    ) AS customer_name,
    SUM(fs.sales_amount) AS total_revenue
FROM gold.fact_sales AS fs
LEFT JOIN gold.dim_customers AS c
    ON c.customer_key = fs.customer_key
GROUP BY
    fs.customer_key,
    c.first_name,
    c.last_name
ORDER BY
    total_revenue DESC,
    fs.customer_key ASC;


/*
===============================================================================
6. TOP 10 CUSTOMERS BY REVENUE — RANK
===============================================================================
Business Question:
    Which customers occupy the ten highest competition
    ranking positions by total revenue?

Output Grain:
    One row per customer_key.

Ranking Rule:
    Equal revenue values receive the same rank.
    Results may contain more than ten customers.
===============================================================================
*/

WITH CustomerRevenue AS (
    SELECT
        fs.customer_key,
        CONCAT(
            c.first_name,
            ' ',
            c.last_name
        ) AS customer_name,
        SUM(fs.sales_amount) AS total_revenue
    FROM gold.fact_sales AS fs
    LEFT JOIN gold.dim_customers AS c
        ON c.customer_key = fs.customer_key
    GROUP BY
        fs.customer_key,
        c.first_name,
        c.last_name
),
RankedCustomers AS (
    SELECT
        customer_key,
        customer_name,
        total_revenue,
        RANK() OVER (
            ORDER BY total_revenue DESC
        ) AS customer_rank
    FROM CustomerRevenue
)
SELECT
    customer_key,
    customer_name,
    total_revenue,
    customer_rank
FROM RankedCustomers
WHERE customer_rank <= 10
ORDER BY
    customer_rank ASC,
    customer_key ASC;


/*
===============================================================================
7. BOTTOM 3 CUSTOMERS BY ORDER COUNT — TOP
===============================================================================
Business Question:
    Which three customers have placed the fewest orders?

Output Grain:
    One row per customer_key.

Business Rules:
    Include customers with zero matching orders.
    Count each distinct order number only once.

Ranking Rule:
    Return at most three customers.
    Break order-count ties using customer_key.

Important:
    Order activity is measured using records in fact_sales.
    Orders absent from fact_sales cannot be counted.
===============================================================================
*/

SELECT TOP (3)
    c.customer_key,
    CONCAT(
        c.first_name,
        ' ',
        c.last_name
    ) AS customer_name,
    COUNT(DISTINCT fs.order_number) AS total_orders
FROM gold.dim_customers AS c
LEFT JOIN gold.fact_sales AS fs
    ON fs.customer_key = c.customer_key
GROUP BY
    c.customer_key,
    c.first_name,
    c.last_name
ORDER BY
    total_orders ASC,
    c.customer_key ASC;

/*
===============================================================================
END OF RANKING ANALYSIS
===============================================================================
*/
