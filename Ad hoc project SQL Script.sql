-- Q.   Provide the list of markets in which customer  "Atliq  Exclusive"  operates its 
-- business in the  APAC  region. 

SELECT DISTINCT market FROM dim_customer
WHERE customer LIKE "%atliq exclusive%" AND region = "APAC";

-- Q.  What is the percentage of unique product increase in 2021 vs. 2020? The 
-- final output contains these fields, 
/*   unique_products_2020 
	 unique_products_2021 
	 percentage_chg */
     
WITH cte AS (
	SELECT count(DISTINCT product_code) AS unique_product_2020
	FROM fact_sales_monthly
	WHERE fiscal_year = 2020),

cte2 AS (
	SELECT count(DISTINCT product_code) AS unique_product_2021
	FROM fact_sales_monthly
	WHERE fiscal_year = 2021)
    
SELECT *,
	ROUND(((unique_product_2021-unique_product_2020)/ unique_product_2020) * 100, 2) AS percentage_chg
FROM cte
JOIN cte2;

/* Q3.  Provide a report with all the unique product counts for each  segment  and 
	sort them in descending order of product counts. The final output contains 
	2 fields, 
	segment 
	product_count */
    
SELECT segment, COUNT(DISTINCT product_code) as product_count
FROM dim_product
GROUP BY segment
ORDER BY product_count DESC;

/* Q4.  Follow-up: Which segment had the most increase in unique products in 
	2021 vs 2020? The final output contains these fields, 
	segment 
	product_count_2020 
	product_count_2021 
	difference */

WITH cte AS(
	SELECT segment, COUNT(DISTINCT p.product_code) as product_count_2020
	FROM dim_product AS p
	JOIN fact_sales_monthly AS fsm
	ON p.product_code = fsm.product_code
	WHERE fiscal_year = 2020
	GROUP BY segment
	ORDER BY product_count_2020 DESC),
    
cte2 AS(
	SELECT segment, COUNT(DISTINCT p.product_code) as product_count_2021
	FROM dim_product AS p
	JOIN fact_sales_monthly AS fsm
	ON p.product_code = fsm.product_code
	WHERE fiscal_year = 2021
	GROUP BY segment
	ORDER BY product_count_2021 DESC)

SELECT cte2.segment, product_count_2020, product_count_2021,
	(product_count_2021 - product_count_2020) AS difference
FROM cte 
JOIN cte2
ON cte.segment = cte2.segment
ORDER BY difference DESC;

/* Q4.5
	Which segments generated the highest average profit or 
	gross margin, and are there any segments with high product variety but low profitability?*/

select segment, 
	count(distinct p.product_code) as product_count,
    round(sum(cogs)/1000000,2) as cogs_mln,
    round(sum(gross_margin)/ 1000000, 2) as total_gross_margin_mln,
    round(avg(gross_margin), 2) as avg_gm_per_product,
    round(sum(gross_margin) * 100 /sum(net_sales) ,1) as gm_pct
from dim_product as p
join agg_gross_margin as gm 
on p.product_code = gm.product_code
group by segment
order by product_count desc;


/* Q5.  Get the products that have the highest and lowest manufacturing costs. 
	The final output should contain these fields, 
	product_code 
	product 
	manufacturing_cost */


SELECT p.product_code, product, manufacturing_cost
FROM dim_product AS p
JOIN fact_manufacturing_cost AS fmc
ON p.product_code = fmc.product_code
WHERE manufacturing_cost = (SELECT MAX(manufacturing_cost) AS highest_manufacturing_costs 
							FROM fact_manufacturing_cost) 
	OR manufacturing_cost =(SELECT MIN(manufacturing_cost) AS lowest_manufacturing_costs
                            FROM fact_manufacturing_cost)
ORDER BY manufacturing_cost DESC;

/* Q6.  Generate a report which contains the top 5 customers who received an 
	average high  pre_invoice_discount_pct  for the  fiscal  year 2021  and in the 
	Indian  market. The final output contains these fields, 
	customer_code 
	customer 
	average_discount_percentage */

SELECT c.customer_code, customer, 
	ROUND(AVG(pre_invoice_discount_pct)*100, 2) AS average_discount_pct
FROM dim_customer AS c
JOIN fact_pre_invoice_deductions AS pre
ON c.customer_code = pre.customer_code
WHERE fiscal_year = 2021 AND market = "INDIA"
GROUP BY c.customer_code, customer
ORDER BY average_discount_pct DESC
LIMIT 5;

-- Q6.5 What is the gross sales contribution of the top 5 customers who received 
-- the highest average discounts, and are these discounts justified by their revenue impact?

SELECT c.customer_code, customer, 
	ROUND(AVG(pre_invoice_discount_pct)*100, 2) AS average_discount_pct,
    ROUND(SUM(gross_price_total)/1000000, 2) as gross_sales_mln,
    ROUND((sum(gross_price_total) * (1 - avg(pre_invoice_discount_pct)))/1000000,2) as net_price,
    round( gross_price_total * 100/sum(gross_price_total) over(), 2) as gs_contribution_pct
FROM dim_customer AS c
JOIN fact_pre_invoice_deductions AS pre
ON c.customer_code = pre.customer_code
JOIN agg_gross_margin as gm
ON gm.customer_code = c.customer_code and 
	c.market = gm.market
WHERE pre.fiscal_year = 2021 AND c.market = "INDIA"
GROUP BY c.customer_code, customer
ORDER BY average_discount_pct DESC
LIMIT 5;


/* Q7.  Get the complete report of the Gross sales amount for the customer  “Atliq 
	Exclusive”  for each month  .  This analysis helps to  get an idea of low and 
	high-performing months and take strategic decisions. 
	The final report contains these columns: 
	Month 
	Year 
	Gross sales Amount */
    
SELECT fsm.fiscal_year,  DATE_FORMAT(date, "%M") AS months,
	ROUND(SUM(sold_quantity * gross_price)/1000000,2) AS gross_sales_mln
FROM fact_sales_monthly AS fsm
JOIN fact_gross_price AS fgp
ON fsm.product_code = fgp.product_code AND
	fsm.fiscal_year = fgp.fiscal_year
JOIN dim_customer AS c
ON fsm.customer_code = c.customer_code
WHERE customer LIKE "%atliq exclusive%" AND fsm.fiscal_year in(2020, 2021)
GROUP BY fsm.fiscal_year, date;

/* Q8.  In which quarter of 2020, got the maximum total_sold_quantity? The final 
	output contains these fields sorted by the total_sold_quantity, 
	Quarter 
	total_sold_quantity */
    
SELECT get_fiscal_quarter(date) AS quarter,
	SUM(sold_quantity) AS total_sold_qty 
FROM fact_sales_monthly
WHERE fiscal_year= 2020
GROUP BY quarter
ORDER BY total_sold_qty DESC;

/* Q9.  Which channel helped to bring more gross sales in the fiscal year 2021 
	and the percentage of contribution?  The final output  contains these fields, 
	channel 
	gross_sales_mln 
	percentage  */
    
WITH cte AS(
SELECT channel, ROUND(SUM(sold_quantity * gross_price)/1000000 ,2) AS gross_sales_mln
FROM fact_sales_monthly AS fsm
JOIN fact_gross_price AS fgp
ON fsm.product_code = fgp.product_code AND
	fsm.fiscal_year = fgp.fiscal_year
JOIN dim_customer AS c
ON fsm.customer_code = c.customer_code
GROUP BY channel)

SELECT channel, gross_sales_mln,
	ROUND(gross_sales_mln/ (SELECT SUM(gross_sales_mln) FROM cte )* 100 , 2) AS pct
FROM cte
ORDER BY pct DESC;

/* Q9.5 How did each sales channel’s gross sales change from 2020 to 2021, 
	and which channels are showing the strongest growth? */

with cte as (
SELECT channel,
	ROUND(SUM(CASE 
				WHEN fiscal_year = 2020 THEN gross_price_total 
			ELSE 0 END)/ 1000000, 2) as 20_gross_sales_mln,
	ROUND(SUM(CASE 
				WHEN fiscal_year = 2021 THEN gross_price_total 
			ELSE 0 END)/ 1000000, 2) as 21_gross_sales_mln
FROM agg_gross_margin AS gm
JOIN dim_customer AS c
ON gm.customer_code = c.customer_code
GROUP BY channel )

select channel, 20_gross_sales_mln, 21_gross_sales_mln,
	round(((21_gross_sales_mln - 20_gross_sales_mln) / 20_gross_sales_mln) *100, 2) as yoy_growth_pct
from cte
order by yoy_growth_pct desc;


/* Q 10.  Get the Top 3 products in each division that have a high 
	total_sold_quantity in the fiscal_year 2021? The final output contains these fields, 
	division 
	product_code 
	product 
	total_sold_quantity 
	rank_order */

WITH cte AS(
	SELECT division, p.product_code, product, 
		SUM(sold_quantity) AS total_sold_quantity
	FROM fact_sales_monthly AS fsm
	JOIN dim_product AS p
	ON fsm.product_code = p.product_code
	WHERE fiscal_year = 2021
	GROUP BY division, p.product_code, product),

cte2 AS (
	SELECT *,
		DENSE_RANK() OVER(PARTITION BY division ORDER BY total_sold_quantity DESC) drnk
	FROM cte)

SELECT *
FROM cte2
WHERE drnk <= 3;

