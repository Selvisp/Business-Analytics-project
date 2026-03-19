create database project; 
select * from stores;
use project;
select * from stocks;
#store & Region wise sale Analysis
CREATE OR REPLACE VIEW vw_store_region_sales AS
SELECT 
    s.store_name,
    s.city,
    s.state,
    ROUND(SUM(oi.quantity * oi.list_price * (1 - oi.discount)), 2) AS total_sales
FROM Orders AS o
JOIN order_items AS oi
    ON o.order_id = oi.order_id
JOIN Stores AS s
    ON o.store_id = s.store_id
GROUP BY 
    s.store_name,
    s.city,
    s.state
ORDER BY 
    total_sales DESC;
    SELECT * FROM vw_store_region_sales;
    
    #Product wise sales & Inventory trends
   CREATE OR REPLACE VIEW vw_product_sales_trend AS
     SELECT 
    p.product_name,
    MONTHNAME(o.order_date) AS month_name,
    MONTH(o.order_date) AS month_number,  
    SUM(oi.quantity) AS total_sold,
    AVG(st.quantity) AS avg_stock
FROM order_items AS oi
JOIN orders AS o 
    ON oi.order_id = o.order_id
JOIN products AS p 
    ON oi.product_id = p.product_id
JOIN stocks AS st 
    ON p.product_id = st.product_id
GROUP BY 
    p.product_name, month_name, month_number
ORDER BY 
    p.product_name, month_number;
    SELECT * FROM vw_product_sales_trend;  
# Staff performance report
CREATE OR REPLACE VIEW vw_staff_performance AS
SELECT 
    CONCAT(s.first_name, ' ', s.last_name) AS staff_name,
    COUNT(DISTINCT o.order_id) AS total_orders,
    SUM(oi.quantity) AS total_quantity_sold,
    ROUND(SUM(oi.quantity * oi.list_price * (1 - oi.discount)), 2) AS total_sales_value
FROM orders AS o
 Inner JOIN order_items AS oi 
    ON o.order_id = oi.order_id
 Inner JOIN staffs AS s 
    ON o.staff_id = s.staff_id
GROUP BY s.staff_id, staff_name
ORDER BY total_sales_value DESC;
SELECT * FROM vw_staff_performance;
#Customer orders and order frequency
CREATE OR REPLACE VIEW vw_customer_orders AS
SELECT 
    CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
    COUNT(DISTINCT o.order_id) AS total_orders,
    ROUND(SUM(oi.quantity * oi.list_price * (1 - oi.discount)), 2) AS total_spent,
    ROUND(COUNT(DISTINCT o.order_id) / 
          (TIMESTAMPDIFF(MONTH, MIN(o.order_date), MAX(o.order_date)) + 1), 2) AS avg_orders_per_month
FROM orders AS o
JOIN order_items AS oi ON o.order_id = oi.order_id
JOIN customers AS c ON o.customer_id = c.customer_id
GROUP BY c.customer_id, customer_name
ORDER BY total_orders DESC;
SELECT * FROM vw_customer_orders;
#Revenue and discount analysis
CREATE OR REPLACE VIEW vw_revenue_discount AS

SELECT 
    p.product_name,
    ROUND(SUM(oi.quantity * oi.list_price * (1 - oi.discount)), 2) AS total_revenue,
    ROUND(SUM(oi.quantity * oi.list_price * oi.discount), 2) AS total_discount_amount,
    ROUND(AVG(oi.discount) * 100, 2) AS avg_discount_percent,
    COUNT(DISTINCT o.order_id) AS total_orders
FROM order_items AS oi
JOIN orders AS o ON oi.order_id = o.order_id
JOIN products AS p ON oi.product_id = p.product_id
GROUP BY p.product_name
ORDER BY total_revenue DESC;
SELECT * FROM vw_revenue_discount;

#Top 3 Selling brands by region

SELECT region, brand_name, total_sales, rn
FROM (
  SELECT
    s.state AS region,
    b.brand_name,
    ROUND(SUM(oi.quantity * oi.list_price * (1 - oi.discount)), 2) AS total_sales,
    ROW_NUMBER() OVER (PARTITION BY s.state ORDER BY SUM(oi.quantity * oi.list_price * (1 - oi.discount)) DESC) AS rn
  FROM order_items oi
  JOIN orders o ON oi.order_id = o.order_id
  JOIN stores s ON o.store_id = s.store_id
  JOIN products p ON oi.product_id = p.product_id
  JOIN brands b ON p.brand_id = b.brand_id
  GROUP BY s.state, b.brand_name
) t
WHERE rn <= 3
ORDER BY region, rn;


#top-selling brands by region and store.
SELECT
  s.state        AS region,
  s.store_name   AS store,
  b.brand_name   AS brand,
  SUM(oi.quantity * oi.list_price * (1 - COALESCE(oi.discount,0))) AS total_sales
  FROM order_items oi
JOIN products p  ON oi.product_id = p.product_id
JOIN brands b    ON p.brand_id = b.brand_id
JOIN orders o    ON oi.order_id = o.order_id
JOIN stores s    ON o.store_id = s.store_id
GROUP BY s.state, s.store_name, b.brand_name
ORDER BY s.state, s.store_name, total_sales DESC;

# staff performance based on total sales handled
SELECT
  s.staff_id,
  s.first_name,
  s.last_name,
  SUM(oi.quantity * oi.list_price * (1 - COALESCE(oi.discount, 0))) AS total_sales,
  SUM(oi.quantity) AS total_units,
  COUNT(DISTINCT oi.order_id) AS orders_handled,
  ROUND(SUM(oi.quantity * oi.list_price * (1 - COALESCE(oi.discount, 0))) /
        COUNT(DISTINCT oi.order_id), 2) AS avg_sales_per_order
FROM order_items oi
JOIN orders o ON oi.order_id = o.order_id
JOIN staffs s ON o.staff_id = s.staff_id
GROUP BY s.staff_id, s.first_name, s.last_name
ORDER BY total_sales DESC;
# customer orders and their fulfillment status
SELECT
  c.customer_id,
  c.first_name,
  c.last_name,
  COUNT(o.order_id) AS total_orders,
  SUM(CASE WHEN o.order_status = 4 THEN 1 ELSE 0 END) AS completed_orders,
  SUM(CASE WHEN o.order_status <> 4 THEN 1 ELSE 0 END) AS pending_or_cancelled,
  ROUND(SUM(CASE WHEN o.order_status = 4 THEN 1 ELSE 0 END) * 100.0 / COUNT(o.order_id), 2) AS fulfillment_rate,
  MAX(o.order_date) AS last_order_date
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
GROUP BY c.customer_id, c.first_name, c.last_name
ORDER BY fulfillment_rate DESC, total_orders DESC;

# The most profitable product categories
SELECT
  c.category_id,
  c.category_name,
  SUM(oi.quantity * oi.list_price * (1 - COALESCE(oi.discount, 0))) AS total_sales,
  SUM(oi.quantity) AS total_units_sold,
  ROUND(SUM(oi.quantity * oi.list_price * (1 - COALESCE(oi.discount, 0))) / SUM(oi.quantity), 2) AS avg_price_per_unit
FROM order_items oi
JOIN products p ON oi.product_id = p.product_id
JOIN categories c ON p.category_id = c.category_id
GROUP BY c.category_id, c.category_name
ORDER BY total_sales DESC;
# stock levels across stores to optimize inventory
SELECT
  s.store_name,
  p.product_name,
  c.category_name,
  st.quantity AS current_stock,
  p.list_price,
  ROUND(st.quantity * p.list_price, 2) AS stock_value
FROM stocks st
JOIN stores s ON st.store_id = s.store_id
JOIN products p ON st.product_id = p.product_id
JOIN categories c ON p.category_id = c.category_id
ORDER BY s.store_name, c.category_name, st.quantity ASC;

# order monthly trends
SELECT
  YEAR(o.order_date) AS year,
  MONTH(o.order_date) AS month_num,
  MONTHNAME(o.order_date) AS month,
  COUNT(o.order_id) AS total_orders,
  SUM(oi.quantity * oi.list_price * (1 - COALESCE(oi.discount,0))) AS total_sales
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
GROUP BY YEAR(o.order_date), MONTH(o.order_date), MONTHNAME(o.order_date)
ORDER BY YEAR(o.order_date), MONTH(o.order_date);

# Delayed Shipment Report
SELECT
  o.order_id,
  o.order_date,
  o.required_date,
  o.shipped_date,
  DATEDIFF(o.shipped_date, o.required_date) AS delay_days,
  CASE 
    WHEN o.shipped_date <= o.required_date THEN 'On Time'
    ELSE 'Delayed'
  END AS delivery_status
FROM orders o
ORDER BY o.shipped_date;
# On-Time vs Delayed Shipments
SELECT
  CASE 
    WHEN o.shipped_date <= o.required_date THEN 'On Time'
    ELSE 'Delayed'
  END AS shipment_status,
  COUNT(o.order_id) AS total_orders,
  ROUND(COUNT(o.order_id) * 100.0 / (SELECT COUNT(*) FROM `Orders`), 2) AS pct_of_total
FROM orders o
GROUP BY shipment_status;

# Customer concentration and demographics
SELECT
  c.state,
  c.city,
  COUNT(c.customer_id) AS total_customers,
  COUNT(DISTINCT o.order_id) AS total_orders,
  ROUND(SUM(oi.quantity * oi.list_price * (1 - COALESCE(oi.discount, 0))), 2) AS total_sales,
  ROUND(SUM(oi.quantity * oi.list_price * (1 - COALESCE(oi.discount, 0))) / COUNT(DISTINCT c.customer_id), 2) AS avg_sales_per_customer
FROM customers c
LEFT JOIN orders o ON c.customer_id = o.customer_id
LEFT JOIN order_items oi ON o.order_id = oi.order_id
GROUP BY c.state, c.city
ORDER BY total_customers DESC, total_sales DESC;
















