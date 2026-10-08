# Data quality and regression testing

## Diagnostic checks on a loaded warehouse

Run [quality_checks_silver_layer.sql](../tests/quality_checks_silver_layer.sql) after Silver loading and [quality_checks_gold_layer.sql](../tests/quality_checks_gold_layer.sql) after Gold view creation.

| Check category | Expected interpretation |
| --- | --- |
| Silver NULL/duplicate identifiers, invalid numeric measures, and date order | Zero violating rows; investigate every returned row |
| Standardized category/gender/country values | A result set is expected; inspect the allowed labels |
| Raw due-date profile inside the Silver check file | Diagnostic of Bronze inputs; dirty raw rows are not proof of failed Silver cleanup |
| Gold business-key uniqueness | Zero violating rows; check both dimension business keys and ERP join inputs |
| Gold unmatched references | Zero rows for complete source integration; returned rows identify exceptions retained by LEFT JOIN |
| Silver-to-Gold row/revenue reconciliation | Zero rows; mismatches can identify row multiplication or data loss |

These scripts expose result sets for review. They do not automatically mark a run as passed or failed. The uniqueness of a generated `ROW_NUMBER()` key alone does not prove that a business entity or fact row is unique.

Record the dataset version, SQL Server version, row counts, run time, violations, and any accepted exceptions when assessing a full-data build. Do not describe a diagnostic script existing in the repository as evidence that the data passed it.

## Automated regression suite

[run_regression.sql](../tests/run_regression.sql) executes the real database initialization, DDL, loaders, views, and analytic scripts against [small synthetic CSV fixtures](../tests/fixtures/). Assertions raise SQL errors on failure. It checks:

- Correct schema/column creation and customer deduplication.
- Expected Bronze/Silver/Gold row counts and revenue preservation.
- Current product selection and cleaned invalid order dates.
- Fractional customer averages and the inclusive 12-month segment boundary.
- Product weighted average price and exposed lifespan.
- Retention of unmatched sales in NULL-key groups.
- Known-customer segmentation counts without counting the unknown bucket as a customer.
- All analytical scripts compile and execute against the deployed objects.
- Re-running the loaders does not append duplicate data.

The workflow [.github/workflows/sql-regression.yml](../.github/workflows/sql-regression.yml) starts SQL Server 2022 in a disposable GitHub Actions service container. It copies fixtures into the same server-side paths used by the Bronze loader. Test credentials belong only to that short-lived container.

## Run the regression suite yourself

**Use a disposable SQL Server instance.** The suite calls `init_database.sql`, which drops and recreates `DataWarehouse`. Never run it against a database containing work you need to preserve.

From the repository root, with a disposable SQL Server container already running:

```bash
SQLSERVER_CONTAINER=your-disposable-sqlserver-container
docker exec -u 0 "$SQLSERVER_CONTAINER" mkdir -p /workspace /var/opt/mssql/datasets
docker cp . "$SQLSERVER_CONTAINER:/workspace"
docker cp tests/fixtures/. "$SQLSERVER_CONTAINER:/var/opt/mssql/datasets/"
docker exec -u 0 "$SQLSERVER_CONTAINER" chmod -R a+rX /workspace /var/opt/mssql/datasets
```

Run sqlcmd in that container with working directory `/workspace`, an authenticated SQL Server connection, certificate settings appropriate to the test environment, and these arguments:

```text
-b -i tests/run_regression.sql
```

The `-b` option makes assertion or SQL failures produce a nonzero exit status. The suite uses sqlcmd `:r` include directives, so it must be run through sqlcmd or a compatible SQLCMD mode.

The synthetic suite does not prove the external raw dataset is free of anomalies, guarantee production concurrency behavior, or benchmark performance. Run the diagnostic checks and record full-data results separately.
