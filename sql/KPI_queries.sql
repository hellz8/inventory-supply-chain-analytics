/* Data exploration */
select * from fact_sales t limit 10;

select * from dim_customer rdc limit 10;
select distinct country
from dim_customer dc;


/* Sales performance */
select customer_name, sum(sales)
from fact_sales
group by customer_name 
order by sum(sales) desc;

/* Rank customer segments (Consumer, Corporate, Home Office) by sales performance */
select distinct segment
from dim_customer dc;

select c.segment, sum(s.sales) as total_sales
from fact_sales as s
join dim_customer as c on s.customer_id = c.customer_id
group by c.segment
order by total_sales desc;

/* Sales by region */
select region, sum(sales) as total_sales
from fact_sales
group by region
order by total_sales desc;

/* Rank product category (Technology, Furniture, Office Supplies) by sales performance */
select category, sum(sales)
from fact_sales t 
group by category
order by sum(sales) desc;

/* Number of products per category */
select category, count (product_id) as total_products
from dim_product dp
group by category
order by total_products desc;

/* Sales by year and category */
select
   d.year_num,
   p.category,
   SUM(s.sales) as total_sales
from fact_sales as s
join dim_date as d on s.order_date = d.full_date
join dim_product p on s.product_id = p.product_id
group by d.year_num , p.category
order by d.year_num, total_sales desc;

select s.order_id,
       p.product_name,
       p.category,
       s.quantity,
       s.sales
from fact_sales s
inner join dim_product p
    on s.product_id  = p.product_id
order by s.sales desc;

select *
from fact_sales
where order_id = 'CA-2018-140151';

/* Inventory analysis */
select * from fact_inventory_snapshot limit 10;

select *
from fact_inventory_snapshot
where cumulative_received_qty <> 0
   or cumulative_sold_qty <> 0
   or quantity_on_hand <> 0
order by snapshot_date, product_id
limit 50;


select * from dim_date dd limit 10;
select * from dim_product dp limit 10;
select * from fact_sales t limit 10;
select * from fact_purchase fp limit 10;
select * from fact_receipt fr limit 10;
select * from fact_inventory_snapshot limit 10;
select * from dim_supplier ds limit 10;
select * from dim_customer dc limit 10;

/* Quantity on hand */
select
   p.product_id,
   sum(r.received_quantity) - sum(s.actual_qty_sold) AS inventory_on_hand
from dim_product as p
left join fact_receipt as r ON p.product_id = r.product_id
left join fact_sales as s ON p.product_id = s.product_id
group by p.product_id
order by inventory_on_hand desc;

/* Total QOH by category and by year*/
WITH latest_snapshot_per_year AS (
    SELECT
        EXTRACT(YEAR FROM f.snapshot_date) AS year,
        MAX(f.snapshot_date) AS latest_date
    FROM fact_inventory_snapshot f
    GROUP BY EXTRACT(YEAR FROM f.snapshot_date)
)
SELECT
    l.year,
    p.category,
    SUM(f.quantity_on_hand) AS total_inventory
FROM latest_snapshot_per_year l
JOIN fact_inventory_snapshot f
    ON f.snapshot_date = l.latest_date
JOIN dim_product p
    ON f.product_id = p.product_id
GROUP BY
    l.year,
    p.category
ORDER BY
    l.year,
    p.category;

/* Stockout detection */
select *
from fact_inventory_snapshot fis 
where quantity_on_hand = 0;

/* Avg stockout day is 3.13*/
WITH stockout_per_product AS (
    SELECT
        p.product_id,
        COUNT(DISTINCT CASE 
            WHEN f.quantity_on_hand <= 0
             AND (
                 f.cumulative_received_qty > 0 
                 OR f.cumulative_sold_qty > 0
             )
            THEN f.snapshot_date
        END) AS stockout_days
    FROM dim_product p
    LEFT JOIN fact_inventory_snapshot f
        ON p.product_id = f.product_id
    GROUP BY p.product_id
)
SELECT
    ROUND(AVG(stockout_days), 2) AS avg_stockout_days
FROM stockout_per_product;

/* Average stockout in days by year*/
WITH stockout_per_product_year AS (
    SELECT
        p.product_id,
        EXTRACT(YEAR FROM f.snapshot_date)::int AS stockout_year,
        COUNT(DISTINCT CASE 
            WHEN f.quantity_on_hand <= 0
             AND (
                 f.cumulative_received_qty > 0 
                 OR f.cumulative_sold_qty > 0
             )
            THEN f.snapshot_date
        END) AS stockout_days
    FROM dim_product p
    LEFT JOIN fact_inventory_snapshot f
        ON p.product_id = f.product_id
    WHERE f.snapshot_date IS NOT NULL
    GROUP BY
        p.product_id,
        EXTRACT(YEAR FROM f.snapshot_date)::int
)
SELECT
    stockout_year,
    ROUND(AVG(stockout_days), 2) AS avg_stockout_days
FROM stockout_per_product_year
GROUP BY stockout_year
ORDER BY stockout_year;

/* Average stockout by category and by year*/
WITH stockout_per_product_year AS (
    SELECT
        p.category,
        p.product_id,
        EXTRACT(YEAR FROM f.snapshot_date)::int AS year,
        COUNT(DISTINCT CASE 
            WHEN f.quantity_on_hand <= 0
             AND (
                 f.cumulative_received_qty > 0 
                 OR f.cumulative_sold_qty > 0
             )
            THEN f.snapshot_date
        END) AS stockout_days
    FROM dim_product p
    LEFT JOIN fact_inventory_snapshot f
        ON p.product_id = f.product_id
    WHERE f.snapshot_date IS NOT NULL
    GROUP BY
        p.category,
        p.product_id,
        EXTRACT(YEAR FROM f.snapshot_date)::int
)
SELECT
    category,
    year,
    ROUND(AVG(stockout_days), 2) AS avg_stockout_days
FROM stockout_per_product_year
GROUP BY category, year
ORDER BY category, year;

/* Count number of products with stockout above 15d by category by year */
WITH stockout_per_product_year AS (
    SELECT
        p.category,
        p.product_id,
        EXTRACT(YEAR FROM f.snapshot_date)::int AS year,
        COUNT(DISTINCT CASE 
            WHEN f.quantity_on_hand <= 0
             AND (
                 f.cumulative_received_qty > 0 
                 OR f.cumulative_sold_qty > 0
             )
            THEN f.snapshot_date
        END) AS stockout_days
    FROM dim_product p
    LEFT JOIN fact_inventory_snapshot f
        ON p.product_id = f.product_id
    WHERE f.snapshot_date IS NOT NULL
    GROUP BY
        p.category,
        p.product_id,
        EXTRACT(YEAR FROM f.snapshot_date)::int
)
SELECT
    category,
    year,
    COUNT(*) AS products_with_stockout_above_15_days
FROM stockout_per_product_year
WHERE stockout_days > 15
GROUP BY category, year
ORDER BY category, year;


/*Overstock analysis*/
WITH sales_2015 AS (
    SELECT
        TRIM(product_id) AS product_id,
        SUM(actual_qty_sold) AS total_qty_sold_2015
    FROM fact_sales
    WHERE actual_ship_date::date BETWEEN '2015-01-01' AND '2015-12-31'
    GROUP BY TRIM(product_id)
),
daily_sales AS (
    SELECT
        product_id,
        total_qty_sold_2015 / 365.0 AS avg_daily_sales
    FROM sales_2015
),
inventory_snapshot AS (
    SELECT
        TRIM(product_id) AS product_id,
        SUM(quantity_on_hand) AS quantity_on_hand
    FROM fact_inventory_snapshot
    WHERE snapshot_date::date = '2015-12-31'
    GROUP BY TRIM(product_id)
)
SELECT
    p.product_id,
    p.product_name,
    COALESCE(i.quantity_on_hand, 0) AS quantity_on_hand,
    COALESCE(ROUND(d.avg_daily_sales, 2), 0) AS avg_daily_sales,
    CASE
        WHEN d.avg_daily_sales IS NULL OR d.avg_daily_sales = 0 THEN NULL
        ELSE ROUND(i.quantity_on_hand / d.avg_daily_sales, 2)
    END AS days_of_inventory
FROM inventory_snapshot i
LEFT JOIN daily_sales d
    ON i.product_id = d.product_id
LEFT JOIN dim_product p
    ON i.product_id = TRIM(p.product_id)
ORDER BY days_of_inventory DESC NULLS LAST;





/* Inventory turnover */
select product_id, round(SUM(fis.cumulative_sold_qty) / AVG(fis.quantity_on_hand),2) AS turnover_ratio
from fact_inventory_snapshot fis
group by product_id
order by turnover_ratio desc;


/* Connect dim_date table to all fact tables: fact_sales table, fact_purchase, fact_receipt, fact_inventory_snapshot*/
select * from dim_date dd
limit 10;

/* MIN 2014-01-01 MAX 2018-12-31 */
select MIN(full_date), MAX(full_date)
from dim_date dd ;

/* MIN 2015-01-03 MAX 2018-12-30 */
select MIN(order_date), MAX(order_date)
from fact_sales;

/*MIN 2015-01-07 MAX 2019-01-07 */
SELECT 
    MIN(actual_ship_date) AS min_ship_date,
    MAX(actual_ship_date) AS max_ship_date
FROM fact_sales;

/* MIN 2014-12-30 MAX 2019-01-17 */
select MIN(receipt_date), MAX(receipt_date)
from fact_receipt;

/*Extended the date range to 2019-01-17*/
INSERT INTO dim_date (
    date_key,
    full_date,
    year_num,
    quarter_num,
    month_num,
    month_name,
    day_num,
    day_name,
    week_of_year,
    is_weekend
)
SELECT
    TO_CHAR(d::date, 'YYYYMMDD')::INT AS date_key,
    d::date AS full_date,
    EXTRACT(YEAR FROM d)::INT AS year_num,
    EXTRACT(QUARTER FROM d)::INT AS quarter_num,
    EXTRACT(MONTH FROM d)::INT AS month_num,
    TRIM(TO_CHAR(d::date, 'Month')) AS month_name,
    EXTRACT(DAY FROM d)::INT AS day_num,
    TRIM(TO_CHAR(d::date, 'Day')) AS day_name,
    EXTRACT(WEEK FROM d)::INT AS week_of_year,
    CASE 
        WHEN EXTRACT(ISODOW FROM d)::INT IN (6, 7) THEN TRUE
        ELSE FALSE
    END AS is_weekend
FROM generate_series('2019-01-01'::date, '2019-01-17'::date, interval '1 day') AS d
WHERE NOT EXISTS (
    SELECT 1
    FROM dim_date dd
    WHERE dd.full_date = d::date
);


SELECT 
    MIN(full_date) AS min_date,
    MAX(full_date) AS max_date
FROM dim_date;

/* Add date_key columns */
ALTER TABLE fact_sales
ADD COLUMN IF NOT EXISTS order_date_key INT;

ALTER TABLE fact_sales
ADD COLUMN IF NOT EXISTS ship_date_key INT;

ALTER TABLE fact_receipt
ADD COLUMN IF NOT EXISTS receipt_date_key INT;

/* Populate the keys*/
UPDATE fact_sales fs
SET order_date_key = dd.date_key
FROM dim_date dd
WHERE fs.order_date = dd.full_date;

UPDATE fact_sales fs
SET ship_date_key = dd.date_key
FROM dim_date dd
WHERE fs.actual_ship_date = dd.full_date;

UPDATE fact_receipt fr
SET receipt_date_key = dd.date_key
FROM dim_date dd
WHERE fr.receipt_date = dd.full_date;

/* Validate populated keys */
SELECT COUNT(*) AS missing_order_date_key
FROM fact_sales
WHERE order_date_key IS NULL;

SELECT COUNT(*) AS missing_ship_date_key
FROM fact_sales
WHERE ship_date_key IS NULL
  AND actual_ship_date IS NOT NULL;

SELECT COUNT(*) AS missing_receipt_date_key
FROM fact_receipt
WHERE receipt_date_key IS NULL;

/* Add new FK*/
ALTER TABLE fact_sales
ADD CONSTRAINT fk_sales_order_date_key
FOREIGN KEY (order_date_key)
REFERENCES dim_date(date_key);

ALTER TABLE fact_sales
ADD CONSTRAINT fk_sales_ship_date_key
FOREIGN KEY (ship_date_key)
REFERENCES dim_date(date_key);

ALTER TABLE fact_receipt
ADD CONSTRAINT fk_receipt_date_key
FOREIGN KEY (receipt_date_key)
REFERENCES dim_date(date_key);

