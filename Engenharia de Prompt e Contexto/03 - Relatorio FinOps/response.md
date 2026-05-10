Prompt:
```
# TASK
Criar um relatório para redução no custo cloud AWS sem degradar SLA. Os dados da AWS são (em csv):
servico,categoria,custo_mensal_usd,uso_medio_pct,observacao
EC2 reservada,compute,4200,72,contrato de 1 ano
EC2 on-demand,compute,8200,45,workloads variaveis
EKS,compute,6700,58,3 clusters
RDS PostgreSQL,databases,8200,62,multi-AZ
ElastiCache Redis,databases,2100,40,cluster de producao
S3 Standard,storage,3100,,5 buckets principais
EBS gp3,storage,1600,68,volumes de producao
CloudWatch Logs,observability,2800,,retencao de 90 dias
CloudWatch Metrics,observability,900,,
Data Transfer Out,network,1900,,trafego entre regioes
NAT Gateway,network,1200,,3 gateways ativos
Lambda,compute,900,30,~12M invocacoes/mes

# ACTION
Deve ser entregue as oportunidades de economia priorizadas por impacto, quanto cada uma representa em percentual da conta total, o esforço de implementação (baixo, médio, alto) e os riscos ou pré-requisitos envolvidos em cada uma.

# GOAL
Relatório deve apresentar uma redução de pelo menos 15% no custo total para o próximo trimestre
Para documentação, prencher um arquivo 'response.md' com esse prompt, com o modelo usado, com o resultado (arquivos) e justificativa porque o TAG se mostra eficiente para essa tarefa em 150 palavras.
```

Modelo: claude-haiku-4-5-20251001 - Modelo escolhido pela tarefa bem definida com todas as informações necessárias e critério objetivo.

Output: relatorio_finops.md

Justificativa: O T-A-G elimina ambiguidade ao separar contexto, entrega esperada e critério de sucesso. Isso resultou em um relatório objetivo, acionável e alinhado à meta exata (15%).