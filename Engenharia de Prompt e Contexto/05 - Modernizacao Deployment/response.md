Prompt:
```
# BEFORE
Temos o seguinte manifesto no kubernetes:

apiVersion: apps/v1
kind: Deployment
metadata:
  name: chronos-api
  namespace: production
spec:
  replicas: 1
  selector:
    matchLabels:
      app: chronos-api
  template:
    metadata:
      labels:
        app: chronos-api
    spec:
      containers:
      - name: api
        image: chronos-api:latest
        ports:
        - containerPort: 8080
        env:
        - name: DB_PASSWORD
          value: "P@ssw0rd2023!"
        - name: JWT_SECRET
          value: "hvt-jwt-prod-secret"

# AFTER
Precisamos modernizar para ter alta disponibilidade, imagem versionada (nada de latest), secrets fora do manifest, resource requests e limits, liveness e readiness probes, securityContext não-root e as demais práticas de produção que hoje são padrão na empresa.


# BRIDGE
Reconstrua o manifesto respeitando essas novas regras.
Para documentação, prencher um arquivo 'response.md' com esse prompt, com o modelo usado e com o resultado (arquivos)
```

Modelo: claude-haiku-4-5-20251001 - Não vejo necessidade de aplicar o Sonnet ou outro modelo para uma tarefa de conhecimento prático

Output: chronos-api-deployment.yaml

Justificativa:
BAB é muito eficiente pois contextualiza o problema, define o objetivo e direciona a solução. Essa estrutura força o modelo a identificar gaps específicos entre estado atual e ideal.
