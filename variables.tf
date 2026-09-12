variable "aws_region" {
  description = "Regiao AWS onde o RDS e provisionado."
  type        = string
  default     = "us-east-1"
}

variable "db_name" {
  description = "Nome do banco de dados criado dentro da instancia RDS."
  type        = string
  default     = "mecanica_db"
}

variable "db_username" {
  description = "Usuario master do RDS."
  type        = string
  default     = "workshop"
}

variable "instance_class" {
  description = "Classe da instancia RDS."
  type        = string
  default     = "db.t3.micro"
}

variable "allocated_storage" {
  description = "Armazenamento alocado (GB)."
  type        = number
  default     = 20
}

variable "engine_version" {
  description = "Versao do PostgreSQL (mesma do postgres:16-alpine usado no cluster ate agora)."
  type        = string
  default     = "16"
}

variable "publicly_accessible" {
  description = <<-EOT
    Enquanto nao existe nenhuma computacao (EKS/Lambda) dentro da VPC, o RDS
    precisa ser publico para rodar a migracao/seed inicial a partir de um
    laptop. Assim que o cluster/Lambda existirem dentro da VPC, mude para
    false e remova operator_cidr.
  EOT
  type        = bool
  default     = true
}

variable "operator_cidr" {
  description = "CIDR /32 do IP publico de quem esta rodando a migracao/seed inicial (ex.: 203.0.113.10/32). Vazio para nao liberar acesso externo."
  type        = string
  default     = ""
}
