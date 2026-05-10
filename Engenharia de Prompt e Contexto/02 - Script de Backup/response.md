Prompt:
```
# Role
Você é um SRE especializado em AWS

# Task
Crie um script que ficará no EC2, será executado 1 vez ao dia, com os seguintes parametros: 
Host: ledger-db.internal.hvt.io
Porta: 5432
Banco: ledger_prod
Usuário de backup: backup_user
Senha: variável de ambiente PGPASSWORD, populada pelo AWS Secrets Manager via IAM role da instância
Região AWS: us-east-1
SO da instância: Ubuntu 22.04 LTS
Diretório de trabalho com 80 GB livres: /var/backups/ledger
Tamanho médio atual do dump compactado: ~12 GB


# Format
O precisa fazer o dump com pg_dump, compactar com gzip, subir o arquivo no bucket S3 hvt-ledger-backups via aws s3 cp, manter 30 dias de retenção no S3 (removendo os mais antigos), registrar cada execução em /var/log/ledger-backup.log com timestamp, e sair com exit code adequado em caso de falha.
Para documentação, prencher um arquivo 'response.md' com esse prompt, com o modelo usado e com o resultado.
```

Modelo: claude-haiku-4-5-20251001 - Escolhido por ser um código simples, fácil de validar e com informações facilmente conhecidas, além do preço significativamente menor.

Output: ledger_backup.sh

Justificativa: O enunciado possuia todas as informações, sendo necessário apenas adequar a estrutura. Tornando muito eficiente a resposta.