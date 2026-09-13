/*
================================================================
Dimension Exploration
================================================================
Script Purpose:
    This script explores key categorical dimensions in the Gold
    layer to understand the available customer and product
    attributes used for analysis.

Exploration Performed:
    - Explores customer geography and demographic attributes.
    - Explores product hierarchy and categorical attributes.
================================================================
*/


-- ============================================================
-- Explore Customer Geography
-- ============================================================

-- Identify the unique countries represented in the customer dimension
SELECT DISTINCT
    country
FROM gold.dim_customers
ORDER BY
    country;


-- ============================================================
-- Explore Customer Demographics
-- ============================================================

-- Identify the available gender classifications
SELECT DISTINCT
    gender
FROM gold.dim_customers
ORDER BY
    gender;

-- Identify the available marital status classifications
SELECT DISTINCT
    marital_status
FROM gold.dim_customers
ORDER BY
    marital_status;


-- ============================================================
-- Explore Product Hierarchy
-- ============================================================

-- Identify the available category, subcategory, and product combinations
SELECT DISTINCT
    category,
    sub_category,
    product_name
FROM gold.dim_products
ORDER BY
    category,
    sub_category,
    product_name;


-- ============================================================
-- Explore Product Attributes
-- ============================================================

-- Identify the available product line classifications
SELECT DISTINCT
    product_line
FROM gold.dim_products
ORDER BY
    product_line;

-- Identify the available product maintenance classifications
SELECT DISTINCT
    maintenance
FROM gold.dim_products
ORDER BY
    maintenance;
