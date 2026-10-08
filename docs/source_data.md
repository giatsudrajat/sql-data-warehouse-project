# Source data

## Two different data sets

The repository contains three reference CSVs under [datasets/flat_files/](../datasets/flat_files/): `dim_customers.csv`, `dim_products.csv`, and `fact_sales.csv`. These are Gold-shaped data for inspection. They are not consumed by either loader, and their keys and column names must not be assumed to match a fresh warehouse build.

The Bronze pipeline requires **six raw CRM/ERP CSVs**, obtained separately from [Data with Baraa's SQL Data Warehouse Project](https://github.com/DataWithBaraa/sql-data-warehouse-project). The documented source snapshot is commit [`9240668`](https://github.com/DataWithBaraa/sql-data-warehouse-project/commit/92406686380cde6eca208c8b43e6fa40ecd26344).

The raw source is MIT-licensed. Its copyright and license text are retained in [the upstream notice](licenses/data-with-baraa-MIT.txt). Keep that notice with redistributed source materials.

## Exact file mapping

| Upstream path under `datasets/` | Local/server path under `datasets/` | Bronze target |
| --- | --- | --- |
| `source_crm/cust_info.csv` | `source_crm/cust_info.csv` | `bronze.crm_cust_info` |
| `source_crm/prd_info.csv` | `source_crm/prd_info.csv` | `bronze.crm_prd_info` |
| `source_crm/sales_details.csv` | `source_crm/sales_details.csv` | `bronze.crm_sales_details` |
| `source_erp/CUST_AZ12.csv` | `source_erp/cust_az12.csv` | `bronze.erp_cust_az12` |
| `source_erp/LOC_A101.csv` | `source_erp/loc_a101.csv` | `bronze.erp_loc_a101` |
| `source_erp/PX_CAT_G1V2.csv` | `source_erp/px_cat_g1v2.csv` | `bronze.erp_px_cat_g1v2` |

## Download on macOS or Linux

Run from the repository root. These commands require curl and internet access, and replace existing files at the listed destinations.

```bash
mkdir -p datasets/source_crm datasets/source_erp
source_base='https://raw.githubusercontent.com/DataWithBaraa/sql-data-warehouse-project/92406686380cde6eca208c8b43e6fa40ecd26344/datasets'

curl --fail --location "$source_base/source_crm/cust_info.csv" --output datasets/source_crm/cust_info.csv
curl --fail --location "$source_base/source_crm/prd_info.csv" --output datasets/source_crm/prd_info.csv
curl --fail --location "$source_base/source_crm/sales_details.csv" --output datasets/source_crm/sales_details.csv
curl --fail --location "$source_base/source_erp/CUST_AZ12.csv" --output datasets/source_erp/cust_az12.csv
curl --fail --location "$source_base/source_erp/LOC_A101.csv" --output datasets/source_erp/loc_a101.csv
curl --fail --location "$source_base/source_erp/PX_CAT_G1V2.csv" --output datasets/source_erp/px_cat_g1v2.csv
```

On other systems, download the six files from the [pinned source directory](https://github.com/DataWithBaraa/sql-data-warehouse-project/tree/92406686380cde6eca208c8b43e6fa40ecd26344/datasets) and save them according to the mapping above. Preserve CSV column order and rename the ERP filenames to lowercase.

Then follow [Setup](setup.md) to copy or mount the files into the SQL Server machine/container. A successful local download does not make the files accessible to a remote server automatically.

## Input contract

- One header row; the loader begins at `FIRSTROW = 2`.
- Comma-separated fields in the exact order specified by [Bronze DDL](../scripts/bronze/ddl_bronze_layer.sql).
- CRM sales dates arrive as integer `YYYYMMDD` values. Invalid dates are handled in Silver after Bronze import.
- Customer, product, and ERP birth dates are loaded into typed date/datetime columns. Values that cannot enter those types can fail at ingestion.
- No general-purpose quoted-CSV parser or schema-drift handling is implemented. This loader targets the supplied source layout.
- Monetary measures are whole-number source values; no currency code is supplied by the model.

## Regression fixtures

[tests/fixtures/](../tests/fixtures/) contains small, synthetic CRM/ERP inputs created for this repository's regression tests. They exercise duplicate customers, period boundaries, fractional averages, invalid dates, and unmatched references. They are not replacements for the full learning dataset or evidence of business performance.
