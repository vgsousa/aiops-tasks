## 🎯 Frameworks de Engenharia de Prompt

Cada exercício demonstra um dos **5 frameworks de prompt engineering** aplicados a problemas reais de operação:

### 1. **RTF** — Role, Task, Format
**Uso:** Problemas de contexto e saída bem-definida  
**Princípio:** Define o papel do modelo, a tarefa específica e o formato esperado  
**Exemplo:** `01 - Dockerfile/` — "Você é um SRE especialista em containers → crie um Dockerfile production-ready → formato: YAML com comentários explicativos"

### 2. **TAG** — Task, Action, Goal
**Uso:** Automação e fluxos de processo  
**Princípio:** Estrutura a tarefa em ações concretas com objetivo final claro  
**Exemplo:** `02 - Script de Backup/` — Tarefa: backup automático → Ações: dump, compressão, S3, retention → Objetivo: zero downtime, zero data loss

### 3. **BAB** — Before, After, Bridge
**Uso:** Diagnóstico de incidentes e decisões binarias  
**Princípio:** Contrasta estado anterior vs. atual, define ponte (decisão) necessária  
**Exemplo:** `08 - Postmortem Tecnico/` — Before: deploy v2.47.0 estável → After: latência 1928% acima → Bridge: rollback vs. escalação?

### 4. **RISE** — Role, Input, Steps, Expectation
**Uso:** Análise metodológica com restrições de tempo  
**Princípio:** Impõe sequência de análise (timeline → impactos → root cause → opções → decisão)  
**Exemplo:** `08 - Postmortem Tecnico/` — SRE Sênior → dados brutos do incidente → 6 etapas estruturadas → postmortem em 20 minutos

### 5. **CARE** — Context, Action, Result, Example
**Uso:** Padrões reutilizáveis com referências  
**Princípio:** Fornece contexto, descreve ação, valida resultado, exemplifica  
**Exemplo:** `06 - Modulo Terraform/` — Contexto: módulo S3 reutilizável → Ação: encryption, versioning, lifecycle → Resultado: IaC production → Exemplo: 2 cenários de uso


## 📚 Exercícios por Competência

### **Containerização & Security**
- **01 - Dockerfile** `[RTF]`
  - Imagem slim, non-root user (appuser), multi-stage awareness
  - COPY seletivo (exclui testes), EXPOSE, CMD
  - Demonstra: least privilege, layer optimization, supply-chain security

### **Bash & Automação**
- **02 - Script de Backup** `[TAG]`
  - pg_dump → gzip → S3 cp, com retry logic
  - Retenção: 30 dias via `aws s3api list-objects-v2` + LastModified comparison
  - Logging com timestamp, error handling (set -euo pipefail)
  - Demonstra: operações críticas, observabilidade, idempotência

### **Cloud Economics**
- **03 - Relatorio FinOps** `[RTF]`
  - Análise de 8 oportunidades de redução de custo
  - EC2 on-demand ($2.7k/mês), CloudWatch Logs ($1.2k), RDS, Data Transfer
  - Priorização: ROI vs. risk, impacto operacional
  - Demonstra: pensamento financeiro, trade-offs técnico-comerciais

### **SQL & Analytics**
- **04 - Relatorio Transactions** `[TAG]`
  - DATE_TRUNC, GROUP BY com múltiplas dimensões
  - Consolidação de 6 meses com TIMESTAMPTZ, CURRENT_DATE - INTERVAL
  - Demonstra: análise temporal, dimensionamento de dados

### **Kubernetes & Orchestration**
- **05 - Modernizacao Deployment** `[TAG]`
  - Manifest completo: Secret, Deployment (replicas=3), Service, HPA, PDB
  - securityContext (runAsNonRoot, uid=1000), probes (readiness/liveness)
  - Resource limits (256Mi/512Mi RAM, 250m/500m CPU), rolling update
  - Anti-affinity, disruption budgets
  - Demonstra: high-availability, compliance, cost control

### **Infrastructure as Code**
- **06 - Modulo Terraform** `[CARE]`
  - Módulo S3 reutilizável com variáveis (name, environment, owner, cost_center)
  - Encryption (AES256), versioning, public_access_block, lifecycle rules
  - Naming convention corporativa (hvt-prefix)
  - 2 exemplos: basic e with-lifecycle
  - Demonstra: modularidade, governança, escalabilidade

### **Resposta a Incidentes**
- **07 - Runbook de Alertas** `[BAB]`
  - 7 passos: estado do pod → análise de métricas → correlação com deploy → diagnóstico (leak vs. underfitting)
  - 3 opções de mitigação com critérios de escalação
  - Checklist pós-incidente (48h de monitoramento)
  - Demonstra: metodologia SRE, confiabilidade, comunicação

### **Postmortem & Root Cause Analysis**
- **08 - Postmortem Tecnico** `[BAB + RISE]`
  - **Versão BAB:** Deploy v2.48.0 → pool de conexões exhausto (240/250 RDS, max pool 20, 147 waiting) → circuit breaker OPEN (87%)
  - **Versão RISE:** Timeline → impactos → 4 hipóteses (timeout 5s→2s é culpado ★★★★★) → análise comparativa (rollback > scaling)
  - Evidências: p99 latency 420ms → 8100ms (1928%), latência exponencial vs. linear em volume
  - Recomendação: ROLLBACK, não escalação emergencial
  - Demonstra: diagnóstico em tempo real, trade-off analysis, decisão sob pressão



## 🎓 Contexto Acadêmico

Programa: **Especialização em AIOps e IA na Engenharia de Cloud**

**Objetivo:** Demonstrar que estrutura de prompt (RTF, TAG, BAB, RISE, CARE) é tão importante quanto o modelo usado. Um prompt bem-estruturado com Claude Haiku 4.5 bate um prompt genérico com Claude Opus 4.7.

## 📊 Resumo de Impacto

| Exercício | Contexto | Resultado | Impacto SRE |
|-----------|----------|-----------|-----------|
| Dockerfile | Container security | Non-root, slim, compliance | Reduz surface de ataque |
| Backup Script | Data durability | pg_dump + S3 + retention | RTO/RPO garantidos |
| FinOps | Custo | $6.3k/mês savings (15% redução) | CAPEX/OPEX otimizado |
| SQL | Analytics | 6 meses de transações consolidadas | Observabilidade financeira |
| Kubernetes | HA & resilience | 3 replicas, HPA, PDB, probes | 99.95% uptime |
| Terraform | Governança | Módulo reutilizável, hvt- prefix | Escalabilidade de infra |
| Runbook | Resposta | 7 passos, 3 opções, escalação | MTTR < 15 min |
| Postmortem | RCA | Pool leak → Rollback recomendado | Evita recorrência |
