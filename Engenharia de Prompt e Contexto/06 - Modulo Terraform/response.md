Prompt:
```
# CONTEXT
A empresa possui um padrão específico para módulos em terraform.
O novo módulo vai ser consumido por todos os times da empresa, então precisa vir com exemplo de uso.

# ACTION
Criar um módulo Terraform reutilizável pra criar buckets S3

# RESULT
Todo módulo Terraform novo precisa seguir:
- Tags obrigatórias em todo recurso: Owner, CostCenter, Environment.
- Prefixo hvt- nos nomes de recursos.
- Todo bucket S3 com: encryption habilitada (SSE-S3 mínimo), versioning ativo, block public access total, logging configurado.
- Variáveis de entrada em variables.tf com description e type obrigatórios.
Para documentação, prencher um arquivo 'response.md' com esse prompt, com o modelo usado e com o resultado (arquivos)

# EXAMPLE
Como referência de estilo, o módulo de VPC que já existe na empresa:
variable "environment" {
  description = "Nome do ambiente (dev, staging, production)"
  type        = string
}

locals {
  common_tags = {
    Owner       = var.owner
    CostCenter  = var.cost_center
    Environment = var.environment
  }
}

resource "aws_vpc" "this" {
  cidr_block = var.cidr_block
  tags = merge(local.common_tags, {
    Name = "hvt-vpc-${var.environment}"
  })
}
```

Modelo: claude-sonnet-4-6 - Modelo com mais parâmetros para uma resposta mais assertiva e com maior qualidade.

Output:
- variables.tf
- main.tf
- outputs.tf
- examples/basic/main.tf
- examples/with-lifecycle/main.tf

Justificativa:
CARE é eficiente pois além de alinhar o modelo ao padrão interno da empresa, define o escopo, estabelece os critérios objetivos, e para manter o padrão utiliza de exemplo. Resultado, o módulo pronto alinhado aos padrões da empresa.
