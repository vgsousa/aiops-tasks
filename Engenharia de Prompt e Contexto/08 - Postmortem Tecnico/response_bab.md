Prompt:
```
# BEFORE
Ontem foi feito um deploy com os seguintes parametros (ontem, 18:42 UTC):
Deploy chronos-api: v2.47.0 -> v2.48.0
Argo CD sync: 2026-04-23 18:42:11 UTC
Changelog:
- Adicionado endpoint POST /v2/transactions/batch
- Refatorado cliente do Ledger (pool de conexoes movido para nova biblioteca interna)
- Bump de psycopg 3.1.18 -> 3.2.0
- Reduzido timeout do Ledger de 5s para 2s

# AFTER
Hoje estamos com um problema generalizado as métricas do Beacon nos últimos 30 minutos:
[...métricas de degradação e logs de erro...]

# BRIDGE
Precisa de um postmortem técnico em 20 minutos para decidir entre rollback do deploy v2.48.0
(que subiu ontem) e scaling emergencial (aumento de limits do RDS e do pool de conexões)
```

Modelo: claude-sonnet-4-6

Output: postmortem-chronos-bab.md

Justificativa:
BAB é eficiente pois o BEFORE mostra para o modelo no estado antes do incidente com evidências concretas (changelog do deploy), o AFTER fornece os sintomas do problema (métricas, logs), e o BRIDGE define o que precisa forçando uma análise direta, sem contexto desnecessário.
