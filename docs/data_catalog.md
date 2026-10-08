# Gold data catalog

Gold consists of **five views**. Types below describe the SQL definitions; these are not persisted fact/dimension tables or enforced primary/foreign-key constraints. Source columns are nullable unless a query filters or replaces NULL explicitly.

## gold.dim_customers

Purpose: enrich CRM customer records with ERP demographic and location data.

Intended grain: one row per CRM `customer_id`, assuming ERP customer/location join keys are unique.

| Column | SQL type | Definition |
| --- | --- | --- |
| customer_key | BIGINT | `ROW_NUMBER()` ordered by CRM customer ID; not a durable key |
| customer_id | INT | CRM `cst_id` |
| customer_number | NVARCHAR(50) | CRM `cst_key`; links to standardized ERP identifiers |
| first_name | NVARCHAR(50) | Trimmed CRM first name |
| last_name | NVARCHAR(50) | Trimmed CRM last name |
| gender | NVARCHAR(50) | CRM gender; ERP fallback if CRM is NULL or `n/a` |
| birthdate | DATE | ERP birth date; future values are replaced with NULL in Silver |
| marital_status | NVARCHAR(50) | `Married`, `Single`, or `n/a` |
| country | NVARCHAR(50) | Standardized ERP country; may be NULL when the ERP join is unmatched |
| create_date | DATE | Source customer creation date, not warehouse load time |

## gold.dim_products

Purpose: describe current products and their category attributes.

Intended grain: one current row per `product_number`. Only Silver rows with `prd_end_dt IS NULL` are included.

| Column | SQL type | Definition |
| --- | --- | --- |
| product_key | BIGINT | `ROW_NUMBER()` ordered by start date and product number; not durable |
| product_id | INT | Source product record ID |
| product_number | NVARCHAR(50) | Product identifier extracted from the CRM product key |
| product_name | NVARCHAR(50) | Source product name |
| category_id | NVARCHAR(50) | Category identifier extracted and normalized from the CRM key |
| category | NVARCHAR(50) | ERP product category |
| sub_category | NVARCHAR(50) | ERP product subcategory |
| maintenance | NVARCHAR(50) | `Yes`, `No`, or `unknown`; NULL when ERP category is unmatched |
| cost | INT | Whole-number source cost; missing source costs become zero in Silver |
| product_line | NVARCHAR(50) | `Mountain`, `Road`, `Other Sales`, `Touring`, or `n/a` |
| start_date | DATE | Start of the selected current product version |

## gold.fact_sales

Purpose: expose Silver sales-detail rows joined to the dimensions.

Intended grain: one source sales-detail row, provided dimension joins do not multiply rows. Multiple rows can share an order number; no unique order-line ID is supplied.

| Column | SQL type | Definition |
| --- | --- | --- |
| order_number | NVARCHAR(50) | Business order identifier; not a unique fact-row identifier |
| product_key | BIGINT | Joined current product key; NULL for unmatched products |
| customer_key | BIGINT | Joined customer key; NULL for unmatched customers |
| order_date | DATE | Cleaned order date; NULL when invalid/inconsistent |
| shipping_date | DATE | Cleaned shipping date |
| due_date | DATE | Cleaned due date |
| sales_amount | INT | Whole-number line revenue, recalculated in Silver when required |
| quantity | INT | Source line quantity |
| price | INT | Cleaned whole-number unit selling price |

No currency code is modeled. The original source customer/product identifiers are not exposed in this view, so NULL dimension keys cannot identify distinct missing source entities.

## gold.report_customer

Definition: [report_customers.sql](../scripts/analytics/report_customers.sql). The SQL object intentionally retains its existing singular name.

Population: fact rows with a non-NULL order date, LEFT JOINed to customers. Intended grain: one row per known customer key, plus one NULL-key group for unmatched sales. Customers without dated sales are absent.

| Column | SQL type | Definition |
| --- | --- | --- |
| customer_key | BIGINT | Customer key, or NULL for the unmatched group |
| customer_number | NVARCHAR(50) | Dimension customer number |
| customer_name | NVARCHAR expression | Trimmed first and last name; `Unknown` when both are missing/blank |
| age | INT | Completed years as of the SQL Server clock; NULL without birth date |
| age_group | VARCHAR expression | `Under 20`, `20-29`, `30-39`, `40-49`, `50 and above`, or `Unknown` |
| customer_segment | VARCHAR expression | `VIP`, `Regular`, `Great`, or `New`; see [thresholds](analytics.md) |
| last_order_date | DATE | Latest included order date |
| recency_months | INT | Calendar-month boundaries from last order to `GETDATE()` |
| total_orders | INT | Distinct non-NULL order numbers |
| total_sales | BIGINT | Sum of included line revenue, cast to BIGINT before summing |
| total_quantity | BIGINT | Sum of included quantities, cast to BIGINT before summing |
| total_products | INT | Distinct non-NULL product keys |
| lifespan_months | INT | Inclusive span between first and last included order month |
| average_order_value | DECIMAL(28,2) | Sales divided by distinct orders; NULL if the denominator is zero |
| average_monthly_spend | DECIMAL(28,2) | Sales divided by inclusive lifespan |

An all-NULL sales group has NULL sales-derived averages. No denominator or missing revenue is silently converted into a zero average.

## gold.report_products

Definition: [report_products.sql](../scripts/analytics/report_products.sql).

Population: fact rows with a non-NULL order date, LEFT JOINed to products. Intended grain: one row per known product key, plus one NULL-key group. Products without dated sales are absent.

| Column | SQL type | Definition |
| --- | --- | --- |
| product_key | BIGINT | Product key, or NULL for the unmatched group |
| product_name | NVARCHAR(50) | Dimension product name |
| category | NVARCHAR(50) | Dimension category |
| sub_category | NVARCHAR(50) | Dimension subcategory |
| cost | INT | Current product cost |
| recency_in_months | INT | Month boundaries since the latest included sale |
| product_segment | VARCHAR expression | `High-Performer`, `Mid-Range`, or `Low-Performer` |
| last_sale_date | DATE | Latest included order date |
| lifespan_months | INT | Inclusive first-to-last-sale month span; exposed for KPI inspection |
| total_orders | INT | Distinct non-NULL orders containing the product |
| total_customers | INT | Distinct non-NULL customer keys |
| total_sales | BIGINT | Sum of included line revenue |
| total_quantity | BIGINT | Sum of included quantities |
| avg_selling_price | DECIMAL(18,2) | Total revenue divided by total units: a quantity-weighted selling price |
| avg_order_revenue | DECIMAL(18,2) | Product revenue divided by distinct product orders |
| avg_monthly_revenue | DECIMAL(18,2) | Product revenue divided by inclusive lifespan |

Product averages return NULL when their denominator is zero. See [Analytics](analytics.md) for population differences and segmentation boundaries.

## Inspect actual deployed metadata

Use this after deploying the views to verify types, lengths, and metadata nullability on your SQL Server instance:

```sql
SELECT
    v.name AS view_name,
    c.column_id,
    c.name AS column_name,
    t.name AS data_type,
    c.max_length,
    c.precision,
    c.scale,
    c.is_nullable
FROM sys.views AS v
JOIN sys.schemas AS s ON s.schema_id = v.schema_id
JOIN sys.columns AS c ON c.object_id = v.object_id
JOIN sys.types AS t ON t.user_type_id = c.user_type_id
WHERE s.name = 'gold'
ORDER BY v.name, c.column_id;
```
