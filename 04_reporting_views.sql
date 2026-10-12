-- =====================================================================
-- Fintech Transactions Database - Reporting view
-- PostgreSQL 16
-- =====================================================================

-- Monthly spend per customer and category, ready for dashboards.
-- Hides the joins and the status filter behind one reusable object.
CREATE OR REPLACE VIEW v_monthly_customer_spend AS
SELECT
    DATE_TRUNC('month', t.created_at)::DATE AS month,
    c.customer_id,
    c.full_name,
    c.tier,
    mc.category_name,
    COUNT(*)      AS num_transactions,
    SUM(t.amount) AS total_spend
FROM transactions t
JOIN customers           c  ON c.customer_id  = t.customer_id
JOIN merchants           m  ON m.merchant_id  = t.merchant_id
JOIN merchant_categories mc ON mc.category_id = m.category_id
WHERE t.status = 'COMPLETED'
GROUP BY DATE_TRUNC('month', t.created_at), c.customer_id,
         c.full_name, c.tier, mc.category_name;

-- Example use: total spend per tier in Q2 2026
-- SELECT tier, SUM(total_spend) AS q2_spend
-- FROM v_monthly_customer_spend
-- WHERE month BETWEEN DATE '2026-04-01' AND DATE '2026-06-01'
-- GROUP BY tier
-- ORDER BY q2_spend DESC;
