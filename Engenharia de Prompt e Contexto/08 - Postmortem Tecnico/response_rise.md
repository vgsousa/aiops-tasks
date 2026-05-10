Prompt:
```
# ROLE
Você é um SRE Sênior com experiência em incidentes de alta complexidade

# INPUT
Após a realização de um deploy ontem começamos a ter problemas graves no ambiente. Os dados que tenho são:
[...changelog v2.48.0, métricas Beacon, logs do pod, estado do Reactor e cluster...]

# STEPS
1. Verificar linha do tempo das evidências
2. Verificar possíveis impactos do deploy
3. Buscar possíveis causa raiz
4. Analisar opções que justiquem as possíveis causas raiz
5. Avaliar e propor as opções de solução
6. Construir plano de ação imediato

# EXPECTATION
Preciso de um postmortem técnico em 20 minutos para decidir entre rollback do deploy v2.48.0
(que subiu ontem) e scaling emergencial (aumento de limits do RDS e do pool de conexões)
```

Modelo: claude-sonnet-4-6

Output: postmortem-chronos-rise.md

Justificativa:
RISE é eficiente pois a ROLE calibra a perspectiva técnica, INPUT concentra todos os dados brutos em um único bloco, STEPS impõe uma sequência analítica que evita conclusões precipitadas, e EXPECTATION restringe a entrega. O resultado é um postmortem analítico, não apenas uma opinião.
