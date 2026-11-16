# Bancos relacionais dos microsservicos da Fase 4 (ver RFC 0004 e ADR 0006
# em mecanica-pos-SOAT/docs): Billing e Execucao ganham cada um uma
# instancia RDS PostgreSQL propria - nenhum servico acessa o banco de outro.
# O RDS do OS Service continua sendo o aws_db_instance.this de main.tf, sem
# nenhuma mudanca.
#
# Diferente do RDS do OS Service, estas instancias nascem privadas
# (publicly_accessible = false): nao existe carga inicial a partir de um
# laptop. As migrations rodam de dentro do cluster EKS, no start do
# container de cada servico (prisma migrate deploy no CMD do Dockerfile), e
# o security group compartilhado (aws_security_group.rds) ja libera a porta
# 5432 para a VPC default inteira.

locals {
  service_databases = {
    billing = {
      db_name         = "mecanica_billing_db"
      staging_db_name = "mecanica_billing_db_staging"
    }
    execucao = {
      db_name         = "mecanica_execucao_db"
      staging_db_name = "mecanica_execucao_db_staging"
    }
  }
}

resource "random_password" "service" {
  for_each = local.service_databases

  length  = 20
  special = false # mesmo motivo do random_password.master: evita URL-encoding no DATABASE_URL
}

resource "aws_db_instance" "service" {
  for_each = local.service_databases

  identifier     = "castor-garage-${each.key}-db"
  engine         = "postgres"
  engine_version = var.engine_version
  instance_class = var.instance_class

  allocated_storage = var.allocated_storage
  storage_encrypted = true

  db_name  = each.value.db_name
  username = var.db_username
  password = random_password.service[each.key].result
  port     = 5432

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false

  multi_az                = false
  backup_retention_period = 1
  skip_final_snapshot     = true
  deletion_protection     = false
  apply_immediately       = true

  tags = {
    Name    = "castor-garage-${each.key}-db"
    Project = "castor-garage"
    Service = each.key
  }
}

locals {
  # Mesmo formato (sslmode=require&uselibpqcompat=true) do database_url do
  # OS Service em main.tf - ver comentario la.
  service_database_urls = {
    for name, cfg in local.service_databases : name => {
      production = "postgresql://${var.db_username}:${random_password.service[name].result}@${aws_db_instance.service[name].address}:5432/${cfg.db_name}?sslmode=require&uselibpqcompat=true"
      staging    = "postgresql://${var.db_username}:${random_password.service[name].result}@${aws_db_instance.service[name].address}:5432/${cfg.staging_db_name}?sslmode=require&uselibpqcompat=true"
    }
  }
}

# Contrato com o deploy de cada servico: o pipeline do repositorio do
# servico le estes parametros para montar o Secret do Kubernetes
# (billing-secret / execucao-secret), no mesmo padrao do
# /castor-garage/database-url do OS Service.
resource "aws_ssm_parameter" "service_database_url" {
  for_each = local.service_databases

  name        = "/castor-garage/${each.key}/database-url"
  description = "Connection string do RDS PostgreSQL do servico ${each.key} (producao)"
  type        = "SecureString"
  value       = local.service_database_urls[each.key].production
}

resource "aws_ssm_parameter" "service_database_url_staging" {
  for_each = local.service_databases

  name        = "/castor-garage/${each.key}/database-url-staging"
  description = "Connection string do database de staging do servico ${each.key} (mesma instancia RDS, database separado). O database em si e criado no deploy de staging do servico - este Terraform so compoe a string."
  type        = "SecureString"
  value       = local.service_database_urls[each.key].staging
}
