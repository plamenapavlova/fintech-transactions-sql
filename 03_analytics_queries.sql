-- =====================================================================
-- Fintech Transactions Database - Analytics queries
-- PostgreSQL 16
-- =====================================================================


-- ---------------------------------------------------------------------
-- Q1. Spend by merchant category
-- Business question: where does customer money go?
-- Concepts: JOIN, GROUP BY, SUM/COUNT, ORDER BY
-- ---------------------------------------------------------------------
SELECT
    mc.category_name,
    COUNT(*)                AS num_transactions,
    SUM(t.amount)           AS total_spend,
    ROUND(AVG(t.amount), 2) AS avg_ticket
FROM transactions t
JOIN merchants           m  ON m.merchant_id  = t.merchant_id
JOIN merchant_categories mc ON mc.category_id = m.category_id
WHERE t.status = 'COMPLETED'
GROUP BY mc.category_name
ORDER BY total_spend DESC;


-- ---------------------------------------------------------------------
-- Q2. High-value transactions > EUR 300
-- Business question: which large payments happened, where and with whom?
-- Concepts: multi-table JOIN, filtering
-- ---------------------------------------------------------------------
SELECT
    t.transaction_id,
    t.created_at,
    c.full_name,
    m.merchant_name,
    ci.city_name AS merchant_city,
    t.amount,
    t.status
FROM transactions t
JOIN customers c  ON c.customer_id  = t.customer_id
JOIN merchants m  ON m.merchant_id  = t.merchant_id
JOIN cities    ci ON ci.city_id     = m.city_id
WHERE t.amount > 300
ORDER BY t.amount DESC;


-- ---------------------------------------------------------------------
-- Q3. Inactive customers - no transactions at all
-- Business question: who signed up but never used their card?
-- Concepts: correlated subquery with NOT EXISTS
-- (NOT EXISTS is preferred over NOT IN, which returns no rows
--  if the subquery ever yields a NULL.)
-- ---------------------------------------------------------------------
SELECT
    c.customer_id,
    c.full_name,
    c.tier,
    c.signup_date
FROM customers c
WHERE NOT EXISTS (
    SELECT 1
    FROM transactions t
    WHERE t.customer_id = c.customer_id
);


-- ---------------------------------------------------------------------
-- Q4. Activity summary for every customer, including inactive ones
-- Business question: how active is each customer?
-- Concepts: LEFT JOIN, conditions in the ON clause, COALESCE
-- (The status filter sits in ON, not WHERE: a WHERE filter on the
--  right-hand table would turn the LEFT JOIN into an INNER JOIN and
--  silently drop customers without transactions.)
-- ---------------------------------------------------------------------
SELECT
    c.full_name,
    c.tier,
    COUNT(t.transaction_id)        AS num_transactions,
    COALESCE(SUM(t.amount), 0)     AS total_spend
FROM customers c
LEFT JOIN transactions t
       ON t.customer_id = c.customer_id
      AND t.status = 'COMPLETED'
GROUP BY c.customer_id, c.full_name, c.tier
ORDER BY total_spend DESC;


-- ---------------------------------------------------------------------
-- Q5. Merchant performance
-- Business question: which merchants generate the most revenue?
-- Concepts: JOIN, GROUP BY on several columns, HAVING
-- ---------------------------------------------------------------------
SELECT
    m.merchant_name,
    mc.category_name,
    COUNT(*)      AS num_transactions,
    SUM(t.amount) AS revenue
FROM transactions t
JOIN merchants           m  ON m.merchant_id  = t.merchant_id
JOIN merchant_categories mc ON mc.category_id = m.category_id
WHERE t.status = 'COMPLETED'
GROUP BY m.merchant_name, mc.category_name
HAVING COUNT(*) >= 5
ORDER BY revenue DESC;


-- ---------------------------------------------------------------------
-- Q6. Average ticket by tier compared with the overall average
-- Business question: do premium tiers really spend more per payment?
-- Concepts: scalar subquery (a subquery that returns a single value)
-- ---------------------------------------------------------------------
SELECT
    c.tier,
    COUNT(*)                 AS num_transactions,
    ROUND(AVG(t.amount), 2)  AS avg_ticket,
    ROUND((SELECT AVG(amount)
           FROM transactions
           WHERE status = 'COMPLETED'), 2) AS overall_avg_ticket
FROM transactions t
JOIN customers c ON c.customer_id = t.customer_id
WHERE t.status = 'COMPLETED'
GROUP BY c.tier
ORDER BY avg_ticket DESC;


-- ---------------------------------------------------------------------
-- Q7. Customers who spend more than the average customer
-- Business question: who are the above-average customers?
-- Concepts: HAVING with a subquery, derived table (subquery in FROM)
-- ---------------------------------------------------------------------
SELECT
    c.full_name,
    c.tier,
    SUM(t.amount) AS total_spend
FROM transactions t
JOIN customers c ON c.customer_id = t.customer_id
WHERE t.status = 'COMPLETED'
GROUP BY c.customer_id, c.full_name, c.tier
HAVING SUM(t.amount) > (
    SELECT AVG(customer_total)
    FROM (
        SELECT SUM(amount) AS customer_total
        FROM transactions
        WHERE status = 'COMPLETED'
        GROUP BY customer_id
    ) AS per_customer
)
ORDER BY total_spend DESC;


-- ---------------------------------------------------------------------
-- Q8. Monthly payment volume
-- Business question: how is volume trending over the half-year?
-- Concepts: grouping by a date expression with TO_CHAR
-- ---------------------------------------------------------------------
SELECT
    TO_CHAR(created_at, 'YYYY-MM') AS month,
    COUNT(*)                       AS num_transactions,
    SUM(amount)                    AS monthly_volume,
    ROUND(AVG(amount), 2)          AS avg_ticket
FROM transactions
WHERE status = 'COMPLETED'
GROUP BY TO_CHAR(created_at, 'YYYY-MM')
ORDER BY month;


-- ---------------------------------------------------------------------
-- Q9. Customer segmentation by total spend
-- Business question: how many customers are low, medium or high spenders?
-- Concepts: CASE expression, derived table, LEFT JOIN, COALESCE
-- ---------------------------------------------------------------------
SELECT
    segment,
    COUNT(*)          AS num_customers,
    SUM(total_spend)  AS segment_spend
FROM (
    SELECT
        c.customer_id,
        COALESCE(SUM(t.amount), 0) AS total_spend,
        CASE
            WHEN COALESCE(SUM(t.amount), 0) >= 1500 THEN 'High'
            WHEN COALESCE(SUM(t.amount), 0) >= 800  THEN 'Medium'
            WHEN COALESCE(SUM(t.amount), 0) > 0     THEN 'Low'
            ELSE 'Inactive'
        END AS segment
    FROM customers c
    LEFT JOIN transactions t
           ON t.customer_id = c.customer_id
          AND t.status = 'COMPLETED'
    GROUP BY c.customer_id
) AS customer_totals
GROUP BY segment
ORDER BY segment_spend DESC;


-- ---------------------------------------------------------------------
-- Q10. Decline and refund rates by merchant category
-- Business question: where do payments fail or get reversed most often?
-- Concepts: conditional aggregation with SUM(CASE ...), percentages
-- ---------------------------------------------------------------------
SELECT
    mc.category_name,
    COUNT(*)                                              AS all_attempts,
    SUM(CASE WHEN t.status = 'DECLINED' THEN 1 ELSE 0 END) AS declined,
    SUM(CASE WHEN t.status = 'REFUNDED' THEN 1 ELSE 0 END) AS refunded,
    ROUND(100.0 * SUM(CASE WHEN t.status = 'DECLINED' THEN 1 ELSE 0 END)
          / COUNT(*), 1)                                  AS decline_rate_pct
FROM transactions t
JOIN merchants           m  ON m.merchant_id  = t.merchant_id
JOIN merchant_categories mc ON mc.category_id = m.category_id
GROUP BY mc.category_name
ORDER BY decline_rate_pct DESC, all_attempts DESC;
