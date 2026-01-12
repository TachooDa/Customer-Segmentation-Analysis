/*
 * Exploratory data analysis untuk table customer
*/
-- 1. Berapa banyak customer yg dimiliki pada table customer
SELECT
	count(DISTINCT customer_id) AS total_customer
FROM v_customer_cleaned;
-- 25000 total customer pada table 
-- 2. Distribusi kustomer dari grouping age di table customer
SELECT 
	age_group,
	count(DISTINCT customer_id) AS num_customer
FROM v_customer_cleaned 
GROUP BY age_group
ORDER BY num_customer DESC;
-- 3. Distribusi customer dari gender atau jenis kelamin yg ada di table v_customer_cleaned
SELECT 
	gender_cleaned,
	count(*) AS num_gender
FROM v_customer_cleaned
GROUP BY gender_cleaned
ORDER BY num_gender DESC;
-- 4. Berapa distribusi customer dari masing-masing kota yg sepertinya berada di portugal ini
SELECT 
	city,
	count(*) AS num_city
FROM v_customer_cleaned
GROUP BY city
ORDER BY num_city DESC;
-- 5. Berapa email yang provided dan not provided di table customer
WITH pct_email AS (
SELECT
count(CASE WHEN email_cleaned != 'Not Provided' THEN 1  end) AS provided_email,
count(CASE WHEN email_cleaned = 'Not Provided' THEN 1 end) AS non_provided_email,
count(*) AS num_customer
FROM v_customer_cleaned
)
SELECT 
	provided_email,
	non_provided_email,
	num_customer,
	round((100.0 * provided_email) / num_customer,2) AS provided_pct,
	round((100.0 * non_provided_email) / num_customer,2) AS non_provided_pct
FROM pct_email;
-- 6. profit,revenue dan cogs yg dihasilkan sepanjang tahun mulai dari tahun 2020-2024
SELECT 
	-- find the total_revenue / net_revenue
	round(sum(s.quantity * p.list_price),0) AS total_revenue,
	-- find the total cost of good sold,
	round(sum(s.quantity * p.cost_price),0) AS total_cogs,
	round(sum(s.quantity * (p.list_price - p.cost_price)),0)  AS total_profit
FROM v_sales_cleaned  AS s
LEFT JOIN v_product_cleaned AS p ON s.product_id = p.product_id;
-- 7. dari penjualan pasti ada barang yg di returned(dikembalikan), berapa distribusinya 
SELECT 
	p.category_cleaned,
	sum( case
			 WHEN s.returned = TRUE THEN 1 ELSE 0 end
	) AS product_return,
	sum( case
			 WHEN s.returned = False THEN 1 ELSE 0 end
	) AS product_not_return,
	-- berapa persentase product di return
	round(100.0* sum(CASE WHEN s.returned=TRUE THEN 1 ELSE 0 end) / count(*),2) AS returned_pct
FROM v_sales_cleaned  AS s
LEFT JOIN v_product_cleaned AS p ON s.product_id = p.product_id
WHERE date >= '2023-01-01 '
GROUP BY 1
ORDER BY product_not_return DESC;

/*
 -------------------------------------------------------------------------------------
 * KPI Resume
 * 1. Total Customer = 25.000
 * 		- Email Provided = 24.504 (98%)
 * 		- Not Provide = 496 (1.98%)
 * 2. Distribusi Customer berdasarkan grouping age
 * 		a. 40-49 = 4,673
 * 		b. 20-29 = 4,659
 * 		c. 30-39 = 4,621
 * 		d. 50-59 = 4,613
 * 		e. 60+ 	 = 4,599
 * 		f. Under 20 = 1,835
 * 3. Distribusi jenis kelamin dari table customer
 * 		a. Male = 8,337
 * 		b. Other = 8,255
 * 		c. Female = 8,110
 * 		d. Unknown = 298
 * 4. Distribusi customer dari kota order asal nya
 * 		a. Faro = 5,118
 * 		b. Lisbon = 5,062
 * 		c. Braga  = 5,000
 * 		d. Coimber = 4,978
 * 		e. Porto = 4,842
 * 5. Distribusi pendapatan dari tahun 2021-2024
 * 		a. Total Revenue = 13M
 * 		b. Total COGS 	 = 5M
 * 		c. Total Profit  = 7.9M
 -------------------------------------------------------------------------------------
 */

-- 2. Berapa revenue,cogs,dan profit yang dihasilkan oleh MRF dari tahun 2023-2024
SELECT
	-- find the total_revenue / net_revenue
	round(SUM(s.quantity * (p.list_price * (1 - s.discount) - p.cost_price)),0) AS total_revenue,
	-- find the total cost of good sold,
	round(sum(s.quantity * p.cost_price), 0) AS total_cogs,
	round(SUM(s.quantity * p.list_price * (1 - s.discount) - p.cost_price), 0) AS total_profit
FROM
	v_sales_cleaned AS s
LEFT JOIN v_product_cleaned AS p ON
	s.product_id = p.product_id
WHERE
	s.date BETWEEN '2023-01-01' AND '2024-12-31';

-- 3. Berapa banyak penjualan produk di tahun 2023-2024 ?
-- include transaksi dan qty barang yg terjual dan profitnya serta revenue yang dihasilkan
WITH prod_rank AS (
SELECT
	p.category_cleaned,
	count(DISTINCT s.transaction_id) AS num_transaction,
	sum(s.quantity) AS total_sale,
	round(SUM(s.quantity * (p.list_price * (1 - s.discount) - p.cost_price)),0) AS total_profit,
	round(SUM(s.quantity * p.list_price * (1 - s.discount)),0) AS total_revenue
FROM v_sales_cleaned AS s
JOIN v_product_cleaned AS p ON s.product_id = p.product_id 
WHERE s.date BETWEEN '2023-01-01' AND '2024-12-31'
GROUP BY p.category_cleaned
)
SELECT
	category_cleaned,
	num_transaction,
	total_sale,
	total_profit,
	total_revenue,
	dense_rank() over(ORDER BY num_transaction desc) AS rank
FROM prod_rank;

-- 4. Store atau toko apa dan dari region mana yang mememiliki aktifitas transaksi penjualan terbanyak
-- include profit dan revenue nya
SELECT 
	 sd.store_id,
	 sd.region,
	 sd.store_name,
	 count(DISTINCT s.transaction_id) AS num_transaction,
	 sum(s.quantity) AS total_sales,
	 round(SUM(s.quantity * (p.list_price * (1 - s.discount) - p.cost_price)), 0) AS total_profit,
	 round(SUM(s.quantity * p.list_price * (1 - s.discount)),0)AS total_revenue
FROM v_sales_cleaned AS s
LEFT JOIN store_data AS sd ON s.store_id = sd.store_id
LEFT JOIN v_product_cleaned AS p ON s.product_id  = p.product_id 
WHERE s.date BETWEEN '2023-01-01' AND '2024-12-31'
GROUP BY sd.store_id,sd.region,sd.store_name 
ORDER BY num_transaction DESC, total_revenue DESC;

-- 5. Pada sales data terdapat kemungkinan produk di returned pada tahun 2023-2024
-- cari berapa banyak produk yang direturn dan dan tidak di returned dan berapa conversion rate nya
WITH return_rate AS (
SELECT 
 	p.category_cleaned AS product,
 	sum(CASE WHEN s.returned = TRUE THEN 1 ELSE 0 end) AS barang_return,
 	sum(CASE WHEN s.returned = FALSE THEN 1 ELSE 0 end) AS no_return,
 	count(DISTINCT s.transaction_id) AS num_transaksi
FROM v_sales_cleaned AS s
INNER JOIN v_product_cleaned AS p ON s.product_id = p.product_id
WHERE s.date BETWEEN '2023-01-01' AND '2024-12-31'
GROUP BY 1
)
SELECT
	product,
	barang_return,
	no_return,
	num_transaksi,
	-- berapa conversion rate dari barang yang direturn
	round(barang_return * 100.0/(barang_return + no_return),2) AS return_rate_pct
FROM return_rate
ORDER BY return_rate_pct DESC;

--6. Jika banyak barang di returned kita juga harus melihat supplier serta store mana yg paling banyak direturn di 2023-2024
SELECT
	sd.store_id,
	sd.store_name,
	sd.region,
	sum(CASE WHEN s.returned = TRUE THEN 1 ELSE 0 END) AS product_returned,
	sum(CASE WHEN s.returned = FALSE THEN 1 ELSE 0 end) AS no_returned,
	count(DISTINCT s.transaction_id) AS num_transaksi
FROM v_sales_cleaned AS s
LEFT JOIN store_data AS sd ON s.store_id = sd.store_id
WHERE s.date BETWEEN '2023-01-01' AND '2024-12-31'
GROUP BY 1,2,3
ORDER BY product_returned DESC
