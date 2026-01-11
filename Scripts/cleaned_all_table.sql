/*
 *------------------------------ WARNING --------------------------------------*
 -- If you want to share the dataset, just share the cleaned dataset, or maybe this project
-- will include the messy dataset for your data cleaning training to
-- load table view to export to CSV
-- 2 additional table views, namely Cohort and RFM (customer segmentation)
-- you can adjust these 2 tables if you want to follow along or maybe you want to do other analyses
 */
/*
 *------what will be shared in this project is only the initial data table and the cleaned data-------*
 */
-- 1. Customer data table after cleaning process
SELECT * FROM v_customer_cleaned;
-- 2. Product data table after cleaning process
SELECT * FROM v_product_cleaned;
-- 3. Sales data table after cleaning process
SELECT * FROM v_sales_cleaned;

/*
	1. Cleaned Customer_data table
*/
SELECT * FROM customer_data;
-- Cek duplicate pada table customer_data
WITH duplicate_fixed AS (
SELECT *,
row_number() over(PARTITION BY age,gender,city ORDER BY customer_id) AS rn
FROM customer_data
)
SELECT 
count(rn) AS num_rn
FROM duplicate_fixed
WHERE rn = 1;
-- Fixed and added  non provided pada columns email yang null atau kosong
SELECT *,
CASE
	WHEN email = '' THEN 'Not Provided'
	ELSE email
END AS email_cleaned
FROM customer_data;
-- standardize data pada gender dikarenakan ada unconditional character seperti ???
-- terdapat 298 rows berisi ???, kita akan isi dengan value Uknown
SELECT *,
CASE
	WHEN gender = '???' THEN 'Unknown'
	ELSE gender
END AS gender_cleaned
FROM customer_data;
-- cek null value di kolom age
SELECT * FROM customer_data WHERE gender IS NULL;
-- buat age grouping untuk customer
SELECT *,
CASE
	WHEn age < 20 THEN 'Under 20'
	WHEN age BETWEEN 20 AND 29 THEN '20-29'
	WHEN age BETWEEN 30 AND 39 THEN '30-39'
	WHEN age BETWEEN 40 AND 49 THEN '40-49'
	WHEN age BETWEEN 50 AND 59 THEN '50-59'
	WHEN age >= 60 THEN '60+'
END AS age_group
FROM customer_data;
-- build new view or permanent table for cleaned columns
DROP VIEW IF EXISTS v_customer_cleaned;
CREATE VIEW v_customer_cleaned as
SELECT 
	COALESCE(customer_id, 'Guest') AS customer_id,
	age,
	CASE
	WHEN gender = '???' THEN 'Unknown'
	ELSE gender
END AS gender_cleaned,
city,
CASE
	WHEN email = '' THEN 'Not Provided'
	ELSE email
END AS email_cleaned,
CASE
	WHEn age < 20 THEN 'Under 20'
	WHEN age BETWEEN 20 AND 29 THEN '20-29'
	WHEN age BETWEEN 30 AND 39 THEN '30-39'
	WHEN age BETWEEN 40 AND 49 THEN '40-49'
	WHEN age BETWEEN 50 AND 59 THEN '50-59'
	WHEN age >= 60 THEN '60+'
END AS age_group
FROM customer_data;
-- test view table
SELECT * FROM v_customer_cleaned;
/*-------------------------------------------------------------------------------------------------------------*/
/*
  2. Cleaned product_data table
 */
SELECT * FROM product_data;
-- Cek duplicate data pada table product_data
SELECT *,
row_number() over(PARTITION BY category,season,supplier ORDER BY product_id) AS rn
FROM product_data;
-- tidak ada duplicate value pada tabel product_data
-- Standardize category columns pada product_data table
SELECT *,
	CASE
		WHEN category = '???' THEN 'Unknown'
		ELSE category
	END AS category_cleaned
FROM product_data;
-- standardize dan fill the blank value di field color dengan Other
SELECT *,
	CASE
		WHEN color = '' THEN 'Other'
		ELSE color
	END AS color_cleaned
FROM product_data;
-- Standardize format kata pada field supplier
SELECT
	*,
	CASE
		WHEN supplier = 'suppliera' THEN 'Supplier A'
		WHEN supplier = 'supplierb' THEN 'Supplier B'
		WHEN supplier = 'supplierc' THEN 'Supplier C'
		WHEN supplier = 'supplierd' THEN 'Supplier D'
	END AS supplier_cleaned
FROM product_data;
-- cek null value pada field cost_price dan list_price
SELECT
	cost_price,
	list_price
FROM product_data
WHERE cost_price IS NULL 
AND list_price IS NULL;
-- Tidak di temukan Value null pada kedua kolom cost_price dan list_price
-- buat view table untuk table product_data
--DROP VIEW IF EXISTS v_product_cleaned;
CREATE VIEW v_product_cleaned as
SELECT 
	product_id,
		CASE
		WHEN category = '???' THEN 'Unknown'
		ELSE category
	END AS category_cleaned,
	CASE
		WHEN color = '' THEN 'Other'
		ELSE color
	END AS color_cleaned,
	SIZE,
	season,
	CASE
		WHEN supplier = 'suppliera' THEN 'Supplier A'
		WHEN supplier = 'supplierb' THEN 'Supplier B'
		WHEN supplier = 'supplierc' THEN 'Supplier C'
		WHEN supplier = 'supplierd' THEN 'Supplier D'
	END AS supplier_cleaned,
	cost_price,
	list_price
FROM product_data;
/*-------------------------------------------------------------------------------------------------------------*/

/*
 * 3. Cleaning data untuk table sales_data
 */
SELECT * FROM sales_data;
-- cek null untuk masing-masing id
SELECT *,
	coalesce(customer_id,'Guest') AS customer_id
FROM sales_data;
-- cek null di quantity dan discount
SELECT 
*
FROM sales_data 
WHERE quantity IS NULL AND discount IS NULL;
-- tidak ditemukan null value pada kolom quantity dan kolom discount
-- berapa banyak barang yg di returnd dan tidak di returned (berdasarkan product_id)
SELECT
	sum(CASE WHEN returned = TRUE THEN 1 ELSE 0 end) AS product_returned,
	sum(CASE WHEN returned = FALSE THEN 1 ELSE 0 end) AS product_not_returned
FROM sales_data;
-- product yg di return berjumlah 4.900+ dan product yg tidak di returnd sejumlah 44.679 produk
-- buat table view untuk table sales_data
DROP VIEW IF EXISTS v_sales_cleaned;
CREATE VIEW v_sales_cleaned AS 
SELECT
	transaction_id,
	date,
	product_id,
	store_id,
	coalesce(customer_id,'Guest') AS customer_id,
	quantity,
	discount ,
	returned
FROM sales_data;
SELECT * FROM v_sales_cleaned;
