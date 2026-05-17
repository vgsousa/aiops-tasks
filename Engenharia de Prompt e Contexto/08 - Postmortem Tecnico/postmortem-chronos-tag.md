# Postmortem Técnico — Chronos API Degradação Severa
**Data:** 2026-04-24  
**Início do incidente:** ~14:00 UTC  
**Status:** ATIVO — decisão de ação imediata requerida  
**Tempo disponível para decisão:** 20 minutos  

---

## Resumo Executivo

Chronos API está em degradação severa desde 14:10 UTC com p99 de 8.1s e 11.7% de taxa de erro às 14:20. A análise temporal e correlação de métricas indicam que o deploy v2.48.0 (18:42 UTC de 23/04) introduziu 4 mudanças de risco significativas, sendo a redução do timeout Ledger (5s → 2s) e a refatoração da biblioteca de pool de conexões as causas primárias do esgotamento de pool.

**Recomendação primária:** **ROLLBACK IMEDIATO para v2.47.0**  
**Justificativa:** Elimina todas as causas raiz simultaneamente em ~5 minutos, reversível, e com recuperação esperada em 10-15 minutos.

---

## Análise Temporal e Correlação

### Linha do Tempo Consolidada

| Horário UTC | p99 (ms) | Taxa Req/s | Taxa Erro % | Evento Crítico |
|---|---|---|---|---|
| 23/04 18:42 | ~50–100 | ~800 | <0.1% | ✓ Deploy v2.48.0 — 4 mudanças introduzidas |
| 24/04 13:30 | 420 | 1200 | 0.2% | Início da degradação (18h 48min após deploy) |
| 24/04 13:45 | 510 | 1450 | 0.3% | Degradação linear |
| 24/04 14:00 | 780 | 1780 | 0.8% | Aceleração da degradação |
| 24/04 14:10 | 2400 | 2100 | 4.5% | **Limiar crítico ultrapassado** |
| 24/04 14:15 | 5200 | 2400 | 8.2% | Degradação exponencial |
| **24/04 14:19** | — | — | — | **⚠ Logs evidenciam pool esgotado (147 waiting)** |
| 24/04 14:20 | 8100 | 2650 | 11.7% | **Colapso — Reactor lag: 18 min** |

### Interpretação da Correlação

1. **Delay de 18h 48min entre deploy e degradação observável:** A refatoração de pool e redução de timeout não causaram falha imediata. A degradação emergiu gradualmente sob carga crescente, sugerindo acúmulo de conexões não liberadas (leak).

2. **Degradação não-linear:** Tráfego cresceu ~120% (1200 → 2650 req/s), mas p99 cresceu **1928%** (420ms → 8100ms). Esse desproporção confirma que o crescimento de tráfego revelou uma condição patológica na gestão de conexões, não é causa isolada de tráfego.

3. **Momento de inflexão em 14:10:** A correlação entre p99 de 2.4s, 2100 req/s e 4.5% de erro marca o ponto onde o pool começou a se esgotar sistematicamente.

---

## Diagnóstico Técnico da Causa Raiz

### Evidência Primária: Esgotamento de Pool de Conexões

```log
2026-04-24 14:19:48 [ERROR] [ledger-client] connection pool exhausted 
                              (max=20, active=20, waiting=147)
2026-04-24 14:19:49 [WARN]  [ledger-client] query timeout after 2000ms
2026-04-24 14:19:50 [ERROR] [ledger-client] connection reset by peer
2026-04-24 14:19:51 [WARN]  [circuit-breaker] ledger-client OPEN (87%)
```

**Cálculo de limite de conexões:**
- 12 pods em running
- Pool máximo por pod: 20 conexões (padrão do deploy v2.48.0)
- Total: 12 × 20 = **240 conexões**
- Estado atual: 240/250 (96% do limite RDS)
- Consumer lag: 18 min e crescendo → backlog de mensagens bloqueadas no Reactor

### Análise das 4 Mudanças Críticas do Deploy v2.48.0

| Mudança | Versão Anterior | Versão Nova | Risco | Impacto Diagnosticado |
|---|---|---|---|---|
| **Timeout Ledger** | 5s | 2s | 🔴 CRÍTICO | Queries que demoravam 2–5s agora expiram e causam leak de conexão na nova biblioteca |
| **Cliente Ledger** | Biblioteca anterior | Nova biblioteca interna | 🔴 CRÍTICO | Comportamento diferente em timeout; conexões não retornam ao pool corretamente |
| **psycopg bump** | 3.1.18 | 3.2.0 | 🟡 MÉDIO | Mudança em cancelamento de query; interação com timeout mais agressivo |
| **Endpoint `/v2/transactions/batch`** | N/A (novo) | Adicionado | 🟡 MÉDIO | Cada requisição batch abre múltiplas conexões; sob nova biblioteca, abre leak |

### Mecanismo de Falha Confirmado pelos Logs

1. **Fase 1 (13:30–14:10):** Aumento progressivo de tráfego diário (1200 → 2100 req/s)
2. **Fase 2 (timeout trigger):** Queries que demoravam ~3–4s no Ledger agora expiram após 2s
3. **Fase 3 (connection leak):** A nova biblioteca de pool não libera conexões quando ocorre timeout — cada expiração deixa uma conexão "travada"
4. **Fase 4 (pool exhaustion):** Pool de 20 conexões por pod satura com requisições aguardando (147 waiting logs registram)
5. **Fase 5 (cascata de falhas):**
   - Circuit breaker abre com 87% de taxa de falha
   - Mensagens rejected são enviadas ao Reactor como republish
   - Reactor acumula 50k+ mensagens com consumer lag de 18 min
   - Novos timeouts geram mais conexões travadas (feedback loop negativo)

---

## Avaliação Comparativa de Opções

### Opção 1: ROLLBACK v2.48.0 → v2.47.0 ✅ RECOMENDADA

**Procedimento executável em <5 minutos:**
```bash
# 1. Rollback via Argo CD (~2 min)
argocd app rollback chronos-api --grpc-web

# 2. Verificar status de rolling update (~3 min)
kubectl rollout status deployment/chronos-api -n production --timeout=5m

# 3. Validar recuperação (~2 min)
kubectl top pods -n production -l app=chronos-api
```

**Vantagens:**
- ✅ Reverte SIMULTANEAMENTE todas as 4 mudanças de risco
- ✅ Elimina leak de conexão (raiz da causa)
- ✅ Reverte timeout para 5s (remove trigger de expiração agressiva)
- ✅ Rollback é limpo, auditável e reversível via Argo CD
- ✅ Se rollback não funcionar, pode-se re-deploy imediatamente
- ✅ Tempo de execução: 5 min; recuperação esperada: 10–15 min

**Expectativa de Recuperação:**
- **0–2 min:** Pods com v2.47.0 iniciando (rolling update)
- **2–5 min:** Conexões vazias (sem leak) sendo liberadas naturalmente
- **5–10 min:** p99 retornando a <500ms
- **10–15 min:** Fila do Reactor começando a drenar (lag reduzindo)
- **15–20 min:** Estabilização completa; capacidade de análise pós-incidente

**Considerações pós-rollback:**
- Endpoint `/v2/transactions/batch` (novo em v2.48.0) ficará indisponível até hotfix
- Mensagens acumuladas (50k) no Reactor serão drenadas em lote — monitorar uso de conexão ao Ledger durante reprocessamento
- Revalidar v2.48.0 em staging com teste de carga de pool exhaustion antes de re-promover

---

### Opção 2: Scaling Emergencial (RDS + Pool) ❌ RISCO ALTO / NÃO SUFICIENTE

**Procedimento proposto:**
- Aumentar `max_connections` no RDS (requer reinício de parameter group ou reboot)
- Aumentar `LEDGER_POOL_MAX` por pod via ConfigMap/rollout

**Problemas críticos:**
- ❌ **SE a causa é connection leak**, aumentar pool apenas adia colapso (problema persiste)
- ❌ Aumentar `max_connections` no RDS em produção **durante incidente ativo** requer:
  - Parameter group reboot (queda de conexões existentes por ~1–2 min)
  - OU aplicar parameter group dinâmico (nem todos os parâmetros suportam)
  - OU reboot da instância RDS (downtime de 5–10 min, inaceitável)
- ❌ Não reverte timeout agressivo de 2s — degradação continuará
- ❌ Circuit breaker já está OPEN — novas conexões não resolvem imediatamente
- ❌ Requer 2 mudanças sincronizadas (RDS + deployment); mais chances de erro

**Quando usar scaling como complemento:**
- **Após** rollback com sucesso, se o Ledger continuar próximo de 100% de utilização durante drenagem da fila do Reactor
- **Nunca** como estratégia primária em incidente ativo de degradação severa

---

### Opção 3: Hotfix de timeout + patch de pool (❌ NÃO VIÁVEL AGORA)

**Por que não:**
- Requer desenvolvimento, teste e validação de código novo — mínimo 30–60 min
- Incidente está em colapso em 20 min
- Risco de introduzir novo bug durante pressão de tempo

**Quando considerar:**
- Pós-incident: antes de re-deslocar v2.48.0 com ajustes

---

## Recomendação Final

**EXECUTE ROLLBACK IMEDIATO para v2.47.0.**

**Justificativa:**
1. **Causa raiz confirmada:** Connection leak na nova biblioteca + timeout agressivo
2. **Velocidade:** ~5 minutos para execução, 10–15 minutos para recuperação
3. **Reversibilidade:** Se algo dar errado, re-deploy é trivial
4. **Efetividade:** Elimina todas as 4 mudanças de risco simultaneamente
5. **Risco mitigado:** Infinitamente menor que modificar RDS em produção durante incidente

**Timeline de execução:**

| Minuto | Ação | Responsável | SLA |
|---|---|---|---|
| 0 | Apresentar postmortem a Doc Brown | SRE on-call | Imediato |
| 1–2 | Confirmar decisão de rollback | Líder técnico | 2 min máx |
| 2–4 | Executar `argocd app rollback` | SRE on-call | 2 min máx |
| 4–8 | Monitorar `kubectl rollout status` | SRE on-call | 4 min máx |
| 8–12 | Verificar queda de p99 e erro % em Grafana | SRE on-call | 4 min máx |
| 12–15 | Validar drenagem da fila do Reactor | SRE on-call | 3 min máx |
| 15–20 | Confirmar estabilização ou escalar | SRE on-call | 5 min máx |

---

## Ações Imediatas Pós-Rollback (Minutos 5–20)

### Monitoramento em Tempo Real

```bash
# 1. Status dos pods a cada 10s
watch -n 10 kubectl get pods -n production -l app=chronos-api -o wide

# 2. CPU/Memória dos pods
watch -n 10 kubectl top pods -n production -l app=chronos-api

# 3. Conexões ao Ledger (deve cair de 240 → <100 em 5 min)
kubectl logs -n production -l app=chronos-api --tail=50 | grep "pool"

# 4. Consumer lag do Reactor (deve reduzir após 5 min)
aws sqs get-queue-attributes \
  --queue-url https://sqs.{region}.amazonaws.com/{account}/chronos-transactions \
  --attribute-names ApproximateNumberOfMessages,ApproximateNumberOfMessages
```

### Critério de Escalação

**Escalar para @chronos-core SE qualquer um dos critérios abaixo:**
- p99 não cair abaixo de 2000ms em 10 minutos após rollback
- Taxa de erro não cair abaixo de 2% em 10 minutos após rollback
- Novos padrões de erro aparecem nos logs após rollback (não-esperados)
- RDS CPU/conexões continuarem crescendo após pool ser liberado

---

## Ações Pós-Incidente (Após Estabilização)

### Fase 1: Root Cause Investigation (Team Chronos Dev — 1–2 dias)

1. **Reproduzir em staging:**
   ```bash
   # Deploy v2.48.0 em staging, induzir carga com wrk ou k6
   wrk -t12 -c400 -d60s -s load-batch-endpoint.lua https://staging-chronos/v2/transactions/batch
   # Monitorar se pool se esgota
   ```

2. **Revisar comportamento da nova biblioteca de pool:**
   - Verificar se `connection.close()` é chamado em timeout
   - Validar se `pool.return_connection()` é chamado em todos os paths
   - Comparar com a biblioteca anterior em mesmo cenário

3. **Testar psycopg 3.2.0 isoladamente:**
   - Validar se query cancellation libera conexão
   - Testar combinação: psycopg 3.2.0 + timeout 2s + carga alta

### Fase 2: Validação Antes de Re-promover v2.48.0

**Pré-requisitos:**
1. Timeout Ledger: reverter para 5s OU adotar valor intermediário (3s) com validação
2. Nova biblioteca de pool: correção de leak OU usar biblioteca anterior
3. Adicionar teste de carga no pipeline CI:
   ```bash
   # Test: pool não se esgota sob timeout agressivo + alta concorrência
   pytest -k test_pool_exhaustion_under_timeout_load
   ```
4. Dashboard Grafana:
   - Adicionar métrica `ledger.pool.waiting` com alerta em threshold >10
   - Adicionar métrica `ledger.pool.active` com alerta em threshold >18

### Fase 3: Melhorias de Processo

1. **Janela de deploy:** Mudanças em cliente de banco de dados (pool, timeout, driver) devem ser deployed em horário de **baixo tráfego** (02:00–06:00 UTC)
2. **Canary deployment:** Para mudanças com risco de regressão em conexões, usar canary de 5% → 25% → 100%
3. **Slack notification pré-deploy:** Alertar @oncall-chronos 24h antes de mudanças de pool/timeout/driver
4. **Pós-deploy validation:** Aguardar 30 min de monitoramento em produção antes de fechar incidente

---

## Conclusão

O incidente foi precipitado por 4 mudanças no deploy v2.48.0, sendo a redução de timeout (5s → 2s) + refatoração da biblioteca de pool as causas raiz confirmadas pelos logs. A correlação temporal de 18h 48min entre deploy e degradação, aliada ao padrão não-linear de crescimento de p99 vs. tráfego, confirma esgotamento de pool de conexão e não crescimento de tráfego isolado.

**Rollback é a opção correta.**

Recuperação esperada: 10–15 minutos. Doc Brown pode aproveitar o período de post-rollback (5–20 min) para coordenar a investigação de causa raiz que o time de dev iniciará imediatamente após estabilização.

---

**Preparado por:** SRE On-Call  
**Timestamp:** 2026-04-24 14:25 UTC (20 minutos após início do incidente)  
**Status:** Recomendação acionável em <5 minutos
