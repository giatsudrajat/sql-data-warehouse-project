/*
================================================================
DDL Script: Create Gold Layer Views
================================================================
Script Purpose:
    This script creates the views for the Gold Layer of the data
    warehouse.

    The Gold Layer represents business-ready data structured
    for analytical and reporting purposes using a star schema.

Objects Created:
    - gold.dim_customers
    - gold.dim_products
    - gold.fact_sales

Data Model:
    - gold.dim_customers : Customer dimension
    - gold.dim_products  : Product dimension
    - gold.fact_sales    : Sales fact

Source Layer:
    Silver Layer

Target Layer:
    Gold Layer

Data Flow:
    Silver -> Gold
================================================================
*/


-- ============================================================
-- Create Dimension: gold.dim_customers
-- ============================================================

IF OBJECT_ID('gold.dim_customers', 'V') IS NOT NULL
    DROP VIEW gold.dim_customers;
GO

CREATE OR ALTER VIEW gold.dim_customers
AS
SELECT
    ROW_NUMBER() OVER (
        ORDER BY ci.cst_id
    ) AS customer_key,
    ci.cst_id AS customer_id,
    ci.cst_key AS customer_number,
    ci.cst_firstname AS first_name,
    ci.cst_lastname AS last_name,

    -- Use ERP gender when CRM gender is missing or unknown
    CASE
        WHEN ci.cst_gndr IS NULL
          OR ci.cst_gndr = 'n/a'
            THEN COALESCE(ca.gen, 'n/a')
        ELSE ci.cst_gndr
    END AS gender,

    ca.bdate AS birthdate,
    ci.cst_marital_status AS marital_status,
    la.cntry AS country,
    ci.cst_create_date AS create_date
FROM silver.crm_cust_info AS ci
LEFT JOIN silver.erp_cust_az12 AS ca
    ON ci.cst_key = ca.cid
LEFT JOIN silver.erp_loc_a101 AS la
    ON ci.cst_key = la.cid;
GO


-- ============================================================
-- Create Dimension: gold.dim_products
-- ============================================================

IF OBJECT_ID('gold.dim_products', 'V') IS NOT NULL
    DROP VIEW gold.dim_products;
GO

CREATE OR ALTER VIEW gold.dim_products
AS
SELECT
    ROW_NUMBER() OVER (
        ORDER BY pi.prd_start_dt, pi.prd_key
    ) AS product_key,
    pi.prd_id AS product_id,
    pi.prd_key AS product_number,
    pi.prd_nm AS product_name,
    pi.cat_id AS category_id,
    pc.cat AS category,
    pc.subcat AS sub_category,
    pc.maintenance,
    pi.prd_cost AS cost,
    pi.prd_line AS product_line,
    pi.prd_start_dt AS start_date
FROM silver.crm_prd_info AS pi
LEFT JOIN silver.erp_px_cat_g1v2 AS pc
    ON pi.cat_id = pc.id
WHERE pi.prd_end_dt IS NULL;
GO


-- ============================================================
-- Create Fact: gold.fact_sales
-- ============================================================

IF OBJECT_ID('gold.fact_sales', 'V') IS NOT NULL
    DROP VIEW gold.fact_sales;
GO

CREATE OR ALTER VIEW gold.fact_sales
AS
SELECT
    sd.sls_ord_num AS order_number,
    pr.product_key,
    c.customer_key,
    sd.sls_order_dt AS order_date,
    sd.sls_ship_dt AS shipping_date,
    sd.sls_due_dt AS due_date,
    sd.sls_sales AS sales_amount,
    sd.sls_quantity AS quantity,
    sd.sls_price AS price
FROM silver.crm_sales_details AS sd
LEFT JOIN gold.dim_customers AS c
    ON sd.sls_cust_id = c.customer_id
LEFT JOIN gold.dim_products AS pr
    ON sd.sls_prd_key = pr.product_number;
GO
