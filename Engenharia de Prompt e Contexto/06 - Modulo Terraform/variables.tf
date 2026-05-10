variable "name" {
  description = "Nome do bucket (sem o prefixo hvt-). Resultado: hvt-{name}-{environment}"
  type        = string
}

variable "environment" {
  description = "Nome do ambiente (dev, staging, production)"
  type        = string
}

variable "owner" {
  description = "Time ou pessoa responsável pelo recurso (tag Owner)"
  type        = string
}

variable "cost_center" {
  description = "Centro de custo para billing (tag CostCenter)"
  type        = string
}

variable "logging_bucket" {
  description = "Nome do bucket de destino para logs de acesso S3"
  type        = string
}

variable "force_destroy" {
  description = "Permitir destruir bucket mesmo com objetos. Usar com cautela em produção."
  type        = bool
  default     = false
}

variable "enable_lifecycle" {
  description = "Habilitar regras de lifecycle para transição automática de objetos"
  type        = bool
  default     = false
}

variable "lifecycle_ia_days" {
  description = "Dias para mover objetos para STANDARD_IA (requer enable_lifecycle = true)"
  type        = number
  default     = 30
}

variable "lifecycle_glacier_days" {
  description = "Dias para mover objetos para GLACIER (requer enable_lifecycle = true)"
  type        = number
  default     = 90
}
