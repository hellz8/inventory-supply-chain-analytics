/* Supplier table and customer table */
DROP TABLE IF EXISTS raw_dim_supplier;
CREATE TABLE IF NOT EXISTS raw_dim_supplier (
    supplier_id       TEXT,
    supplier_name     TEXT,
    lead_time_days    INTEGER
);

select * from raw_dim_supplier rds;
select count (*) from raw_dim_supplier rds;

CREATE TABLE IF NOT EXISTS dim_supplier (
    supplier_id       TEXT PRIMARY KEY,
    supplier_name     TEXT NOT NULL,
    lead_time_days    INTEGER
);

INSERT INTO dim_supplier (
supplier_id,
supplier_name,
lead_time_days
)
SELECT
supplier_id,
supplier_name,
lead_time_days
FROM raw_dim_supplier;

select * from dim_supplier ds;
select count (*) from dim_supplier ds;

DROP TABLE IF EXISTS raw_dim_customer;
CREATE TABLE raw_dim_customer (
    customer_id      TEXT,
    customer_name    TEXT,
    segment          TEXT,
    region           TEXT,
    city             TEXT,
    state            TEXT,
    country          TEXT
);
select * from raw_dim_customer rdc;
select count (*) from raw_dim_customer dc;


DROP TABLE IF EXISTS dim_customer;
CREATE TABLE dim_customer (
    customer_id      TEXT PRIMARY KEY,
    customer_name    TEXT NOT NULL,
    segment          TEXT,
    region           TEXT,
    city             TEXT,
    state            TEXT,
    country          TEXT
);

INSERT INTO dim_customer (
    customer_id,
    customer_name,
    segment,
    region,
    city,
    state,
    country
)
SELECT
    customer_id,
    customer_name,
    segment,
    region,
    city,
    state,
    country
FROM raw_dim_customer;

select * from dim_customer dc;
select count (*) from dim_customer dc;

/* Product table: clean currency fields, avg_unit_price and standard_unit_cost were stored with dollar signs, like $275.06, 
 so they should first be loaded as text and then cleaned into numeric fields */
DROP TABLE IF EXISTS raw_dim_product;

CREATE TABLE IF NOT EXISTS raw_dim_product (
    product_id              TEXT,
    product_name            TEXT,
    category                TEXT,
    sub_category            TEXT,
    supplier_id             TEXT,
    supplier_name           TEXT,
    default_warehouse_id    TEXT,
    lead_time_days          INTEGER,
    avg_unit_price          TEXT,
    standard_unit_cost      TEXT,
    reorder_point_qty       INTEGER,
    target_stock_qty        INTEGER
);


select * from raw_dim_product rdp;
select count (*) from raw_dim_product rdp;

DROP TABLE IF EXISTS dim_product;
CREATE TABLE IF NOT EXISTS dim_product (
    product_id              TEXT PRIMARY KEY,
    product_name            TEXT NOT NULL,
    category                TEXT,
    sub_category            TEXT,
    supplier_id             TEXT,
    supplier_name           TEXT,
    default_warehouse_id    TEXT,
    lead_time_days          INTEGER,
    avg_unit_price          NUMERIC(12,2),
    standard_unit_cost      NUMERIC(12,2),
    reorder_point_qty       INTEGER,
    target_stock_qty        INTEGER
);
INSERT INTO dim_product (
    product_id,
    product_name,
    category,
    sub_category,
    supplier_id,
    supplier_name,
    default_warehouse_id,
    lead_time_days,
    avg_unit_price,
    standard_unit_cost,
    reorder_point_qty,
    target_stock_qty
)
SELECT
    product_id,
    product_name,
    category,
    sub_category,
    supplier_id,
    supplier_name,
    default_warehouse_id,
    lead_time_days,
    REPLACE(REPLACE(avg_unit_price, '$', ''), ',', '')::NUMERIC(12,2),
    REPLACE(REPLACE(standard_unit_cost, '$', ''), ',', '')::NUMERIC(12,2),
    reorder_point_qty,
    target_stock_qty
FROM raw_dim_product;

select * from dim_product dp ;
select count (*) from dim_product dp;

/* Load fact tables: purchase, receipt, and sales*/
/* Purchase table: date columns (order_date, expected_delivery_date) and currency columns (unit_cost and total_cost) 
 were stored as text first*/

DROP TABLE IF EXISTS raw_fact_purchase;
CREATE TABLE IF NOT EXISTS raw_fact_purchase (
    purchase_order_id         TEXT,
    product_id                TEXT,
    supplier_id               TEXT,
    supplier_name             TEXT,
    order_date                TEXT,
    expected_delivery_date    TEXT,
    order_quantity            INTEGER,
    unit_cost                 TEXT,
    total_cost                TEXT,
    status                    TEXT
);

select * from  raw_fact_purchase rfp limit 10;
select count (*) from raw_fact_purchase rfp;

DROP TABLE IF EXISTS fact_purchase;
CREATE TABLE IF NOT EXISTS fact_purchase (
    purchase_order_id         TEXT PRIMARY KEY,
    product_id                TEXT NOT NULL,
    supplier_id               TEXT NOT NULL,
    supplier_name             TEXT,
    order_date                DATE,
    expected_delivery_date    DATE,
    order_quantity            INTEGER,
    unit_cost                 NUMERIC(12,2),
    total_cost                NUMERIC(14,2),
    status                    TEXT
);

INSERT INTO fact_purchase (
    purchase_order_id,
    product_id,
    supplier_id,
    supplier_name,
    order_date,
    expected_delivery_date,
    order_quantity,
    unit_cost,
    total_cost,
    status
)
SELECT
    purchase_order_id,
    product_id,
    supplier_id,
    supplier_name,
    TO_DATE(order_date, 'YYYY-MM-DD'),
    TO_DATE(expected_delivery_date, 'YYYY-MM-DD'),
    order_quantity,
    REPLACE(REPLACE(unit_cost, '$', ''), ',', '')::NUMERIC(12,2),
    REPLACE(REPLACE(total_cost, '$', ''), ',', '')::NUMERIC(14,2),
    status
FROM raw_fact_purchase;

select * from  fact_purchase fp limit 10;
select count (*) from fact_purchase fp;

/* The fact recepit table: "receipt_date" is first stored as text*/
DROP TABLE IF EXISTS raw_fact_receipt;
CREATE TABLE IF NOT EXISTS raw_fact_receipt (
    receipt_id           TEXT,
    purchase_order_id    TEXT,
    product_id           TEXT,
    warehouse_id         TEXT,
    receipt_date         TEXT,
    received_quantity    INTEGER,
    receipt_status       TEXT
);

select * from raw_fact_receipt rfr limit 10;
select count (*) from raw_fact_receipt rfr;

DROP TABLE IF EXISTS fact_receipt;
CREATE TABLE IF NOT EXISTS fact_receipt (
    receipt_id           TEXT PRIMARY KEY,
    purchase_order_id    TEXT NOT NULL,
    product_id           TEXT NOT NULL,
    warehouse_id         TEXT,
    receipt_date         DATE,
    received_quantity    INTEGER,
    receipt_status       TEXT
);

INSERT INTO fact_receipt (
    receipt_id,
    purchase_order_id,
    product_id,
    warehouse_id,
    receipt_date,
    received_quantity,
    receipt_status
)
SELECT
    receipt_id,
    purchase_order_id,
    product_id,
    warehouse_id,
    TO_DATE(receipt_date, 'YYYY-MM-DD'),
    received_quantity,
    receipt_status
FROM raw_fact_receipt;

select * from fact_receipt fr;
select count (*) from fact_receipt fr;

/* The fact sales table: date field (order_date, ship_date, and actual_ship_date) and the sales column
 were storesd as text first */

DROP TABLE IF EXISTS raw_fact_sales;
CREATE TABLE IF NOT EXISTS raw_fact_sales (
    row_id              INTEGER,
    order_id            TEXT,
    order_date          TEXT,
    ship_date           TEXT,
    ship_mode           TEXT,
    customer_id         TEXT,
    customer_name       TEXT,
    segment             TEXT,
    country             TEXT,
    city                TEXT,
    state               TEXT,
    postal_code         TEXT,
    region              TEXT,
    product_id          TEXT,
    category            TEXT,
    sub_category        TEXT,
    product_name        TEXT,
    sales               TEXT,
    quantity            INTEGER,
    actual_qty_sold     INTEGER,
    actual_ship_date    TEXT
);
select * from raw_fact_sales rfs limit 10;
select count (*) from raw_fact_sales rfs;

SELECT MIN(order_date), MAX(order_date)
FROM raw_fact_sales rfs;


DROP TABLE IF EXISTS fact_sales;
CREATE TABLE fact_sales (
    row_id              INTEGER PRIMARY KEY,
    order_id            TEXT NOT NULL,
    order_date          DATE,
    ship_date           DATE,
    ship_mode           TEXT,
    customer_id         TEXT NOT NULL,
    customer_name       TEXT,
    segment             TEXT,
    country             TEXT,
    city                TEXT,
    state               TEXT,
    postal_code         TEXT,
    region              TEXT,
    product_id          TEXT NOT NULL,
    category            TEXT,
    sub_category        TEXT,
    product_name        TEXT,
    sales               NUMERIC(12,2),
    quantity            INTEGER,
    actual_qty_sold     INTEGER,
    actual_ship_date    DATE
);

INSERT INTO fact_sales (
    row_id,
    order_id,
    order_date,
    ship_date,
    ship_mode,
    customer_id,
    customer_name,
    segment,
    country,
    city,
    state,
    postal_code,
    region,
    product_id,
    category,
    sub_category,
    product_name,
    sales,
    quantity,
    actual_qty_sold,
    actual_ship_date
)
SELECT
    row_id,
    order_id,
    TO_DATE(order_date, 'DD/MM/YYYY'),
    TO_DATE(ship_date, 'YYYY-MM-DD'),
    ship_mode,
    customer_id,
    customer_name,
    segment,
    country,
    city,
    state,
    postal_code,
    region,
    product_id,
    category,
    sub_category,
    product_name,
    REPLACE(REPLACE(sales, '$', ''), ',', '')::NUMERIC(12,2),
    quantity,
    actual_qty_sold,
    TO_DATE(actual_ship_date, 'YYYY-MM-DD')
FROM raw_fact_sales;

select * from fact_sales t limit 10;
select count (*) from fact_sales t;

/* Create the snapshot date table */
DROP TABLE IF EXISTS dim_date;
CREATE TABLE IF NOT EXISTS dim_date (
    date_key        INTEGER PRIMARY KEY,
    full_date       DATE NOT NULL UNIQUE,
    year_num        INTEGER NOT NULL,
    quarter_num     INTEGER NOT NULL,
    month_num       INTEGER NOT NULL,
    month_name      TEXT NOT NULL,
    day_num         INTEGER NOT NULL,
    day_name        TEXT NOT NULL,
    week_of_year    INTEGER NOT NULL,
    is_weekend      BOOLEAN NOT NULL
);

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
    TO_CHAR(d::date, 'YYYYMMDD')::INTEGER AS date_key,
    d::date AS full_date,
    EXTRACT(YEAR FROM d)::INTEGER AS year_num,
    EXTRACT(QUARTER FROM d)::INTEGER AS quarter_num,
    EXTRACT(MONTH FROM d)::INTEGER AS month_num,
    TO_CHAR(d::date, 'FMMonth') AS month_name,
    EXTRACT(DAY FROM d)::INTEGER AS day_num,
    TO_CHAR(d::date, 'FMDay') AS day_name,
    EXTRACT(WEEK FROM d)::INTEGER AS week_of_year,
    CASE
        WHEN EXTRACT(ISODOW FROM d) IN (6, 7) THEN TRUE
        ELSE FALSE
    END AS is_weekend
FROM generate_series(
    '2014-01-01'::date,
    '2018-12-31'::date,
    interval '1 day'
) AS d;

select * from dim_date;
SELECT MIN(full_date), MAX(full_date)
FROM dim_date;

/* Create the snapshot inventory table */

DROP TABLE IF EXISTS fact_inventory_snapshot;
CREATE TABLE fact_inventory_snapshot (
    snapshot_date           DATE NOT NULL,
    date_key                INTEGER NOT NULL,
    product_id              TEXT NOT NULL,
    cumulative_received_qty INTEGER NOT NULL,
    cumulative_sold_qty     INTEGER NOT NULL,
    quantity_on_hand        INTEGER NOT NULL,
    PRIMARY KEY (snapshot_date, product_id)
);

TRUNCATE TABLE fact_inventory_snapshot;
WITH calendar_products AS (
    SELECT
        d.full_date,
        d.date_key,
        p.product_id
    FROM dim_date d
    CROSS JOIN dim_product p
    WHERE d.full_date BETWEEN
        (
            SELECT LEAST(
                (SELECT MIN(order_date) FROM fact_sales),
                (SELECT MIN(receipt_date) FROM fact_receipt)
            )
        )
        AND
        (
            SELECT GREATEST(
                (SELECT MAX(order_date) FROM fact_sales),
                (SELECT MAX(receipt_date) FROM fact_receipt)
            )
        )
),
daily_receipts AS (
    SELECT
        receipt_date AS movement_date,
        product_id,
        SUM(received_quantity) AS received_qty
    FROM fact_receipt
    GROUP BY receipt_date, product_id
),
daily_sales AS (
    SELECT
        order_date AS movement_date,
        product_id,
        SUM(actual_qty_sold) AS sold_qty
    FROM fact_sales
    GROUP BY order_date, product_id
),
base AS (
    SELECT
        cp.full_date,
        cp.date_key,
        cp.product_id,
        COALESCE(dr.received_qty, 0) AS daily_received_qty,
        COALESCE(ds.sold_qty, 0) AS daily_sold_qty
    FROM calendar_products cp
    LEFT JOIN daily_receipts dr
        ON cp.full_date = dr.movement_date
       AND cp.product_id = dr.product_id
    LEFT JOIN daily_sales ds
        ON cp.full_date = ds.movement_date
       AND cp.product_id = ds.product_id
),
final_snapshot AS (
    SELECT
        full_date AS snapshot_date,
        date_key,
        product_id,
        SUM(daily_received_qty) OVER (
            PARTITION BY product_id
            ORDER BY full_date
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS cumulative_received_qty,
        SUM(daily_sold_qty) OVER (
            PARTITION BY product_id
            ORDER BY full_date
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS cumulative_sold_qty
    FROM base
)
INSERT INTO fact_inventory_snapshot (
    snapshot_date,
    date_key,
    product_id,
    cumulative_received_qty,
    cumulative_sold_qty,
    quantity_on_hand
)
SELECT
    snapshot_date,
    date_key,
    product_id,
    cumulative_received_qty,
    cumulative_sold_qty,
    cumulative_received_qty - cumulative_sold_qty AS quantity_on_hand
FROM final_snapshot;


select * from fact_inventory_snapshot fis limit 10;
SELECT COUNT(*) FROM fact_inventory_snapshot;

/* Validate the inventory snapshot table */
SELECT *
FROM fact_inventory_snapshot
ORDER BY snapshot_date, product_id
LIMIT 20;

SELECT MIN(snapshot_date), MAX(snapshot_date)
FROM fact_inventory_snapshot;

/* Check a single product over time */
SELECT *
FROM fact_inventory_snapshot
WHERE product_id = 'FUR-BO-10001798'
ORDER BY snapshot_date
LIMIT 50;

/* Total inventory by day */
SELECT
    snapshot_date,
    SUM(quantity_on_hand) AS total_inventory_units
FROM fact_inventory_snapshot
GROUP BY snapshot_date
ORDER BY snapshot_date;

/* Products with negative inventory */
SELECT *
FROM fact_inventory_snapshot
WHERE quantity_on_hand < 0
ORDER BY snapshot_date, product_id;

/* Latest inventory by product */
SELECT *
FROM fact_inventory_snapshot
WHERE snapshot_date = (SELECT MAX(snapshot_date) FROM fact_inventory_snapshot)
ORDER BY quantity_on_hand;


/* Fixed the inventory snapshot table */
TRUNCATE TABLE fact_inventory_snapshot;

WITH daily_receipts AS (
    SELECT
        receipt_date::date AS movement_date,
        TRIM(product_id) AS product_id,
        SUM(received_quantity) AS qty_in
    FROM fact_receipt
    GROUP BY 1, 2
),
daily_sales AS (
    SELECT
        order_date::date AS movement_date,
        TRIM(product_id) AS product_id,
        SUM(actual_qty_sold) AS qty_out
    FROM fact_sales
    GROUP BY 1, 2
),
calendar_products AS (
    SELECT
        d.full_date,
        d.date_key,
        TRIM(p.product_id) AS product_id
    FROM dim_date d
    CROSS JOIN dim_product p
    WHERE d.full_date BETWEEN
        LEAST(
            (SELECT MIN(order_date)::date FROM fact_sales),
            (SELECT MIN(receipt_date)::date FROM fact_receipt)
        )
        AND
        GREATEST(
            (SELECT MAX(order_date)::date FROM fact_sales),
            (SELECT MAX(receipt_date)::date FROM fact_receipt)
        )
),
base AS (
    SELECT
        cp.full_date,
        cp.date_key,
        cp.product_id,
        COALESCE(dr.qty_in, 0) AS daily_received_qty,
        COALESCE(ds.qty_out, 0) AS daily_sold_qty
    FROM calendar_products cp
    LEFT JOIN daily_receipts dr
        ON cp.full_date = dr.movement_date
       AND cp.product_id = dr.product_id
    LEFT JOIN daily_sales ds
        ON cp.full_date = ds.movement_date
       AND cp.product_id = ds.product_id
)
INSERT INTO fact_inventory_snapshot (
    snapshot_date,
    date_key,
    product_id,
    cumulative_received_qty,
    cumulative_sold_qty,
    quantity_on_hand
)
SELECT
    full_date AS snapshot_date,
    date_key,
    product_id,
    SUM(daily_received_qty) OVER (
        PARTITION BY product_id
        ORDER BY full_date
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS cumulative_received_qty,
    SUM(daily_sold_qty) OVER (
        PARTITION BY product_id
        ORDER BY full_date
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS cumulative_sold_qty,
    SUM(daily_received_qty - daily_sold_qty) OVER (
        PARTITION BY product_id
        ORDER BY full_date
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS quantity_on_hand
FROM base;

SELECT COUNT(*)
FROM fact_inventory_snapshot
WHERE cumulative_received_qty <> 0
   OR cumulative_sold_qty <> 0
   OR quantity_on_hand <> 0;

SELECT *
FROM fact_inventory_snapshot
WHERE cumulative_received_qty <> 0
   OR cumulative_sold_qty <> 0
   OR quantity_on_hand <> 0
ORDER BY snapshot_date, product_id
LIMIT 50;


/* Add foreign keys- check for orphan records first */
/* 1. Check fact_sales.customer_id */
SELECT DISTINCT fs.customer_id
FROM fact_sales fs
LEFT JOIN dim_customer dc
    ON fs.customer_id = dc.customer_id
WHERE dc.customer_id IS NULL;

/* 2. Check fact_sales.product_id */
SELECT DISTINCT fs.product_id
FROM fact_sales fs
LEFT JOIN dim_product dp
    ON fs.product_id = dp.product_id
WHERE dp.product_id IS NULL;

/* 3. Check fact_purchase.supplier_id */
SELECT DISTINCT fp.supplier_id
FROM fact_purchase fp
LEFT JOIN dim_supplier ds
    ON fp.supplier_id = ds.supplier_id
WHERE ds.supplier_id IS NULL;

/* 4.fact_purchase.product_id */
SELECT DISTINCT fp.product_id
FROM fact_purchase fp
LEFT JOIN dim_product dp
    ON fp.product_id = dp.product_id
WHERE dp.product_id IS NULL;

/* 5. Check fact_receipt.purchase_order_id */
SELECT DISTINCT fr.purchase_order_id
FROM fact_receipt fr
LEFT JOIN fact_purchase fp
    ON fr.purchase_order_id = fp.purchase_order_id
WHERE fp.purchase_order_id IS NULL;

/* 6. Check fact_receipt.product_id */
SELECT DISTINCT fr.product_id
FROM fact_receipt fr
LEFT JOIN dim_product dp
    ON fr.product_id = dp.product_id
WHERE dp.product_id IS NULL;

/* 7. Check fact_inventory_snapshot.date_key */
SELECT DISTINCT fis.date_key
FROM fact_inventory_snapshot fis
LEFT JOIN dim_date dd
    ON fis.date_key = dd.date_key
WHERE dd.date_key IS NULL;

/* 8. Check fact_inventory_snapshot.product_id */
SELECT DISTINCT fis.product_id
FROM fact_inventory_snapshot fis
LEFT JOIN dim_product dp
    ON fis.product_id = dp.product_id
WHERE dp.product_id IS NULL;

/* 9. Check dim_product.supplier_id */
SELECT DISTINCT dp.supplier_id
FROM dim_product dp
LEFT JOIN dim_supplier ds
    ON dp.supplier_id = ds.supplier_id
WHERE ds.supplier_id IS NULL;

/* Create foreign keys */
/* 1. dim_product → dim_supplier */
ALTER TABLE dim_product
ADD CONSTRAINT fk_dim_product_supplier
FOREIGN KEY (supplier_id)
REFERENCES dim_supplier(supplier_id);

ALTER TABLE dim_product
DROP CONSTRAINT fk_dim_product_supplier;

/* 2. Foreign keys: fact_sales */
ALTER TABLE fact_sales
ADD CONSTRAINT fk_fact_sales_customer
FOREIGN KEY (customer_id)
REFERENCES dim_customer(customer_id);

ALTER TABLE fact_sales
ADD CONSTRAINT fk_fact_sales_product
FOREIGN KEY (product_id)
REFERENCES dim_product(product_id);

/* 3. Foreign keys: fact_purchase */
ALTER TABLE fact_purchase
ADD CONSTRAINT fk_fact_purchase_supplier
FOREIGN KEY (supplier_id)
REFERENCES dim_supplier(supplier_id);

ALTER TABLE fact_purchase
ADD CONSTRAINT fk_fact_purchase_product
FOREIGN KEY (product_id)
REFERENCES dim_product(product_id);

/* 4. Foreign keys: fact_receipt */
ALTER TABLE fact_receipt
ADD CONSTRAINT fk_fact_receipt_purchase_order
FOREIGN KEY (purchase_order_id)
REFERENCES fact_purchase(purchase_order_id);

ALTER TABLE fact_receipt
ADD CONSTRAINT fk_fact_receipt_product
FOREIGN KEY (product_id)
REFERENCES dim_product(product_id);

/* 5. Foreign keys:fact_inventory_snapshot*/
ALTER TABLE fact_inventory_snapshot
ADD CONSTRAINT fk_fact_inventory_snapshot_date
FOREIGN KEY (date_key)
REFERENCES dim_date(date_key);

ALTER TABLE fact_inventory_snapshot
ADD CONSTRAINT fk_fact_inventory_snapshot_product
FOREIGN KEY (product_id)
REFERENCES dim_product(product_id);


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

/* Data validation & quality checks: duplicate checks */
/* Fact sales table: same product appear twice on an order due to discount/ship split/line */
select *
from fact_sales t 
limit 10;

select order_id, product_id, COUNT(*)
from fact_sales
group by order_id, product_id
having count(*) > 1;


select *
from fact_sales
where order_id = 'CA-2018-118017' and product_id ='TEC-AC-10002006';

/* Fact purchase table: no duplicates*/
select *
from fact_purchase fp 
limit 10;

select fp.purchase_order_id , product_id, COUNT(*)
from fact_purchase fp 
group by fp.purchase_order_id , product_id
having count (*) > 1;

/* Fact receipt table: no duplicates */
select *
from fact_receipt fr 
limit 10;

select receipt_id, product_id, COUNT(*)
from fact_receipt fr 
group by receipt_id, product_id
having count (*)>1;

/* Product table: no duplicates */
select *
from dim_product
limit 10;

select product_id, supplier_id, COUNT (*)
from dim_product dp 
group by product_id, supplier_id
having count (*)>1;

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
