Prompt:
```
# TASK
Criar um SQL para consolidar os numeros de transações, o Ledger (PostgreSQL) tem o histórico completo, e as duas tabelas relevantes estão abaixo.
CREATE TABLE transactions (
  id              BIGSERIAL PRIMARY KEY,
  customer_id     BIGINT NOT NULL REFERENCES customers(id),
  category        VARCHAR(32) NOT NULL,
  amount_cents    BIGINT NOT NULL,
  status          VARCHAR(16) NOT NULL,
  payment_method  VARCHAR(16),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  completed_at    TIMESTAMPTZ
);

CREATE INDEX idx_transactions_created_at ON transactions(created_at);
CREATE INDEX idx_transactions_status ON transactions(status);
CREATE INDEX idx_transactions_category ON transactions(category);
---
CREATE TABLE customers (
  id          BIGSERIAL PRIMARY KEY,
  segment     VARCHAR(16) NOT NULL,
  country     CHAR(2) NOT NULL,
  signup_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

Categorias em produção hoje: subscription, one_time, refund e credit_adjustment.

# ACTION
Só entra no relatório quem tem status = 'completed'.
O campo amount_cents está em centavos de real e precisa aparecer na saída em reais com 2 casas decimais.
Ordenação final: mês crescente, depois categoria crescente.
O recorte é dos últimos 6 meses corridos a partir de hoje (2026-04-24), agrupado por mês (no formato YYYY-MM) e por categoria, trazendo duas métricas por linha: quantidade de transações e volume total em reais.

# GOAL
Criar query em SQL do crescimento de transações nos últimos 6 meses por categoria
Para documentação, prencher um arquivo 'response.md' com esse prompt, com o modelo usado e com o resultado (arquivos)
```

Modelo: claude-haiku-4-5-20251001 - Modelo escolhido pela tarefa bem definida com todas as informações necessárias e critério objetivo.

Output: consolidacao_transacoes.sql

Justificativa:
A estrutura TAG provou-se extremamente eficiente para esta tarefa SQL. Essa clareza permitiu gerar uma query SQL precisa de primeira, sem necessidade de iterações. A separação entre o quê, comoe objetivo é ótimo para queries SQL, onde ambiguidades resulta em saídas problematicas.
