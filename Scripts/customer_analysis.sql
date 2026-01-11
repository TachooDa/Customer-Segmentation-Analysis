SELECT
	*
FROM
	v_customer_cleaned;

/* The Main analysis*/
/* Customer Segmentation and Retention Analyis*/
SELECT
	*
FROM
	v_customer_cleaned;

SELECT
	*
FROM
	v_product_cleaned;

SELECT
	*
FROM
	v_sales_cleaned;
-- Berapa customer life time valu berdasarkan profit yg dimiliki di tahun 2023-2024
WITH cohort AS (
	SELECT
		s.customer_id,
		EXTRACT(YEAR FROM min(s.date)) AS cohort_year,
		sum(s.quantity * (p.list_price-p.cost_price)) AS customer_ltv_profit
	FROM
		v_sales_cleaned AS s
	JOIN v_product_cleaned AS p ON
		s.product_id = p.product_id
	WHERE
		s.date >= '2023-01-01'
	GROUP BY
		s.customer_id
)
SELECT
	*,
	round(avg(customer_ltv_profit) OVER(PARTITION BY cohort_year), 2) AS avg_cust_ltv
FROM
	cohort;
-- Sekarang saat nya melihat bagaimana perilaku customer dengan cohort retention analysis
-- untuk melihat apakah pelanggan tetap aktif kembali membeli atau setelah membeli tidak kembali lagi untuk tahun 2023-2024
-- buat query cohort ini menjadi view untuk mencari berapa customer yg active dan berapa yang churn
DROP VIEW IF EXISTS cohort_analysis;

CREATE OR REPLACE
VIEW cohort_analysis AS
WITH first_purchase AS (
	SELECT
		-- 1. cari tanggal pertama kali customer purchase product
		customer_id,
		date_trunc('month', min(date)) AS cohort_month
	FROM
		v_sales_cleaned
	GROUP BY
		customer_id
),
cohort_table AS (
	SELECT
		-- 2. Gabungkan untuk DATA sales dengan DATA  first purchase
		s.customer_id,
		f.cohort_month,
		(
			EXTRACT(YEAR FROM s.date) - EXTRACT(YEAR FROM f.cohort_month)
		) * 12 +
	(
			EXTRACT(MONTH FROM s.date) - EXTRACT(MONTH FROM f.cohort_month)
		) AS monthly_index
	FROM
		v_sales_cleaned AS s
	JOIN first_purchase AS f ON
		s.customer_id = f.customer_id
),
cust_count AS (
	SELECT
		cohort_month,
		monthly_index,
		count(DISTINCT customer_id) AS total_customers
	FROM
		cohort_table
	GROUP BY
		1,
		2
),
final_calculation AS (
	SELECT
		*,
		FIRST_VALUE(total_customers) OVER(PARTITION BY cohort_month ORDER BY monthly_index) AS cohort_size
	FROM
		cust_count
)
SELECT
	cohort_month,
	monthly_index,
	total_customers,
	cohort_size,
	(
		cohort_size - total_customers
	) AS churn_customers,
	round(100.0 * total_customers / cohort_size, 2) AS retention_pct,
	round(100.0 * (cohort_size - total_customers)/ cohort_size, 2) AS churn_pct
FROM
	final_calculation
WHERE
	cohort_month >= '2023-01-01'
ORDER BY
	cohort_month ASC,
	monthly_index ASC;
SELECT * FROM cohort_analysis;
-- dari analisis cohort berapa customer yg masih aktif membeli atau melakukan transaksi pembelian product 
-- dan berapa banyak yang sudah churn (tidak aktif) (jumlah dan persentase nya) untuk tahun transaksi terakhir nya
WITH customer_activity AS (
	SELECT
		customer_id,
		max(date) AS last_order_date,
		(
			SELECT
				max(date)
			FROM
				v_sales_cleaned
		) AS anchor_date
	FROM
		v_sales_cleaned
	WHERE date >= '2023-01-01'
	GROUP BY
		customer_id
),
status_flag AS (
	SELECT
		*,
		CAST(anchor_date - last_order_date AS int) AS days_since_order,
		CASE
			WHEN (
				anchor_date - last_order_date
			) <= 90 THEN 'Active'
			ELSE 'Churn'
		END AS cust_status
	FROM
		customer_activity
)
SELECT 
	cust_status,
	count(customer_id) AS total_customer,
	round(100.0 * count(customer_id) / sum(count(customer_id))OVER(), 0) AS pct_total
FROM
	status_flag
GROUP BY
	cust_status ;


/*---------------------------------------------------------------------------------------------------------------------------*/
-- RFM Analysis untuk segmentasi customers
-- new rfm rules
-- buat view table dari rfm analysis ini untuk deep dive analysis
DROP VIEW IF EXISTS rfm_segment;

CREATE OR REPLACE
VIEW rfm_segment AS
-- build main table untk customer nya
WITH customer_table AS (
	SELECT
		s.transaction_id,
		s.date,
		s.customer_id,
		-- Data dari Customer
		c.age_group,
		c.gender_cleaned,
		c.city AS customer_city,
		-- Data dari Product
		p.category_cleaned,
		p.list_price,
		p.cost_price,
		-- Data dari Store
		sd.store_name,
		sd.region AS store_region,
		-- Data Transaksi
		s.quantity,
		s.returned
	FROM
		v_sales_cleaned AS s
	INNER JOIN v_customer_cleaned AS c ON
		s.customer_id = c.customer_id
	INNER JOIN v_product_cleaned AS p ON
		s.product_id = p.product_id
	INNER JOIN store_data AS sd ON
		s.store_id = sd.store_id
	WHERE
		s.date >= '2023-01-01'
),
agg_table AS (
	-- buat aggregate table untuk cari total_order,profit, dan tanggal terakhir order
	SELECT
		customer_id,
		gender_cleaned,
		customer_city,
		age_group,
		round(count(DISTINCT transaction_id), 0) AS total_order,
		-- frequency value
		round(sum(quantity *(list_price - cost_price)), 0) AS total_profit,
		-- monetary_value
		max(date) AS last_order_date,
		ROUND(SUM(quantity * list_price) / COUNT(DISTINCT transaction_id), 0) AS avg_order_value,
		CAST((SELECT max(date) FROM v_sales_cleaned) - max(date) AS int) AS recency_days
		-- as recency value
	FROM
		customer_table
	GROUP BY
		customer_id,
		gender_cleaned,
		customer_city,
		age_group
),
-- hitung rfm value menggunakan ntile(5) untuk membagi menjadi 5 divisi customer group
-- 1. RFM Score:
		/*
		 	 1. Recency: 5 is the most recent, 1 is the least recent
			 2. Frequency: 5 is the most frequent, 1 is the least frequent
			 3. Monetary: 5 is the highest value, 1 is the lowest value
		 */
rfm_value AS (
	SELECT
		*,
		-- calculation untuk recency 
	NTILE(5) OVER(ORDER BY recency_days desc) AS recency,
		NTILE(5) OVER(ORDER BY total_order) AS frequency,
		NTILE(5) OVER(ORDER BY total_profit) AS monetary,
		NTILE(3) OVER(ORDER BY avg_order_value) AS avg_order_ntile
	FROM
		agg_table
),
-- Calculating RFM score by concatenation Recency value, Frequency value and Monetary value
rfm_score AS (
	SELECT
		*,
		-- gunakan || untuk mendapatkan rfm_score
	CAST(recency AS varchar) || CAST(frequency AS varchar)|| CAST(monetary AS varchar) AS rfm_cell,
		(
			recency + frequency + monetary
		) AS rfm_score
	FROM
		rfm_value
),
-- RFM segment based on Recency as the primary key (5=very recent, 1=least recent), 
-- then Monetary value (5=highest, 1=lowest), and 
-- Finally Frequency (5=very frequent, 1=least frequent)
rfm_segment AS (
	SELECT
		*,
		CASE
			-- champions segment
		WHEN recency = 5
				AND frequency >= 4
				AND monetary >= 4 THEN 'Champions'
				-- Loyal customer segment
				WHEN recency >= 4
				AND frequency >= 4
				AND monetary >= 1 THEN 'Loyal Customers'
				-- Potential loyal customers segment
				WHEN recency >= 4
				AND frequency <= 3
				AND monetary >= 1 THEN 'Potential Loyal Customers'
				-- Hibernating customers
				WHEN recency = 2
				AND frequency >= 1
				AND monetary >= 1 THEN 'Hibernating Customers'
				-- Lost Customers
				WHEN recency = 1
				AND frequency <= 5
				AND monetary <= 5 THEN 'Lost Customers'
				ELSE 'Need Attention / At Risk'
			END AS rfm_segmentation,
			CASE
				WHEN avg_order_ntile = 3 THEN 'High avg order value'
				WHEN avg_order_ntile = 2 THEN 'Medium avg order value'
				ELSE 'Low avg order value'
			END AS avg_order_value_segment
		FROM
			rfm_score
		ORDER BY
			customer_id
)
SELECT
	*
FROM
	rfm_segment;

/*deep dive into rfm segmentation analysis*/
-- 1. berapa banyak customer yang ada dan masuk ke RFM Segmentation (2023-2024)
SELECT
	rfm_segmentation,
	count(DISTINCT customer_id) AS total_customer,
	-- Menghitung persentase terhadap total keseluruhan kustomer
	ROUND(100.0 * COUNT(DISTINCT customer_id) / SUM(COUNT(DISTINCT customer_id)) OVER(), 2) AS pct_total
FROM
	rfm_segment
GROUP BY 
	rfm_segmentation
ORDER BY
	total_customer DESC;
-- 2. Berapa profit yg dihasilkan berdasarkan segment rfm
SELECT
	rfm_segmentation,
	sum(total_profit) AS total_profit_segment,
	count(DISTINCT customer_id) AS total_customers,
	ROUND(SUM(total_profit) * 100.0 / SUM(SUM(total_profit)) OVER (), 2) AS profit_percentage
FROM
	rfm_segment
GROUP BY
	rfm_segmentation
ORDER BY
	total_profit_segment DESC;
-- 3. Identifying the top 5 high value  customers by rfm score
WITH filter_cust AS (
	SELECT
		customer_id,
		customer_city,
		total_order,
		last_order_date,
		total_profit,
		avg_order_value,
		rfm_score,
		rfm_segmentation,
		avg_order_value_segment,
		DENSE_RANK() OVER(
		ORDER BY rfm_score DESC, avg_order_value DESC
	) AS rank_customer
	FROM
		rfm_segment
)
SELECT
	*
FROM
	filter_cust
WHERE
	rank_customer BETWEEN 1 AND 5;
-- 4. mapping di kota  mana customer  memiliki segmentasi rfm sebagai champions
SELECT
	customer_city,
	count(customer_id) AS total_high_value_cust,
	DENSE_RANK() OVER(ORDER BY count(customer_id) DESC) AS places_rank
FROM
	rfm_segment
WHERE
	rfm_segmentation = 'Champions'
	AND avg_order_value_segment = 'High avg order value'
GROUP BY
	1
ORDER BY
	total_high_value_cust DESC;

-- 5. Pada customer segementation diatas berasal dari kota apa saja dan profit yang dihasilkan berapa ?
SELECT 
	customer_city,
	sum(total_profit) AS customer_profit,
	-- berapa masing-masing customer, apa dateng ke store langsung atau melalui online
	count(DISTINCT customer_id) AS total_customer
FROM
	rfm_segment
GROUP BY
customer_city
ORDER BY
	customer_profit DESC,
	total_customer DESC;
-- 6. Dari analisa diatas populasi segmentasi champions dan lost customers dari kota mana saja
SELECT
	customer_city,
	rfm_segmentation,
	count(customer_id) AS total_customer,
	sum(total_order) AS total_vol_order,
	sum(total_profit) AS total_profit_contributions,
	round(100.0 * count(customer_id) / sum(count(DISTINCT customer_id)) OVER(PARTITION BY rfm_segmentation), 2) AS pct_share_segment
FROM
	rfm_segment
WHERE
	rfm_segmentation IN (
		'Champions', 'Lost Customers'
	)
GROUP BY
	customer_city,
	rfm_segmentation
ORDER BY
	total_vol_order DESC;
-- 7. berapa profit dari tahun 2023-2024
SELECT
	date,
	round(sum(s.quantity *(p.list_price - p.cost_price)), 0) AS total_profit,
	round(sum(s.quantity * p.list_price),0) AS total_revenue
FROM
	v_sales_cleaned AS s
LEFT JOIN v_product_cleaned AS p ON
	s.product_id = p.product_id
WHERE
	s.date BETWEEN '2023-01-01' AND '2024-12-31'
GROUP BY
	s.date
ORDER BY
	s.date ASC;

-- 8. dari segementasi customer diatas distribusi range umur nya gimana ?
SELECT
	rfm_segmentation,
	age_group,
	count(distinct customer_id) AS total_customer
FROM rfm_segment
GROUP BY rfm_segmentation,age_group;