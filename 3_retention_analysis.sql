WITH customer_last_purchase AS
(SELECT
    customerkey,
    cleaned_name,
    orderdate,
    row_number() OVER (PARTITION BY customerkey ORDER BY orderdate DESC) AS rn,
    first_purchase_date,
    cohort_year
FROM cohort_analysis
),
churned_customers AS 
(
SELECT customerkey,
       cleaned_name,
       orderdate AS last_purchase_date,
       CASE 
       	  WHEN orderdate< (SELECT max(orderdate) FROM sales)- INTERVAL '6 months' THEN 'Churned Customer'
       	  ELSE 'Active Customer'
       END AS customer_status,
       cohort_year
       
FROM customer_last_purchase 
WHERE rn=1 AND first_purchase_date < (SELECT max(orderdate) FROM sales)- INTERVAL '6 months'
)
-- since the last purchase date(data ending on) is 2024-04-20, all the customers who have purchased within 6 months of this date would show as active since they have not crossed the period of 6 months. This would be highly wrong and skew the data(eg all customers in 2024 would show active)
-- therefore we need to consider customers who have been in the system for more than 6 months.

SELECT cohort_year,
       customer_status,
       Count(customerkey) AS num_customers,
       Sum(Count(customerkey)) OVER (PARTITION BY cohort_year) AS total_customers,
       Round(Count(customerkey)/Sum(Count(customerkey)) OVER (PARTITION BY cohort_year),2) AS status_percentage
FROM churned_customers
GROUP BY cohort_year, customer_status



