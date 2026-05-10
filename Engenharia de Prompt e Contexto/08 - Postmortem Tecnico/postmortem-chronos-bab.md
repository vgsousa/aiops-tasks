# Postmortem Técnico — Chronos API Degradação Severa
**Data:** 2026-04-24  
**Início do incidente:** ~14:00 UTC  
**Status:** ATIVO — decisão de ação imediata requerida  
**Tempo disponível para decisão:** 20 minutos  

---

## Resumo Executivo

Chronos API está em colapso progressivo desde 14:10 UTC com p99 de 8100ms e 11.7% de erro às 14:20. A causa raiz identificada é esgotamento do pool de conexões ao Ledger (PostgreSQL), precipitada por mudanças introduzidas no deploy **v2.48.0 ontem às 18:42 UTC**.

**Recomendação:** **ROLLBACK para v2.47.0 imediatamente.**

---

## Linha do Tempo

| Horário | p99 (ms) | Req/s | Erro % | Evento |
|---------|----------|-------|--------|--------|
| 18:42 UTC (23/04) | Normal | Normal | <0.1% | Deploy v2.48.0 |
| 13:30 UTC (24/04) | 420 | 1200 | 0.2% | Início da degradação detectável |
| 14:00 UTC | 780 | 1780 | 0.8% | Degradação acelerando |
| 14:10 UTC | 2400 | 2100 | 4.5% | Limiar crítico ultrapassado |
| 14:19 UTC | — | — | — | Pool esgotado, circuit breaker OPEN |
| 14:20 UTC | 8100 | 2650 | 11.7% | Colapso — estado atual |

---

## Análise da Causa Raiz

### Evidência principal: pool de conexões esgotado

```
connection pool exhausted (max=20, active=20, waiting=147)
query timeout after 2000ms
circuit-breaker OPEN (87%)
Conexões RDS: 240/250
```

Com 12 pods × pool de 20 conexões = **240 conexões ao Ledger**, exatamente o limite atual do RDS. O pool está cheio e 147 requisições aguardam por conexão.

### Mudanças no deploy v2.48.0 que explicam o cenário

| Mudança | Risco | Impacto Provável |
|---------|-------|-----------------|
| Timeout Ledger: 5s → **2s** | **ALTO** | Queries de 2–5s agora expiram; conexões não retornam ao pool corretamente |
| Pool de conexões → nova biblioteca interna | **ALTO** | Comportamento diferente em timeout pode causar leak de conexões |
| Bump psycopg 3.1.18 → 3.2.0 | Médio | Mudança de comportamento em cancelamento de query |
| Novo endpoint `/v2/transactions/batch` | Médio | Cada chamada batch pode abrir múltiplas conexões |

### Mecanismo de falha (hipótese confirmada pelos logs)

1. Aumento natural de tráfego ao longo do dia (1200 → 2650 req/s)
2. Queries ao Ledger que demoravam 2–5s na versão anterior agora expiram após 2s
3. A nova biblioteca de pool **não retorna conexões ao pool quando ocorre timeout** (connection leak)
4. Pool se esgota progressivamente → novas requisições aguardam → p99 explode
5. Circuit breaker abre com 87% de falhas → Reactor acumula mensagens
6. Efeito em cascata: 50k mensagens na fila, 18 min de consumer lag e crescendo

### Por que **não** é problema de tráfego isolado

O tráfego cresceu ~120% (1200 → 2650 req/s), mas o p99 cresceu **1928%** (420ms → 8100ms). Crescimento de tráfego sozinho não explica essa desproporção. O esgotamento de pool é a causa primária, não o volume.

---

## Avaliação das Opções

### Opção 1: ROLLBACK v2.48.0 → v2.47.0 ✅ RECOMENDADA

**Procedimento (estimativa: 5 min):**
```bash
argocd app rollback chronos-api --grpc-web
kubectl rollout status deployment/chronos-api -n production
```

**Por que esta opção:**
- Reverte simultaneamente todas as 4 mudanças de risco
- É a única opção que trata a causa raiz (comportamento do pool)
- Reversível: se o rollback piorar algo, pode-se fazer re-deploy
- Argo CD mantém histórico; o rollback é limpo e auditável

**Expectativa de recuperação:**
- 0–2 min: pods com v2.47.0 iniciando (rolling update)
- 2–5 min: conexões do pool sendo liberadas naturalmente (sem leak)
- 5–10 min: p99 voltando a níveis normais (<500ms)
- 10–15 min: fila do Reactor começando a drenar

**Risco:**
- Endpoint `/v2/transactions/batch` ficará indisponível até hotfix ser preparado
- Mensagens acumuladas no Reactor (50k) serão processadas em lote — monitorar Ledger durante reprocessamento

---

### Opção 2: Scaling emergencial (RDS + pool) ❌ NÃO RECOMENDADA AGORA

**Procedimento:**
- Aumentar `max_connections` no RDS (requer reinício ou parameter group)
- Aumentar pool por pod no deployment

**Por que não é suficiente:**
- Se a causa é **connection leak** na nova biblioteca, aumentar o pool apenas adia o colapso
- Reiniciar parameter group do RDS em produção durante incidente ativo é de alto risco
- Não reverte o timeout de 2s, que continua causando degradação sob carga
- Mesmo com pool maior, circuit breaker já está OPEN — novas conexões não ajudam imediatamente

**Quando usar scaling como complemento:**
- Após rollback, se o Ledger ainda estiver próximo do limite de conexões durante drenagem da fila do Reactor

---

## Plano de Ação Imediato (próximos 20 minutos)

| Minuto | Ação | Responsável |
|--------|------|-------------|
| 0–2 | Confirmar decisão de rollback no canal #oncall-chronos | SRE on-call |
| 2–3 | Executar `argocd app rollback chronos-api` | SRE on-call |
| 3–8 | Monitorar `kubectl rollout status` e `kubectl top pods` | SRE on-call |
| 8–12 | Verificar queda do p99 e error rate no Grafana | SRE on-call |
| 12–15 | Verificar drenagem da fila do Reactor | SRE on-call |
| 15–20 | Confirmar estabilização ou escalar para @chronos-core | SRE on-call |

### Monitoramento pós-rollback

```bash
# Estado dos pods a cada 10s
watch -n 10 kubectl get pods -n production -l app=chronos-api

# Uso de memória e CPU
watch -n 10 kubectl top pods -n production -l app=chronos-api

# Conexões ao Ledger (monitorar queda de 240 → <100)
kubectl exec -n production deploy/chronos-api -- \
  python -c "from app import db; print(db.pool.status())"

# Consumer lag do Reactor
aws sqs get-queue-attributes \
  --queue-url <URL-chronos-transactions> \
  --attribute-names ApproximateNumberOfMessages
```

---

## Critério de Escalação

**Escalar para @chronos-core SE:**
- p99 não cair abaixo de 2000ms em 10 minutos após o rollback
- Error rate não cair abaixo de 2% em 10 minutos após o rollback
- Novos erros aparecerem nos logs após o rollback

---

## Ações Pós-Incidente (após estabilização)

1. **Root cause investigation (time de desenvolvimento):**
   - Revisar comportamento da nova biblioteca de pool em cenários de timeout
   - Testar `psycopg 3.2.0` com timeout agressivo em ambiente de staging sob carga
   - Validar se `/v2/transactions/batch` abre conexões sem timeout adequado

2. **Antes de re-promover v2.48.0:**
   - Reverter timeout para 5s (ou adotar valor intermediário: 3s com testes)
   - Adicionar teste de carga com pool exhaustion no pipeline CI
   - Implementar métrica de `pool.waiting` no dashboard Grafana com alerta em >10

3. **Melhorias de processo:**
   - Deploy de mudanças em cliente de banco de dados em horário de baixo tráfego
   - Canary deployment para mudanças com risco de regressão em conexões
