SELECT 
    cohort_year,
    Count(DISTINCT customerkey) AS total_customers,
    Sum(total_net_revenue) AS total_revenue,
    Sum(total_net_revenue)/Count(DISTINCT customerkey) AS customer_revenue
FROM cohort_analysis 
WHERE orderdate=first_purchase_date
GROUP BY cohort_year

