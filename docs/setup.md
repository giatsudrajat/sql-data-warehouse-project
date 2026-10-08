# Setup and execution

## Requirements

- SQL Server 2022+ for the complete project, including `DATETRUNC` analytics.
- A SQL Server connection with permission to create the development database, tables, views, and procedures; load files with `BULK INSERT`; and truncate staging tables.
- A SQL client that executes `GO` as a batch separator. SSMS and sqlcmd support this; configure your client accordingly if using DBeaver or DataGrip.
- The six raw files listed in [Source data](source_data.md).

The SQL client and database server may be on different machines. `BULK INSERT` resolves paths on the **SQL Server machine**, not the client laptop. A Mac can connect to a separate SQL Server instance.

## Prepare the input directory

Download the raw files with the commands in [Source data](source_data.md). The loader expects these paths:

| Server-side directory | Files |
| --- | --- |
| `/var/opt/mssql/datasets/source_crm/` | `cust_info.csv`, `prd_info.csv`, `sales_details.csv` |
| `/var/opt/mssql/datasets/source_erp/` | `cust_az12.csv`, `loc_a101.csv`, `px_cat_g1v2.csv` |

The upstream ERP filenames are uppercase; the download commands deliberately save them with the lowercase names used by the loader.

For an existing SQL Server container, run the following from the repository root. Replace the example container name with yours:

```bash
SQLSERVER_CONTAINER=your-sqlserver-container
docker exec -u 0 "$SQLSERVER_CONTAINER" mkdir -p /var/opt/mssql/datasets/source_crm /var/opt/mssql/datasets/source_erp
docker cp datasets/source_crm/. "$SQLSERVER_CONTAINER:/var/opt/mssql/datasets/source_crm/"
docker cp datasets/source_erp/. "$SQLSERVER_CONTAINER:/var/opt/mssql/datasets/source_erp/"
docker exec -u 0 "$SQLSERVER_CONTAINER" chmod -R a+rX /var/opt/mssql/datasets
```

Alternatively, mount the local `datasets/` directory at `/var/opt/mssql/datasets/` when creating your container. For Windows or another server layout, edit all six paths in [proc_load_bronze.sql](../scripts/bronze/proc_load_bronze.sql) to readable server-side locations.

Do not load `datasets/flat_files/` into Bronze. Those CSVs have a different schema; for example the reference product file has `subcategory`, while the generated Gold view exposes `sub_category`.

## First deployment

**The initialization script deletes an existing `DataWarehouse` database.** Bronze and Silver DDL scripts also drop and recreate their tables. Use this sequence for a disposable development installation.

Execute each file as a script, in this order. After initialization, select `DataWarehouse` as the database for every new connection or editor.

| Step | File or command | Result |
| --- | --- | --- |
| 1 | [scripts/init_database.sql](../scripts/init_database.sql) | Recreate `DataWarehouse` and its three schemas |
| 2 | [scripts/bronze/ddl_bronze_layer.sql](../scripts/bronze/ddl_bronze_layer.sql) | Create six Bronze tables |
| 3 | [scripts/bronze/proc_load_bronze.sql](../scripts/bronze/proc_load_bronze.sql) | Define the Bronze loader; does not execute it |
| 4 | `EXEC bronze.load_bronze;` | Import the six source files |
| 5 | [scripts/silver/ddl_silver_layer.sql](../scripts/silver/ddl_silver_layer.sql) | Create six Silver tables |
| 6 | [scripts/silver/proc_load_silver.sql](../scripts/silver/proc_load_silver.sql) | Define the Silver loader |
| 7 | `EXEC silver.load_silver;` | Clean and load Bronze data into Silver |
| 8 | [tests/quality_checks_silver_layer.sql](../tests/quality_checks_silver_layer.sql) | Inspect Silver checks and raw-data diagnostics |
| 9 | [scripts/gold/ddl_gold_layer.sql](../scripts/gold/ddl_gold_layer.sql) | Create the three core Gold views |
| 10 | [tests/quality_checks_gold_layer.sql](../tests/quality_checks_gold_layer.sql) | Inspect business-key, relationship, and reconciliation checks |
| 11 | [scripts/analytics/report_customers.sql](../scripts/analytics/report_customers.sql) | Create `gold.report_customer` |
| 12 | [scripts/analytics/report_products.sql](../scripts/analytics/report_products.sql) | Create `gold.report_products` |
| 13 | Analytical scripts in [scripts/analytics/](../scripts/analytics/) | Query the model; customer segmentation requires step 11 |

The singular SQL object name `gold.report_customer` is preserved for compatibility. Its filename is plural: `report_customers.sql`.

A connection-context check:

```sql
SELECT DB_NAME() AS current_database;
-- Expected before steps 2-13: DataWarehouse
```

## Subsequent refreshes

After preparing a complete, consistent set of source files, run:

```sql
USE DataWarehouse;
GO
EXEC bronze.load_bronze;
GO
EXEC silver.load_silver;
GO
```

Run quality checks after each layer. Gold views read refreshed Silver data without a separate load step. Recreate report or model views only when their definitions change.

Do not run the database-reset or table-DDL scripts during a normal data refresh. Refreshes are multi-statement and not atomic; stop downstream consumption if a loader fails, resolve the cause, and rerun the affected layer and its dependants. Error handlers print context and rethrow the SQL error.

## Troubleshooting

| Symptom | Check |
| --- | --- |
| Cannot open a CSV or operating-system file error | The file exists inside the server/container, its case matches, and SQL Server can read it |
| Error near `GO` | Use script mode and enable SQL Server batch-separator handling in the client |
| Invalid object name such as `bronze.crm_cust_info` | Check `DB_NAME()` and run the DDL before the loader |
| `DATETRUNC` is unavailable | Use SQL Server 2022+ for the full analysis suite |
| A loader stops partway through | Read the original error, correct the source/path/schema problem, rerun the layer, and repeat quality checks |
| Gold totals exceed Silver totals | Inspect duplicated business keys in dimensions and ERP join inputs before trusting the join results |
| Report totals differ from overall exploration | Reports filter out NULL order dates; reconcile using the same population |
| Old report filenames are missing | Use the new `.sql` filenames; the existing singular customer view name remains valid |

See [Data quality](data_quality.md) for regression-test execution in a disposable SQL Server environment.
