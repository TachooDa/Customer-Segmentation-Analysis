-- buat table customer, produc dan store terlebih dahulu
CREATE TABLE customer_data (
	customer_id varchar(50) NOT NULL PRIMARY KEY,
	age int,
	gender varchar(50),
	city varchar(50),
	email varchar(100)
);

CREATE TABLE product_data (
	product_id varchar(50) NOT NULL PRIMARY KEY,
	category varchar(50),
	color varchar(50),
	size varchar(15),
	season  varchar(50),
	supplier varchar(50),
	cost_price decimal(10,2),
	list_price decimal(10,2)
);

CREATE TABLE store_data (
	store_id varchar(50) NOT NULL PRIMARY KEY,
	store_name varchar(50),
	region varchar(50),
	store_size_m2 int
);

CREATE TABLE sales_data (
	transaction_id varchar(50) NOT NULL PRIMARY KEY,
	date date,
	product_id varchar(50) ,
	store_id varchar(50) ,
	customer_id varchar(50),
	quantity int,
	discount decimal(10,2),
	returned boolean,
	 FOREIGN KEY (product_id) REFERENCES product_data(product_id),
    FOREIGN KEY (store_id) REFERENCES store_data(store_id),
    FOREIGN KEY (customer_id) REFERENCES customer_data(customer_id)
);
SELECT * FROM store_data;
DROP TABLE IF EXISTS customer_data ;
DROP TABLE IF EXISTS product_data ;
DROP TABLE IF EXISTS store_data ;
DROP TABLE  IF EXISTS sales_data;
ALTER TABLE sales_data
ALTER COLUMN  discount TYPE decimal(10,2);
--- load data dari csv ke pgadmin lewat psql tools
\copy customer_data FROM 'C:\Users\USER\Documents\Data Analyst Course\mrf assets\customer_data.csv' WITH (FORMAT csv, HEADER true, DELIMITER ',', ENCODING 'UTF8', NULL 'null');
\copy product_data FROM 'C:\Users\USER\Documents\Data Analyst Course\mrf assets\product_data.csv' WITH (FORMAT csv, HEADER true, DELIMITER ',', ENCODING 'UTF8', NULL 'null');
\copy store_data FROM 'C:\Users\USER\Documents\Data Analyst Course\mrf assets\store_data.csv' WITH (FORMAT csv, HEADER true, DELIMITER ',', ENCODING 'UTF8', NULL 'null');
\copy sales_data FROM 'C:\Users\USER\Documents\Data Analyst Course\mrf assets\sales_data.csv' WITH (FORMAT csv, HEADER true, DELIMITER ',', ENCODING 'UTF8', NULL '');
