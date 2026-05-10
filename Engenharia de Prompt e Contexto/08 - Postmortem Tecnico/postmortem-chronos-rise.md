# Postmortem Técnico — Chronos API Degradação Severa (RISE)
**Data:** 2026-04-24 | **Status:** ATIVO | **Janela de decisão:** 20 minutos

---

## Step 1 — Linha do Tempo das Evidências

| Horário (UTC) | Evento | Fonte |
|---------------|--------|-------|
| 2026-04-23 18:42 | Deploy v2.47.0 → v2.48.0 via Argo CD | Argo CD |
| 2026-04-24 13:30 | p99=420ms, err=0.2% — degradação inicial detectável | Beacon |
| 2026-04-24 13:45 | p99=510ms, req/s +21% (1200→1450) | Beacon |
| 2026-04-24 14:00 | p99=780ms, err=0.8% — tendência de alta não linear | Beacon |
| 2026-04-24 14:10 | p99=2400ms, err=4.5% — limiar crítico ultrapassado | Beacon |
| 2026-04-24 14:15 | p99=5200ms, err=8.2% — tráfego crescendo (2400 req/s) | Beacon |
| 2026-04-24 14:19 | Pool esgotado (max=20, waiting=147), circuit breaker OPEN 87% | Logs pod |
| 2026-04-24 14:20 | p99=8100ms, err=11.7%, 240/250 conexões RDS, 50k msgs na fila | Beacon / SQS |

**Observação crítica:** Entre 13:30 e 14:20 (50 min), o tráfego cresceu **~120%** (1200→2650 req/s), mas o p99 cresceu **~1928%** (420ms→8100ms). Crescimento linear de tráfego não explica degradação exponencial — há um fator amplificador interno.

---

## Step 2 — Possíveis Impactos do Deploy v2.48.0

| Mudança no changelog | Impacto potencial |
|---------------------|-------------------|
| **Novo endpoint `/v2/transactions/batch`** | Cada chamada batch pode abrir múltiplas conexões ao Ledger simultaneamente, aumentando pressão sobre o pool |
| **Pool de conexões → nova biblioteca interna** | Mudança arquitetural de alto risco: comportamento em timeouts, retry e devolução de conexões pode diferir da implementação anterior |
| **psycopg 3.1.18 → 3.2.0** | Mudança de minor version: possível alteração em cancelamento de query ou gestão de conexões em cenários de timeout |
| **Timeout Ledger: 5s → 2s** | Queries que completavam em 2–5s na versão anterior agora expiram; se a conexão não for devolvida ao pool após o timeout, há resource leak progressivo |

**Mudanças de maior risco combinado:** timeout + nova biblioteca de pool. Ambas afetam o ciclo de vida das conexões ao Ledger de forma simultânea.

---

## Step 3 — Possíveis Causas Raiz

### Hipótese A (principal): Connection leak no pool após timeout ★★★★★
Timeout reduzido de 5s para 2s faz com que queries longas expirem. A nova biblioteca de pool não devolve a conexão ao pool após o timeout (`context deadline exceeded`), causando leak progressivo. Com tráfego crescente, o pool esgota mais rápido — o que explica a degradação acelerada e não linear.

**Evidência direta:** `connection pool exhausted (max=20, active=20, waiting=147)` + `query timeout after 2000ms` nos logs.

### Hipótese B: Endpoint batch abre múltiplas conexões por requisição ★★★☆☆
O novo endpoint `/v2/transactions/batch` pode abrir N conexões em paralelo por chamada, multiplicando a pressão sobre o pool. O log confirma falha neste endpoint: `POST /v2/transactions/batch failed`.

**Evidência:** Circuit breaker abriu com 87% de falha — alto, sugerindo que a maioria das requisições (incluindo batch) estava falhando.

### Hipótese C: Carga no Ledger por queries mais lentas pós-psycopg ★★☆☆☆
psycopg 3.2.0 pode ter mudado o comportamento de execução de queries, tornando-as mais lentas e mantendo conexões abertas por mais tempo.

**Menos provável como causa isolada**, mas pode ser fator agravante.

### Hipótese D: Tráfego legítimo apenas (sem relação com deploy) ★☆☆☆☆
Descartada: a desproporção entre crescimento de tráfego (~120%) e crescimento de p99 (~1928%) rejeita tráfego como causa única.

---

## Step 4 — Análise das Opções

### Opção 1: Rollback para v2.47.0

**O que resolve:** Reverte todas as mudanças de risco simultaneamente — timeout volta a 5s, biblioteca de pool anterior (comportamento conhecido), psycopg 3.1.18, endpoint batch removido.

**O que não resolve:** Mensagens acumuladas no Reactor (50k) continuarão aguardando processamento após o rollback — monitorar reprocessamento.

**Velocidade de recuperação:** 5–10 minutos após início do rollback.

**Risco da ação:** Baixo. Argo CD mantém histórico; operação é rastreável e revertível.

**Endpoint `/batch` offline:** Sim, até hotfix ser preparado com correções adequadas.

---

### Opção 2: Scaling emergencial (RDS max_connections + pool)

**O que resolve:** Aumenta a capacidade máxima de conexões, dando mais headroom ao pool.

**O que não resolve:** Se a causa raiz é **leak de conexões** (Hipótese A), aumentar o pool apenas adia o colapso — o pool maior também se esgotará, só levará mais tempo. Circuit breaker já está OPEN; novas conexões não desbloqueiam o tráfego imediatamente.

**Velocidade de recuperação:** 15–25 minutos (parameter group do RDS pode exigir reinício ou apply com downtime).

**Risco da ação:** Alto. Reiniciar parameter group do RDS durante incidente ativo adiciona risco de indisponibilidade do banco.

**Eficácia:** Incerta se a causa raiz for leak; apenas eficaz se for underfitting puro (Hipótese D, já descartada).

---

## Step 5 — Avaliação e Proposta de Solução

**Decisão recomendada: ROLLBACK (Opção 1)**

| Critério | Rollback | Scaling |
|----------|----------|---------|
| Trata a causa raiz provável | ✅ Sim | ❌ Não |
| Velocidade de recuperação | ✅ 5–10 min | ❌ 15–25 min |
| Risco da operação | ✅ Baixo | ❌ Alto (RDS restart) |
| Reversível | ✅ Sim | ⚠️ Parcialmente |
| Resolve circuit breaker | ✅ Sim (pool drena) | ❌ Não diretamente |

**Scaling como complemento pós-rollback:** Se após o rollback o Reactor estiver gerando pico de reprocessamento e o Ledger se aproximar novamente de 250 conexões, aumentar o pool de conexões pontualmente via `kubectl set resources` (sem mexer no RDS).

---

## Step 6 — Plano de Ação Imediato

### Execução (próximos 20 minutos)

**[T+0] Confirmar decisão no canal #oncall-chronos**
```
@team Iniciando rollback v2.48.0 → v2.47.0 agora.
Causa identificada: connection pool exhausted por provável leak após timeout 2s.
Acompanhar no Grafana.
```

**[T+2] Executar rollback via Argo CD**
```bash
argocd app rollback chronos-api --grpc-web
```

**[T+3] Monitorar rollout**
```bash
kubectl rollout status deployment/chronos-api -n production
kubectl get pods -n production -l app=chronos-api -w
```

**[T+5] Verificar liberação do pool e queda do error rate**
```bash
# Logs ao vivo — aguardar ausência de "pool exhausted"
kubectl logs -n production -l app=chronos-api --since=2m -f | grep -E "pool|timeout|circuit"

# Conexões ao Ledger (esperar queda de 240 → <150)
watch -n 5 kubectl exec -n production deploy/chronos-api -- \
  python -c "import os; print(os.environ.get('POOL_STATS', 'n/a'))"
```

**[T+10] Validar métricas no Grafana**
- p99 < 1000ms → recuperação em progresso
- Error rate < 1% → estabilizando
- Circuit breaker CLOSED → pool operacional

**[T+12] Monitorar fila do Reactor**
```bash
aws sqs get-queue-attributes \
  --queue-url <URL-chronos-transactions> \
  --attribute-names ApproximateNumberOfMessages,ApproximateNumberOfMessagesNotVisible
```
Esperar queda gradual do consumer lag (18 min → decrescendo).

**[T+15] Decisão de escalação**
- Se p99 > 2000ms após 15 min do rollback → escalar `@chronos-core`
- Se erro persiste mas pool liberou → investigar Reactor isoladamente

**[T+20] Registro no canal #oncall-chronos**
```
RESOLUÇÃO: Rollback v2.48.0 → v2.47.0 executado.
p99: Xms | Error rate: X% | Pool: estável
Fila Reactor: X mensagens (lag: X min)
Issue aberta: hvt/chronos-api#<N> — investigar timeout 2s + nova lib pool
```

### Ações pós-estabilização

1. Abrir issue em `hvt/chronos-api` com todos os dados deste postmortem
2. Testar nova biblioteca de pool em staging com timeout agressivo (2s) e carga simulada
3. Revisar PR do v2.48.0: endpoint batch deve usar connection timeout separado
4. Adicionar métrica `pool.waiting` no dashboard com alerta em >5
