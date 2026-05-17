# Response TAG — Análise Comparativa de Metodologias de Prompt Engineering

**Prompt Executado:** prompt_tag.txt  
**Modelo:** claude-haiku-4-5  
**Output:** postmortem-chronos-tag.md  
**Data:** 2026-05-17  

---

## Análise Comparativa das 3 Metodologias de Prompt Engineering

### BAB (Before-After-Bridge)
- **Ganhos:** 
  - Flexibilidade máxima; o modelo explora alternativas que o analista pode ignorar
  - Estrutura narrativa natural (problema → impacto → solução)
  - Excelente para discovery quando a causa raiz é ambígua
  
- **Perdas:** 
  - Falta de rigidez pode levar a recomendações menos acionáveis
  - Sem guidance estruturada, qualidade varia com contexto do prompt
  - Menos determinístico para reprodução
  
- **Caso de uso ideal:** Exploração aberta, investigação inicial, brainstorm de alternativas

- **Resultado neste case:** BAB foi mais completo quando steps foram deixados vagos, pois o modelo teve liberdade para preencher lacunas e explorar múltiplas causas possíveis

---

### RISE (Role-Input-Steps-Expected)
- **Ganhos:** 
  - Estrutura robusta com steps explícitos
  - Clareza de expectativa do começo ao fim
  - Reproduzibilidade alta se steps estão bem-definidos
  
- **Perdas:** 
  - Qualidade depende criticamente de steps bem-definidos
  - Se steps são vagos, output fica genérico e superficial
  - Menos adequado para descoberta de novas abordagens fora dos steps
  
- **Caso de uso ideal:** Execução de procedimentos operacionais bem-conhecidos com steps claros (runbooks, deploys, procedimentos passo-a-passo)

- **Resultado neste case:** RISE seria superior se steps fossem específicos e concretos, mas com steps vagos (conforme testado), o output ficou aquém do BAB em completude

---

### TAG (Temporal-Analytical-Goal-oriented) — ABORDAGEM NOVA
- **Ganhos:** 
  - Rigor temporal e quantificável (correlações de tempo, cálculos de impacto, delays específicos)
  - Estrutura analytical detalhada de causa-efeito em fases sequenciais
  - Goal-oriented com timeline sincronizada à decisão (20 min para Doc Brown)
  - Rastreabilidade máxima de conclusões (quais evidências de log levaram a qual insight)
  - Altamente acionável: timeline explícita com SLA por ação (0–2 min, 2–4 min, etc.)
  - Excelente para auditoria pós-facto e escalação a stakeholders
  
- **Perdas:** 
  - Menos exploração de alternativas fora do escopo/objetivo definido
  - Requer análise quantificável (nem sempre disponível em todos os incidentes)
  - Estrutura mais rígida pode perder nuances qualitativas em cenários ambíguos
  - Menos apropriado para investigação aberta / discovery
  
- **Caso de uso ideal:** 
  - Incidentes ativos com prazo de decisão
  - Postmortems com necessidade de escalação
  - Recomendações executivas sob pressão de tempo
  - Auditoria e compliance
  
- **Resultado neste case:** TAG entregou postmortem mais acionável e imediato:
  - Correlação temporal explícita (18h 48min entre deploy e degradação)
  - Cálculos quantificáveis (12 pods × 20 pool = 240 conexões = 96% limite RDS)
  - Mecanismo de falha em 5 fases com evidências diretas dos logs
  - Timeline executável em 0–20 min com SLA por ação
  - Recomendação concreta: **ROLLBACK IMEDIATO** vs scaling (evitou decisão perdida em análise)

---

## Comparação Dimensional

| Dimensão | BAB | RISE | TAG | Vencedor |
|---|---|---|---|---|
| **Exploração de alternativas** | 🔴 Alto (potencialmente excessivo) | 🟡 Médio | 🟢 Focado em goal | RISE/TAG |
| **Rigor temporal** | 🟡 Mencionado genericamente | 🟡 Mencionado genericamente | 🔴 **Detalhado** (18h 48min, correlações exatas) | TAG |
| **Quantificação de impacto** | 🟡 Presente | 🟡 Presente | 🔴 **Extensiva** (pool, lag, CPU, connections, %) | TAG |
| **Acionabilidade** | 🟡 Requer interpretação extra | 🟢 Se steps são claros | 🔴 **Timeline + SLA** por ação | TAG |
| **Reproduzibilidade** | 🟡 Média (depende do contexto) | 🔴 **Muito alta** (se steps são claros) | 🔴 **Muito alta** (timeline e métricas explícitas) | RISE/TAG |
| **Adequação a incidente ativo** | 🟡 Razoável (pode explorar demais) | 🟡 Razoável | 🔴 **Excelente** (tempo + decisão clara) | TAG |
| **Confiança do stakeholder** | 🟡 Pode parecer exploratório | 🟡 Depende dos steps | 🔴 **Alto** (evidências quantificáveis) | TAG |
| **Descoberta de causa raiz** | 🔴 **Alto** (explora múltiplas causas) | 🟡 Dependente de steps | 🟡 Focado na causa provável | BAB |

---

## Síntese por Contexto de Uso

### Para Incidentes Ativos → **TAG É SUPERIOR**
- Pressão de tempo: 20 min para decisão executiva
- Necessidade de rastreabilidade: quais logs/métricas levaram a qual insight
- Risco de escalação: stakeholders precisam de confiança na análise
- Resultado: postmortem-chronos-tag.md entregou recomendação clara (ROLLBACK) com justificativa quantificável

### Para Descoberta e Exploração → **BAB É SUPERIOR**
- Ambiguidade de causa raiz
- Necessidade de explorar múltiplas hypotheses
- Contexto: pesquisa, design decisions, brainstorm
- Resultado: BAB foi mais completo quando steps foram vagos

### Para Execução de Procedimentos Operacionais → **RISE É SUPERIOR**
- Steps bem-definidos e conhecidos
- Necessidade de reproduzibilidade exata
- Contexto: runbooks, deployments com procedimento fixo, migrações
- Resultado: RISE com steps claros seria determinístico e altamente reproduzível

---

## Conclusão

**Para este case específico (postmortem técnico de incidente ativo):**
- BAB entregou exploração aberta; adequado para investigação
- RISE entregaria rigidez; adequado se steps fossem claros
- **TAG entregou o resultado ideal: decisão acionável em 20 min com rastreabilidade total**

A abordagem **TAG provou ser a metodologia mais apropriada** para incidentes que demandam:
1. Decisão rápida e irrevogável (rollback vs scaling)
2. Justificativa quantificável a stakeholders (Doc Brown)
3. Rastreamento de evidência (quais logs levaram à conclusão)
4. Timeline de execução sincronizada ao objetivo

**Recomendação para cenários futuros:**
- **BAB** → Discovery, investigação inicial, exploração de causa raiz quando ambígua
- **RISE** → Procedimentos operacionais com steps bem-definidos (runbooks, CI/CD)
- **TAG** → Postmortems, decisões executivas, incidentes ativos, auditoria

A consolidação destes três enfoques (BAB para exploração, RISE para procedimento, TAG para decisão executiva) oferece cobertura completa de cenários de engenharia de prompt para contextos SRE/operacional.
