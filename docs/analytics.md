# Analytics and metric definitions

Deploy the three core Gold views first, followed by [report_customers.sql](../scripts/analytics/report_customers.sql) and [report_products.sql](../scripts/analytics/report_products.sql). Customer segmentation reads the customer report view.

## Analysis index

| Script in `scripts/analytics/` | Question / output | Population and grain |
| --- | --- | --- |
| [database_exploration.sql](../scripts/analytics/database_exploration.sql) | What objects and columns exist? | Database metadata |
| [dimension_exploration.sql](../scripts/analytics/dimension_exploration.sql) | Which categories and customer attributes exist? | Distinct dimension attributes |
| [date_range_exploration.sql](../scripts/analytics/date_range_exploration.sql) | What dates are covered or missing? | Date coverage and quality summaries |
| [measures_exploration.sql](../scripts/analytics/measures_exploration.sql) | What are the overall business measures? | All fact rows; dimension counts are computed separately |
| [magnitude_analysis.sql](../scripts/analytics/magnitude_analysis.sql) | How are customers, products, and sales distributed? | Country, gender, category, and customer groups |
| [ranking_analysis.sql](../scripts/analytics/ranking_analysis.sql) | Which products/customers lead or trail? | Entity keys; TOP uses key tie-breakers, RANK can return more than N rows |
| [change_over_time_analysis.sql](../scripts/analytics/change_over_time_analysis.sql) | How do monthly sales change? | Dated sales per observed month |
| [cumulative_analysis.sql](../scripts/analytics/cumulative_analysis.sql) | How do sales and average prices accumulate? | Dated sales per observed year |
| [performance_analysis.sql](../scripts/analytics/performance_analysis.sql) | How does product revenue compare with history and prior calendar periods? | Matching, non-NULL product names; year/month/name grain |
| [data_segmentation.sql](../scripts/analytics/data_segmentation.sql) | How are product costs and customer values segmented? | All current products; customers from `gold.report_customer` |
| [part_to_whole_analysis.sql](../scripts/analytics/part_to_whole_analysis.sql) | What share of sales belongs to each segment? | All sales; LEFT JOIN by category or country |

## Shared report metrics

| Metric | Definition |
| --- | --- |
| Revenue | `SUM(sales_amount)` over the stated population |
| Orders | `COUNT(DISTINCT order_number)`; NULL order numbers are not counted |
| Lifespan | `DATEDIFF(MONTH, first_order_date, last_order_date) + 1` |
| Recency | `DATEDIFF(MONTH, last_order_date, GETDATE())`; month boundaries, not elapsed 30-day periods |
| Customer average order value | Customer revenue / distinct customer orders |
| Customer average monthly spend | Customer revenue / inclusive lifespan |
| Product average selling price | Product revenue / units sold |
| Product average order revenue | Product revenue / distinct orders containing that product |
| Product average monthly revenue | Product revenue / inclusive lifespan |

Reports exclude NULL order dates. They retain unmatched dimension sales in a NULL-key group. Distinct customer/product counts exclude NULL keys; an unknown group is not evidence of one identifiable customer or product.

Lifespan includes intervening months without sales. A January-to-December customer has a lifespan of 12 even if orders occurred only in January and December. A single-month customer has a lifespan of 1.

Average calculations cast before division; a zero denominator returns NULL. Report sums use BIGINT before aggregation. The underlying fact monetary columns remain INT.

## Customer segments

Rules are evaluated in the following order in `gold.report_customer`:

| Segment | Rule |
| --- | --- |
| VIP | Lifespan >= 12 months and total sales > 5,000 |
| Regular | Lifespan >= 12 months and total sales <= 5,000 |
| Great | Lifespan < 12 months and total sales > 10,000 |
| New | All remaining groups |

These are project thresholds, not validated business policy. NULL sales fall through to `New` under the current CASE expression.

The segmentation query reuses the report view rather than maintaining another lifespan/segment calculation. Its `total_customers` counts known keys; `unknown_customer_groups` separately exposes the NULL-key group if present.

## Product segments

| Segment | Total sales |
| --- | --- |
| High-Performer | > 50,000 |
| Mid-Range | >= 10,000 and <= 50,000 |
| Low-Performer | < 10,000, or NULL under the current CASE expression |

The product cost-segmentation query is a different analysis and includes unsold current products. Its boundaries are: below 100; 100-500 inclusive; greater than 500 through 1,000; then through 1,500; then through 2,000; above 2,000. A NULL cost is `Unknown`, but the standard Silver pipeline already replaces source NULL costs with zero.

## Comparison and averaging distinctions

- **Monthly change:** LAG compares the preceding available monthly row. If February is absent, March can be compared with January. Missing months are not generated or replaced with zero.
- **Product YoY/MoM:** comparisons are accepted only when the previous observed period is the previous calendar year/month. Otherwise the comparison is NULL and labeled as missing. Different product keys with the same product name are combined intentionally.
- **Historical average:** the product performance query uses all available periods for that product name and period type, including the current period; it is not a trailing-only benchmark.
- **Exploration average price:** an unweighted average of recorded line prices, calculated as decimal. It differs from the quantity-weighted product report price.
- **Cumulative average price:** each year's average price has equal weight; it is not a transaction- or quantity-weighted overall average.
- **Part-to-whole:** NULL dimension groups remain in the denominator. Rounded percentages need not sum to exactly 100.00.

## Reading results responsibly

Align date filters, join population, entity grain, and treatment of missing periods before comparing outputs. Product-level distinct order counts cannot be added to obtain company-wide distinct orders because one order can contain several products.

No business findings or performance timings are claimed here without an actual execution against the selected dataset. Synthetic regression results validate behavior, not business outcomes.
