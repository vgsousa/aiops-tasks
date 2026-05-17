-- Consolidação de Transações - Últimos 6 Meses
-- Agrupa transações completadas por mês e categoria
-- Valores em centavos convertidos para reais com 2 casas decimais

SELECT
  TO_CHAR(DATE_TRUNC('month', t.created_at), 'YYYY-MM') AS mes,
  t.category,
  COUNT(*) AS quantidade_transacoes,
  ROUND(SUM(t.amount_cents) / 100.0, 2) AS volume_reais
FROM transactions t
WHERE t.status = 'completed'
  AND t.created_at >= '2026-04-24'::date - INTERVAL '6 months'
  AND t.category IN ('subscription', 'one_time', 'refund', 'credit_adjustment')
GROUP BY DATE_TRUNC('month', t.created_at), t.category
ORDER BY DATE_TRUNC('month', t.created_at) ASC, t.category ASC;
