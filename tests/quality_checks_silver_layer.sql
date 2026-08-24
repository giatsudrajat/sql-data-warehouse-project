/*
===============================================================================
Quality Checks: Silver Layer
===============================================================================
Script Purpose:
    This script performs data quality checks to validate data consistency,
    accuracy, completeness, and standardization across the 'silver' schema.

Checks Performed:
    - Validate primary keys for NULL or duplicate values.
    - Identify unwanted spaces in string fields.
    - Review standardized categorical values.
    - Identify NULL or negative numeric values.
    - Validate date ranges and chronological relationships.
    - Validate consistency between related business measures.

Usage Notes:
    - Run these checks after loading data into the Silver Layer.
    - Queries marked with "Expectation: No Results" should return zero rows.
    - Review distinct-value checks to confirm that values follow the expected
      Silver Layer standardization rules.
    - Investigate and resolve any discrepancies found during validation.
===============================================================================
*/


-- ============================================================
-- Checking 'silver.crm_cust_info'
-- ============================================================

-- Check for NULL or duplicate primary keys
-- Expectation: No Results
SELECT
    cst_id,
    COUNT(*)
FROM silver.crm_cust_info
GROUP BY
    cst_id
HAVING COUNT(*) > 1
    OR cst_id IS NULL;


-- Check for unwanted spaces in customer keys
-- Expectation: No Results
SELECT
    cst_key
FROM silver.crm_cust_info
WHERE cst_key != TRIM(cst_key);


-- Review standardized marital status values
SELECT DISTINCT
    cst_marital_status
FROM silver.crm_cust_info;


-- ============================================================
-- Checking 'silver.crm_prd_info'
-- ============================================================

-- Check for NULL or duplicate primary keys
-- Expectation: No Results
SELECT
    prd_id,
    COUNT(*)
FROM silver.crm_prd_info
GROUP BY
    prd_id
HAVING COUNT(*) > 1
    OR prd_id IS NULL;


-- Check for unwanted spaces in product names
-- Expectation: No Results
SELECT
    prd_nm
FROM silver.crm_prd_info
WHERE prd_nm != TRIM(prd_nm);


-- Check for NULL or negative product costs
-- Expectation: No Results
SELECT
    prd_cost
FROM silver.crm_prd_info
WHERE prd_cost < 0
    OR prd_cost IS NULL;


-- Review standardized product line values
SELECT DISTINCT
    prd_line
FROM silver.crm_prd_info;


-- Check for invalid date order where end date precedes start date
-- Expectation: No Results
SELECT
    *
FROM silver.crm_prd_info
WHERE prd_end_dt < prd_start_dt;


-- ============================================================
-- Checking 'silver.crm_sales_details'
-- ============================================================

-- Check for invalid raw due-date values
-- Expectation: No Invalid Dates
SELECT
    NULLIF(sls_due_dt, 0) AS sls_due_date
FROM bronze.crm_sales_details
WHERE sls_due_dt <= 0
    OR LEN(sls_due_dt) != 8
    OR sls_due_dt > 20500101
    OR sls_due_dt < 19000101;


-- Check chronological consistency between order, shipping, and due dates
-- Expectation: No Results
SELECT
    *
FROM silver.crm_sales_details
WHERE sls_order_dt > sls_ship_dt
    OR sls_order_dt > sls_due_dt;


-- Check data consistency: Sales = Quantity * Price
-- Expectation: No Results
SELECT DISTINCT
    sls_sales,
    sls_quantity,
    sls_price
FROM silver.crm_sales_details
WHERE sls_sales != sls_quantity * sls_price
    OR sls_sales IS NULL
    OR sls_quantity IS NULL
    OR sls_price IS NULL
    OR sls_sales <= 0
    OR sls_quantity <= 0
    OR sls_price <= 0
ORDER BY
    sls_sales,
    sls_quantity,
    sls_price;


-- ============================================================
-- Checking 'silver.erp_cust_az12'
-- ============================================================

-- Identify birth dates outside the expected valid range
-- Expectation: Birth dates between 1916-02-10 and today
SELECT DISTINCT
    bdate
FROM silver.erp_cust_az12
WHERE bdate < '1916-02-10'
    OR bdate > GETDATE();


-- Review standardized gender values
SELECT DISTINCT
    gen
FROM silver.erp_cust_az12;


-- ============================================================
-- Checking 'silver.erp_loc_a101'
-- ============================================================

-- Review standardized country values
SELECT DISTINCT
    cntry
FROM silver.erp_loc_a101
ORDER BY
    cntry;


-- ============================================================
-- Checking 'silver.erp_px_cat_g1v2'
-- ============================================================

-- Check for unwanted spaces in category-related attributes
-- Expectation: No Results
SELECT
    *
FROM silver.erp_px_cat_g1v2
WHERE cat != TRIM(cat)
    OR subcat != TRIM(subcat)
    OR maintenance != TRIM(maintenance);


-- Review standardized maintenance values
SELECT DISTINCT
    maintenance
FROM silver.erp_px_cat_g1v2;
