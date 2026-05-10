# Runbook: [CRITICAL] High Memory Usage — Chronos API Pods (>85% por 10min)

**Serviço:** Chronos API  
**Namespace:** production  
**Canal de plantão:** #oncall-chronos  
**Escalação:** @chronos-core (15 min em horário comercial / 30 min fora)  

---

## Pré-requisitos

Certifique-se de ter acesso às ferramentas antes de começar:

```bash
kubectl version --client
aws --version
argocd version --client
```

Configure o contexto kubectl para o cluster correto:

```bash
aws eks update-kubeconfig --region us-east-1 --name <nome-do-cluster>
kubectl config set-context --current --namespace=production
```

---

## Passo 1 — Confirmar o estado atual dos pods

Verifique quantos pods estão rodando e se há pods em estado degradado:

```bash
kubectl get pods -n production -l app=chronos-api -o wide
```

**O que observar:**
- Coluna `STATUS`: pods em `OOMKilled`, `CrashLoopBackOff` ou `Pending` indicam situação crítica
- Coluna `RESTARTS`: contagem alta indica reinícios por OOM
- Coluna `READY`: se muitos pods não estão prontos, o tráfego está sendo absorvido pelas réplicas restantes

Verifique o uso atual de memória dos pods:

```bash
kubectl top pods -n production -l app=chronos-api --sort-by=memory
```

Verifique o HPA (se está escalando ou travado):

```bash
kubectl get hpa -n production
kubectl describe hpa chronos-api -n production
```

**Estado esperado:** 4–12 réplicas, CPU target ~70%. Se HPA está no limite (12 réplicas) e memória ainda alta, o problema é de memory leak ou underfitting de limits.

---

## Passo 2 — Analisar métricas de memória (últimas 4 horas)

**No Grafana:** Abra o dashboard do Chronos API e filtre as últimas 4 horas. Observe:
- Curva de memória: crescimento linear = possível leak; patamar estável mas alto = underfitting
- Correlação com volume de requisições (pico de tráfego justifica uso maior)
- Horário de início do crescimento

**No Beacon (logs):** Filtre as últimas 4 horas no namespace `production` para o serviço `chronos-api`:

```
namespace=production service=chronos-api level=error
```

Procure por:
- `OutOfMemoryError`, `java.lang.OutOfMemory`, `malloc failed`, `SIGKILL`
- Erros relacionados ao Ledger (PostgreSQL) ou Reactor (SQS) — filas represadas podem inflar buffers em memória

**Via kubectl:** Verifique eventos recentes de OOM no namespace:

```bash
kubectl get events -n production --sort-by='.lastTimestamp' | grep -i "chronos-api\|OOM\|kill"
```

Detalhes de um pod específico (substitua `<pod-name>`):

```bash
kubectl describe pod <pod-name> -n production
```

Procure em `Last State` → `Reason: OOMKilled` para confirmar reinício por memória.

---

## Passo 3 — Verificar o último deploy

Verifique quando foi o último deploy e se coincide com o início do problema:

```bash
argocd app history chronos-api --grpc-web
```

Ou via kubectl (verifica o campo `creationTimestamp` da ReplicaSet mais recente):

```bash
kubectl get replicasets -n production -l app=chronos-api --sort-by='.metadata.creationTimestamp'
```

Verifique a imagem em uso:

```bash
kubectl get deployment chronos-api -n production -o jsonpath='{.spec.template.spec.containers[0].image}'
```

**Correlação:** Se o crescimento de memória coincide com o horário do último deploy (±30 min), há forte indício de regressão introduzida na versão atual.

---

## Passo 4 — Avaliar: memory leak ou subdimensionamento?

Use a tabela abaixo para determinar o diagnóstico:

| Sintoma observado | Diagnóstico provável |
|------------------|----------------------|
| Memória cresce continuamente após o deploy, sem estabilizar | Memory leak (regressão no código) |
| Memória alta mas estável (platô), sem crescimento | Underfitting — limits muito baixos para a carga atual |
| Crescimento correlacionado com horário de pico de tráfego | Underfitting por sazonalidade |
| Crescimento após deploy específico | Regressão — candidato a rollback |
| Restart por OOMKilled frequente mas pods voltam | Leak acumulativo entre restarts |

Verifique os limits atuais configurados no deployment:

```bash
kubectl get deployment chronos-api -n production -o jsonpath='{.spec.template.spec.containers[0].resources}' | jq .
```

---

## Passo 5 — Ação imediata de mitigação

Escolha **uma** das ações abaixo conforme o diagnóstico do Passo 4:

### Opção A — Escala horizontal temporária (menor risco)

Use quando a memória está alta mas estável e o HPA não escalou o suficiente:

```bash
kubectl scale deployment chronos-api -n production --replicas=10
```

Monitore por 5 minutos:

```bash
watch -n 10 kubectl top pods -n production -l app=chronos-api
```

### Opção B — Aumentar limits de memória temporariamente

Use quando a memória está no limite configurado e o problema é claramente underfitting:

```bash
kubectl set resources deployment chronos-api -n production \
  --containers=api \
  --limits=memory=1Gi \
  --requests=memory=512Mi
```

> **Atenção:** Esta alteração será sobrescrita pelo próximo deploy via Argo CD. Documente no canal #oncall-chronos.

### Opção C — Rollback (se correlacionado com deploy recente)

Use quando o diagnóstico aponta regressão introduzida no último deploy:

```bash
# Via Argo CD (preferencial — mantém sincronia com o repositório)
argocd app rollback chronos-api --grpc-web

# Via kubectl (somente se argocd não estiver disponível)
kubectl rollout undo deployment/chronos-api -n production
```

Confirme que o rollback foi aplicado:

```bash
kubectl rollout status deployment/chronos-api -n production
kubectl get pods -n production -l app=chronos-api
```

---

## Passo 6 — Critérios de escalação para o time de desenvolvimento

**Escale para @chronos-core imediatamente se:**

- Pods estão em `OOMKilled` e reiniciam em loop (mais de 5 vezes em 30 min)
- Rollback foi executado mas o problema persiste
- Erros nas dependências (Ledger ou Reactor) sugerem causa raiz externa
- Nenhuma das ações de mitigação (Passos 5A, 5B, 5C) estabilizou os pods em 15 minutos
- O alerta disparou fora do horário comercial e a situação não melhora em 20 minutos

**Ao escalar, envie no canal #oncall-chronos:**

```
@chronos-core ESCALAÇÃO — Chronos API High Memory
- Horário do alerta: <HH:MM>
- Estado atual: <X pods OOMKilled / Y reinícios>
- Último deploy: <versão/horário>
- Ação tomada: <rollback/scale/ajuste de limit>
- Resultado: <sem melhora / piora>
- Link Grafana: <URL do dashboard filtrado>
```

---

## Passo 7 — Ajustes definitivos e critério de validação pós-fix

Após estabilização, abra uma issue no repositório `hvt/chronos-api` com:

### Ajustes recomendados

**Se underfitting (limits baixos):**
- Aumentar `resources.limits.memory` no manifesto do deployment via PR
- Ajustar HPA para considerar memória como métrica adicional:
  ```yaml
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
  ```

**Se memory leak:**
- Time de desenvolvimento deve perfilar a aplicação com heap dump
- Habilitar flag de profiling temporariamente via env var (validar com time)
- Considerar adicionar alertas de tendência (memória crescendo >5% em 30min)

### Critérios de validação pós-fix

O fix é considerado bem-sucedido quando, por 48 horas após o deploy:

- [ ] Alerta não disparou novamente
- [ ] `kubectl top pods` mostra memória estável (sem tendência crescente)
- [ ] Grafana confirma platô de memória abaixo de 75% dos limits
- [ ] Sem pods em `OOMKilled` ou `CrashLoopBackOff`
- [ ] HPA não atingiu o máximo (12 réplicas) sem justificativa de tráfego

---

## Registro de incidente

Ao finalizar, registre no canal #oncall-chronos:

```
RESOLUÇÃO — Chronos API High Memory
- Duração do incidente: <X minutos>
- Causa raiz: <memory leak / underfitting / regressão em deploy X>
- Ação tomada: <rollback / scale / ajuste de limits>
- Issue aberta: hvt/chronos-api#<número>
- Próximos passos: <PR de fix / profiling agendado>
```
