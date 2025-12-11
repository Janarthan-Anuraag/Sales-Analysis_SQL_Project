# SQL - Sales Analysis

**Technical Details**:

- Database: PostgreSQL
- Analysis Tools: PostgreSQL, DBeaver, PGadmin
- Coding,business-related tips: ChatGPT

## Overview

About Contoso: The Contoso Corporation is a multinational business with its headquarters in Paris. The company is a manufacturing, sales, and support organization with more than 100,000 products.

This database has data related to customers, sales, products. I analyzed customer behavior, retention, and lifetime value for an E-Commerce company to understand how different customer groups/segments perform over time. This helped identify ways to keep customers coming back and increase overall revenue.

## Business Problems

1. **Customer Segmentation Analysis** : Who are our most valuable customers? 
2. **Cohort Analysis** : How do diferent customer groups generate revenue?
3. **Retention Analysis**: Which customers haven't purchased recently?

**Creating View: customer_analysis**

First I created a view which can be used when needed. (A view is a virtual table that allows us to use results of a stored query.) 

```sql
CREATE OR REPLACE VIEW public.cohort_analysis
AS WITH customer_revenue AS (
         SELECT s.customerkey,
            s.orderdate,
            sum(s.quantity::double precision * s.netprice / s.exchangerate) AS total_net_revenue,
            count(s.orderkey) AS num_orders,
            c.countryfull,
            c.age,
            c.givenname,
            c.surname
           FROM sales s
             LEFT JOIN customer c ON c.customerkey = s.customerkey
          GROUP BY s.customerkey, s.orderdate, c.countryfull, c.age, c.givenname, c.surname
        )
 SELECT customerkey,
    orderdate,
    total_net_revenue,
    num_orders,
    countryfull,
    age,
    concat(TRIM(BOTH FROM givenname), ' ', TRIM(BOTH FROM surname)) AS cleaned_name,
    min(orderdate) OVER (PARTITION BY customerkey) AS first_purchase_date,
    EXTRACT(year FROM min(orderdate) OVER (PARTITION BY customerkey)) AS cohort_year
   FROM customer_revenue cr;
   ```
I wanted to create a clean and useful view of each customer’s purchase history so I could analyze how customers behave over time.

- First, I calculated how much revenue each customer generated on each purchase date, along with the number of orders they made, by joining the sales and customer tables.

- I also included some customer info like their country, age, and full name (combined and cleaned up).

- Then, I figured out when each customer made their first purchase using a window function. This helps to group customers into cohorts (like all customers who joined in 2021, 2022, etc.).

- Finally, I added a "cohort year" column by extracting the year from their first purchase date.

The whole idea was to prepare a ready-to-use dataset that could help me do cohort analysis, like tracking how different groups of customers perform over time and assign cohort year in front of each customers.

## Analysis Approach
### 1. Customer Segmentation Analysis:

1. Categorized customers based on total lifetime value (LTV).
2. Segmented customers to High, Mid, and Low-value customers.
3. Calculated key metrics: Average customer value in each segment,percentage contribution.

Query:

```sql
WITH customer_ltv AS (
 SELECT 
    customerkey,
    cleaned_name,
    SUM(total_net_revenue) AS total_ltv
 FROM cohort_analysis 
 GROUP BY 
    customerkey,
    cleaned_name
 ), customer_segments AS ( 
 SELECT  
    percentile_cont(0.25) WITHIN GROUP (ORDER BY total_ltv) AS ltv_25th_percentile,
    percentile_cont(0.75) WITHIN GROUP (ORDER BY total_ltv) AS ltv_75th_percentile
 FROM customer_ltv 
 ), segment_values AS (
SELECT c.* ,
    CASE WHEN c.total_ltv < cs.ltv_25th_percentile THEN '1-Low-Value'
         WHEN c.total_ltv <= cs.ltv_75th_percentile THEN '2-Mid-Value'
         ELSE '3-High-value'
    END AS customer_segment
FROM customer_ltv c, customer_segments cs)

SELECT customer_segment,
       Sum(total_ltv) AS total_ltv,
       Count(customerkey) AS customer_count,
       Sum(total_ltv)/ Count(customerkey) AS avg_ltv
FROM segment_values
GROUP BY customer_segment
```
I wrote this code to break down our customers based on how much revenue they’ve brought in overall. First, I calculated the total LTV for each customer, then used percentiles to split them into low, mid, and high-value segments. Finally, I summarized how much total revenue each segment brings in and how many customers fall into each. This helps us understand which group contributes most to our revenue and where we might want to focus our marketing or retention efforts.

📊 Key Findings:

![table1](/images/table1.png)

💡 Business Insights:

We can see that high value customers contribute over 65% of the revenue which is great since customers who pay more are buying more. Mid value customers contribute around 30% of the revenue which is what we should expect. Low value customers contribute around 2% of the total revenue which both alarming and shows signs that we can improve here.

🧩 Strategic Recommendations:

- High-Value: Introduce an exclusive premium membership or loyalty program targeted at the 12,372 top-tier customers. Given their outsized contribution to revenue, retaining even a small portion of this group is critical, as churn within this segment has a significant financial impact.

- Mid-Value: Implement personalized upsell strategies, such as tailored product bundles or targeted discounts, to encourage this group to increase their spending. Optimizing this segment could unlock a potential revenue increase from $66.6M to $135.4M.

- Low-Value: Launch re-engagement initiatives focusing on affordability, including price-sensitive promotions or limited-time offers. The goal is to boost purchase frequency and gradually move some of these users into higher-value segments.


### 2. Cohort Analysis:

1. Tracked revenue and customer count per cohorts.
2. Cohorts were grouped by year of first purchase.
3. Analyzed customer retention at a cohort level.

Query: 

```sql

SELECT 
    cohort_year,
    Count(DISTINCT customerkey) AS total_customers,
    Sum(total_net_revenue) AS total_revenue,
    Sum(total_net_revenue)/Count(DISTINCT customerkey) AS customer_revenue
FROM cohort_analysis 
WHERE orderdate=first_purchase_date
GROUP BY 
    cohort_year
```
I wrote this code to understand how valuable each cohort of customers is in their first purchase. By grouping the data by cohort year and filtering only for first-time purchases, I could calculate how many unique customers joined each year, how much total revenue they brought in initially, and what the average revenue per customer was. This helps get a clear picture of how strong each year's customer acquisition was.

📊 Key Findings:

- There is decline in revenue generated per customer over the years , which is contorary to what we would expect.

   - 2022-2024 cohorts are consistently performing worse than earlier cohorts.    
   - Although net revenue is increasing, this is likely due to a larger customer base, which is not reflective of customer value.

💡 Business Insights

- Declining Customer Value:
The average revenue generated per customer (LTV) has shown a downward trend across successive cohorts, suggesting a reduction in value extracted from newly acquired users.
- Drop in New Customer Acquisition (2023):
A significant decline in the number of customers acquired in 2023 raises concerns about the effectiveness of current acquisition strategies or market conditions.
- Combined Revenue Pressure:
The simultaneous drop in customer acquisition and declining customer value poses a potential long-term revenue risk, indicating the need for both retention and acquisition strategy reevaluation.

🧩 Strategic Recommendations:
 - Re-evaluate Acquisition Channels:
Conduct a performance audit of marketing and sales channels used in 2023 to identify underperforming sources and reallocate budget toward higher-converting channels.
  - Strengthen Onboarding and Engagement Programs:
Introduce or enhance early-life customer engagement strategies (e.g., personalized onboarding, product tutorials, usage incentives) to increase activation and long-term value.
  - Explore Cohort-Specific Offers or Retention Plans:
Design targeted offers or loyalty programs for recent cohorts to improve retention and revenue per user, helping to stabilize LTV trends.

### 3. Customer Retention:

1. Flagged customers showing signs of potential churn
2. Examined recent purchasing trends and behavior
3. Computed key performance metrics at the individual customer level

Query:

```sql
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
```
I wrote this query to figure out which customers have stopped buying from us and which ones are still active. First, I found the most recent purchase for each customer. Then, I marked anyone who hasn’t bought anything in the last 6 months as “churned” — but only for customers who joined at least 6 months ago, so the data isn’t skewed by newer ones who haven’t had a chance to buy again yet. Finally, I broke it down by cohort year to see the share of active vs. churned customers over time.

📊 Key Findings:

- Cohort churn stabilizes at ~90% after 2–3 years, indicating a consistent long-term retention ceiling.
- Retention remains low (8–10%)(Average Customer Retention in E-Commerce: 15%-25%) across all cohorts, pointing to a systemic challenge rather than cohort-specific issues.
-Recent cohorts (2022–2023) are following similar churn patterns, suggesting that without changes, future cohorts will experience the same drop-off.
- Customer value is concentrated in the early lifecycle, making the first 12–24 months critical for driving long-term value.

🧩 Strategic Recommendations:

- Implement short, non-intrusive exit surveys or post-churn feedback requests to understand why users leave. Use this qualitative data to uncover patterns (e.g., pricing concerns, product experience, lack of value) and feed those insights into both product development and customer experience improvements.
- Target high-value churned users with win-back campaigns instead of broad messaging to increase ROI and recover meaningful revenue.
- Not all users churn for the same reasons. Segment retention strategies by cohort age (e.g., 0–6 months, 6–12 months, 1–2 years) and tailor engagement tactics accordingly. For instance, newer cohorts may respond better to onboarding education or rewards, while older ones may need reactivation triggers like exclusive deals or limited-time offers.
- Continuously monitor cohort behavior, using real-time analytics to test what works.

