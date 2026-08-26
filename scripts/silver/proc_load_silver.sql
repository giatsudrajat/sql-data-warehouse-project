/*
================================================================
Stored Procedure: Load Silver Layer (Bronze -> Silver)
================================================================
Script Purpose:
    This stored procedure performs the ETL (Extract, Transform, Load)
    process to populate the 'silver' schema tables from the 'bronze'
    schema.

Actions Performed:
    - Truncates the Silver tables before loading data.
    - Inserts transformed and cleansed data from Bronze into Silver tables.

Parameters:
    None.
    This stored procedure does not accept any parameters or return any values.

Usage Example:
    EXEC silver.load_silver;
================================================================
*/

CREATE OR ALTER PROCEDURE silver.load_silver
AS
BEGIN
    DECLARE
        @start_time       DATETIME,
        @end_time         DATETIME,
        @batch_start_time DATETIME,
        @batch_end_time   DATETIME;

    BEGIN TRY

        SET @batch_start_time = GETDATE();

        PRINT '========================================';
        PRINT 'Loading Silver Layer';
        PRINT '========================================';

        PRINT '----------------------------------------';
        PRINT 'Loading CRM TABLE';
        PRINT '----------------------------------------';


        -- ============================================================
        -- Load CRM Customer Information
        -- ============================================================

        SET @start_time = GETDATE();

        PRINT '>> Truncating Table: silver.crm_cust_info';
        TRUNCATE TABLE silver.crm_cust_info;

        PRINT '>> Inserting Data To: silver.crm_cust_info';

        INSERT INTO silver.crm_cust_info (
            cst_id,
            cst_key,
            cst_firstname,
            cst_lastname,
            cst_marital_status,
            cst_gndr,
            cst_create_date
        )
        SELECT
            cst_id,
            cst_key,
            TRIM(cst_firstname) AS cst_firstname,
            TRIM(cst_lastname) AS cst_lastname,

            -- Normalize marital status values to readable format
            CASE
                WHEN TRIM(UPPER(cst_marital_status)) = 'M' THEN 'Married'
                WHEN TRIM(UPPER(cst_marital_status)) = 'S' THEN 'Single'
                ELSE 'n/a'
            END AS cst_marital_status,

            -- Normalize gender values to readable format
            CASE
                WHEN TRIM(UPPER(cst_gndr)) = 'F' THEN 'Female'
                WHEN TRIM(UPPER(cst_gndr)) = 'M' THEN 'Male'
                ELSE 'n/a'
            END AS cst_gndr,

            cst_create_date
        FROM (
            SELECT
                *,
                ROW_NUMBER() OVER (
                    PARTITION BY cst_id
                    ORDER BY cst_create_date DESC
                ) AS flag_last
            FROM bronze.crm_cust_info
            WHERE cst_id IS NOT NULL
        ) AS t
        WHERE flag_last = 1; -- Select the most recent record per customer

        SET @end_time = GETDATE();

        PRINT '>> Load Duration: '
            + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR)
            + ' seconds';

        PRINT '----------------------------------------';


        -- ============================================================
        -- Load CRM Product Information
        -- ============================================================

        SET @start_time = GETDATE();

        PRINT '>> Truncating Table: silver.crm_prd_info';
        TRUNCATE TABLE silver.crm_prd_info;

        PRINT '>> Inserting Data To: silver.crm_prd_info';

        INSERT INTO silver.crm_prd_info (
            prd_id,
            cat_id,
            prd_key,
            prd_nm,
            prd_cost,
            prd_line,
            prd_start_dt,
            prd_end_dt
        )
        SELECT
            prd_id,

            -- Extract Category ID
            REPLACE(SUBSTRING(prd_key, 1, 5), '-', '_') AS cat_id,

            -- Extract Product Key
            SUBSTRING(prd_key, 7, LEN(prd_key)) AS prd_key,

            prd_nm,

            -- Replace NULL cost values with 0
            ISNULL(prd_cost, 0) AS prd_cost,

            -- Map product line code to descriptive value
            CASE UPPER(TRIM(prd_line))
                WHEN 'M' THEN 'Mountain'
                WHEN 'R' THEN 'Road'
                WHEN 'S' THEN 'Other Sales'
                WHEN 'T' THEN 'Touring'
                ELSE 'n/a'
            END AS prd_line,

            CAST(prd_start_dt AS DATE) AS prd_start_dt,

            -- Calculate end date as one day before the next start date
            CAST(
                LEAD(prd_start_dt) OVER (
                    PARTITION BY prd_key
                    ORDER BY prd_start_dt
                ) - 1 AS DATE
            ) AS prd_end_dt

        FROM bronze.crm_prd_info;

        SET @end_time = GETDATE();

        PRINT '>> Load Duration: '
            + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR)
            + ' seconds';

        PRINT '----------------------------------------';


        -- ============================================================
        -- Load CRM Sales Details
        -- ============================================================

        SET @start_time = GETDATE();

        PRINT '>> Truncating Table: silver.crm_sales_details';
        TRUNCATE TABLE silver.crm_sales_details;

        PRINT '>> Cleaning Data Using CTE and Inserting Data To: silver.crm_sales_details';

        ;WITH cleaned_data AS (
            SELECT
                sls_ord_num,
                sls_prd_key,
                sls_cust_id,

                -- Clean order date
                CASE
                    WHEN sls_order_dt IS NULL
                      OR sls_order_dt = 0
                        THEN NULL
                    ELSE TRY_CONVERT(
                        DATE,
                        CONVERT(VARCHAR(8), sls_order_dt),
                        112
                    )
                END AS sls_order_dt,

                -- Clean shipping date
                CASE
                    WHEN sls_ship_dt IS NULL
                      OR sls_ship_dt = 0
                        THEN NULL
                    ELSE TRY_CONVERT(
                        DATE,
                        CONVERT(VARCHAR(8), sls_ship_dt),
                        112
                    )
                END AS sls_ship_dt,

                -- Clean due date
                CASE
                    WHEN sls_due_dt IS NULL
                      OR sls_due_dt = 0
                        THEN NULL
                    ELSE TRY_CONVERT(
                        DATE,
                        CONVERT(VARCHAR(8), sls_due_dt),
                        112
                    )
                END AS sls_due_dt,

                sls_sales,
                sls_quantity,

                -- Derive price if original value is missing or invalid
                CASE
                    WHEN sls_price IS NULL
                      OR sls_price <= 0
                        THEN CAST(sls_sales AS DECIMAL(18, 4))
                             / NULLIF(sls_quantity, 0)
                    ELSE sls_price
                END AS sls_price

            FROM bronze.crm_sales_details
        )

        INSERT INTO silver.crm_sales_details (
            sls_ord_num,
            sls_prd_key,
            sls_cust_id,
            sls_order_dt,
            sls_ship_dt,
            sls_due_dt,
            sls_sales,
            sls_quantity,
            sls_price
        )
        SELECT
            sls_ord_num,
            sls_prd_key,
            sls_cust_id,
            sls_order_dt,
            sls_ship_dt,
            sls_due_dt,

            -- Recalculate sales if missing, invalid,
            -- or inconsistent with quantity * cleaned price
            CASE
                WHEN sls_sales IS NULL
                  OR sls_sales <= 0
                  OR sls_sales != sls_quantity * sls_price
                    THEN sls_quantity * sls_price
                ELSE sls_sales
            END AS sls_sales,

            sls_quantity,
            sls_price

        FROM cleaned_data;

        SET @end_time = GETDATE();

        PRINT '>> Load Duration: '
            + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR)
            + ' seconds';

        PRINT '----------------------------------------';


        -- ============================================================
        -- Load ERP Tables
        -- ============================================================

        PRINT '----------------------------------------';
        PRINT 'Loading ERP TABLE';
        PRINT '----------------------------------------';


        -- ============================================================
        -- Load ERP Customer Information
        -- ============================================================

        SET @start_time = GETDATE();

        PRINT '>> Truncating Table: silver.erp_cust_az12';
        TRUNCATE TABLE silver.erp_cust_az12;

        PRINT '>> Inserting Data To: silver.erp_cust_az12';

        INSERT INTO silver.erp_cust_az12 (
            cid,
            bdate,
            gen
        )
        SELECT
            -- Remove 'NAS' prefix if present
            CASE
                WHEN cid LIKE 'NAS%'
                    THEN SUBSTRING(cid, 4, LEN(cid))
                ELSE cid
            END AS cid,

            -- Set future birthdays to NULL
            CASE
                WHEN bdate > GETDATE() THEN NULL
                ELSE bdate
            END AS bdate,

            -- Normalize gender values and handle unknown cases
            CASE
                WHEN UPPER(TRIM(REPLACE(gen, CHAR(13), '')))
                     IN ('F', 'FEMALE')
                    THEN 'Female'
                WHEN UPPER(TRIM(REPLACE(gen, CHAR(13), '')))
                     IN ('M', 'MALE')
                    THEN 'Male'
                ELSE 'n/a'
            END AS gen

        FROM bronze.erp_cust_az12;

        SET @end_time = GETDATE();

        PRINT '>> Load Duration: '
            + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR)
            + ' seconds';

        PRINT '----------------------------------------';


        -- ============================================================
        -- Load ERP Location Information
        -- ============================================================

        SET @start_time = GETDATE();

        PRINT '>> Truncating Table: silver.erp_loc_a101';
        TRUNCATE TABLE silver.erp_loc_a101;

        PRINT '>> Inserting Data To: silver.erp_loc_a101';

        INSERT INTO silver.erp_loc_a101 (
            cid,
            cntry
        )
        SELECT
            REPLACE(cid, '-', '') AS cid,

            -- Normalize and handle missing or blank country codes
            CASE
                WHEN TRIM(UPPER(REPLACE(cntry, CHAR(13), '')))
                     IN ('USA', 'US')
                    THEN 'United States'
                WHEN TRIM(UPPER(REPLACE(cntry, CHAR(13), ''))) = 'DE'
                    THEN 'Germany'
                WHEN TRIM(REPLACE(cntry, CHAR(13), '')) = ''
                  OR cntry IS NULL
                    THEN 'n/a'
                ELSE TRIM(REPLACE(cntry, CHAR(13), ''))
            END AS cntry

        FROM bronze.erp_loc_a101;

        SET @end_time = GETDATE();

        PRINT '>> Load Duration: '
            + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR)
            + ' seconds';

        PRINT '----------------------------------------';


        -- ============================================================
        -- Load ERP Product Category Information
        -- ============================================================

        SET @start_time = GETDATE();

        PRINT '>> Truncating Table: silver.erp_px_cat_g1v2';
        TRUNCATE TABLE silver.erp_px_cat_g1v2;

        PRINT '>> Inserting Data To: silver.erp_px_cat_g1v2';

        INSERT INTO silver.erp_px_cat_g1v2 (
            id,
            cat,
            subcat,
            maintenance
        )
        SELECT
            id,
            cat,
            subcat,
            maintenance
        FROM bronze.erp_px_cat_g1v2;

        SET @end_time = GETDATE();

        PRINT '>> Load Duration: '
            + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR)
            + ' seconds';

        PRINT '----------------------------------------';


        -- ============================================================
        -- Batch Completion
        -- ============================================================

        SET @batch_end_time = GETDATE();

        PRINT '========================================';
        PRINT 'Loading Silver Layer is Completed';
        PRINT '    - Total Load Duration: '
            + CAST(
                DATEDIFF(
                    SECOND,
                    @batch_start_time,
                    @batch_end_time
                ) AS NVARCHAR
            )
            + ' seconds';
        PRINT '========================================';

    END TRY

    BEGIN CATCH

        PRINT '========================================';
        PRINT 'ERROR OCCURRED DURING LOADING SILVER LAYER';
        PRINT 'Error Message: ' + ERROR_MESSAGE();
        PRINT 'Error Number: ' + CAST(ERROR_NUMBER() AS NVARCHAR);
        PRINT 'Error State: ' + CAST(ERROR_STATE() AS NVARCHAR);
        PRINT '========================================';

    END CATCH;
END;
GO

EXEC silver.load_silver;
GO
