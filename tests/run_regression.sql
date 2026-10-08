/*
Run from the repository root through sqlcmd -b in a DISPOSABLE SQL Server.
This suite resets DataWarehouse. Fixtures must be copied to
/var/opt/mssql/datasets before execution. Never use a valuable database.
*/
:on error exit
:r scripts/init_database.sql
:r scripts/bronze/ddl_bronze_layer.sql
GO
:r scripts/bronze/proc_load_bronze.sql
GO
EXEC bronze.load_bronze;
GO
:r scripts/silver/ddl_silver_layer.sql
GO
:r scripts/silver/proc_load_silver.sql
GO
EXEC silver.load_silver;
GO
:r scripts/gold/ddl_gold_layer.sql
:r scripts/analytics/report_customers.sql
GO
:r scripts/analytics/report_products.sql
GO

IF (SELECT COUNT(*) FROM bronze.crm_sales_details) <> 9
    THROW 51000, 'Bronze fixture import did not load nine sales rows.', 1;
IF (SELECT COUNT(*) FROM silver.crm_cust_info) <> 3
    THROW 51001, 'Customer deduplication failed.', 1;
IF NOT EXISTS (
    SELECT 1 FROM silver.crm_cust_info
    WHERE cst_id = 1 AND cst_lastname = 'Latest' AND cst_marital_status = 'Married'
)
    THROW 51002, 'Latest customer selection or marital-status mapping failed.', 1;
IF (SELECT COUNT(*) FROM gold.dim_products) <> 3
    THROW 51003, 'Current product selection failed.', 1;
IF NOT EXISTS (
    SELECT 1 FROM gold.dim_products
    WHERE product_number = 'P3' AND product_name = 'Test History Current'
)
    THROW 51004, 'Gold did not select the current product version.', 1;
IF (SELECT COUNT(*) FROM gold.fact_sales) <> 9
    THROW 51005, 'Gold joins changed the source sales row count.', 1;
IF (SELECT SUM(sales_amount) FROM gold.fact_sales) <> 15276
    THROW 51006, 'Sales corrections or revenue reconciliation failed.', 1;
IF NOT EXISTS (
    SELECT 1 FROM gold.fact_sales WHERE order_number = 'SO6' AND order_date IS NULL
)
    THROW 51007, 'An invalid calendar date was not cleaned to NULL.', 1;
IF NOT EXISTS (
    SELECT 1 FROM gold.fact_sales WHERE order_number = 'SO8' AND sales_amount = 14
)
    THROW 51008, 'Sales repair from quantity and price failed.', 1;
IF NOT EXISTS (
    SELECT 1 FROM gold.fact_sales WHERE order_number = 'SO9' AND price = 5
)
    THROW 51009, 'Missing price repair failed.', 1;
IF NOT EXISTS (
    SELECT 1 FROM gold.report_customer
    WHERE customer_number = 'AW0001'
      AND total_orders = 2 AND total_sales = 101
      AND lifespan_months = 12 AND customer_segment = 'Regular'
      AND average_order_value = 50.50 AND average_monthly_spend = 8.42
)
    THROW 51010, 'Fractional averages or inclusive twelve-month boundary failed.', 1;
IF NOT EXISTS (
    SELECT 1 FROM gold.report_customer
    WHERE customer_number = 'AW0002' AND total_sales = 10025
      AND customer_segment = 'Great' AND average_order_value = 3341.67
)
    THROW 51011, 'Great segment or valid-date filtering failed.', 1;
IF NOT EXISTS (
    SELECT 1 FROM gold.report_customer
    WHERE customer_number = 'AW0003' AND customer_segment = 'VIP'
)
    THROW 51012, 'VIP segment boundary failed.', 1;
IF NOT EXISTS (
    SELECT 1 FROM gold.report_customer
    WHERE customer_key IS NULL AND customer_name = 'Unknown' AND total_sales = 9
)
    THROW 51013, 'Unmatched customer sales were lost.', 1;
IF NOT EXISTS (
    SELECT 1 FROM gold.report_products
    WHERE product_name = 'Test Road' AND total_sales = 111
      AND total_quantity = 7 AND lifespan_months = 12
      AND avg_selling_price = 15.86 AND avg_monthly_revenue = 9.25
)
    THROW 51014, 'Weighted product price or inclusive-month revenue failed.', 1;
IF NOT EXISTS (
    SELECT 1 FROM gold.report_products WHERE product_key IS NULL AND total_sales = 9
)
    THROW 51015, 'Unmatched product sales were lost.', 1;
IF (SELECT SUM(total_sales) FROM gold.report_customer) <> 15236
 OR (SELECT SUM(total_sales) FROM gold.report_products) <> 15236
    THROW 51016, 'Report populations do not reconcile to dated sales.', 1;
IF (SELECT COUNT(customer_key) FROM gold.report_customer) <> 3
 OR (SELECT COUNT(*) - COUNT(customer_key) FROM gold.report_customer) <> 1
    THROW 51017, 'Known customer counts and unknown group were not separated.', 1;
IF EXISTS (
    SELECT 1 FROM sys.columns
    WHERE object_id IN (OBJECT_ID('gold.dim_customers'), OBJECT_ID('gold.dim_products'))
      AND name IN ('customer_key', 'product_key') AND TYPE_NAME(system_type_id) <> 'bigint'
)
    THROW 51018, 'Gold key types differ from the catalog.', 1;
GO

-- Smoke-test every analysis against the real deployed object definitions.
:r scripts/analytics/database_exploration.sql
GO
:r scripts/analytics/dimension_exploration.sql
GO
:r scripts/analytics/date_range_exploration.sql
GO
:r scripts/analytics/measures_exploration.sql
GO
:r scripts/analytics/magnitude_analysis.sql
GO
:r scripts/analytics/ranking_analysis.sql
GO
:r scripts/analytics/change_over_time_analysis.sql
GO
:r scripts/analytics/cumulative_analysis.sql
GO
:r scripts/analytics/performance_analysis.sql
GO
:r scripts/analytics/data_segmentation.sql
GO
:r scripts/analytics/part_to_whole_analysis.sql
GO

-- A second full refresh must replace the data rather than append to it.
EXEC bronze.load_bronze;
EXEC silver.load_silver;
GO
IF (SELECT COUNT(*) FROM gold.fact_sales) <> 9
 OR (SELECT SUM(sales_amount) FROM gold.fact_sales) <> 15276
 OR (SELECT COUNT(*) FROM gold.report_customer) <> 4
    THROW 51019, 'Repeated full refresh changed fixture cardinality or revenue.', 1;
PRINT 'PASS: SQL Server warehouse and report regression suite.';
GO
