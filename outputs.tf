output "db_endpoint" {
  description = "Host:porta do RDS"
  value       = aws_db_instance.this.endpoint
}

output "db_address" {
  description = "Host do RDS (sem porta)"
  value       = aws_db_instance.this.address
}

output "ssm_parameter_name" {
  description = "Nome do parametro SSM com a DATABASE_URL completa"
  value       = aws_ssm_parameter.database_url.name
}

output "security_group_id" {
  description = "Security group do RDS (para liberar acesso de outros repos - EKS/Lambda)"
  value       = aws_security_group.rds.id
}

output "ssm_parameter_name_staging" {
  description = "Nome do parametro SSM com a DATABASE_URL de staging"
  value       = aws_ssm_parameter.database_url_staging.name
}

output "newrelic_check_command" {
  description = "Comando para verificar se o pod de monitoramento do RDS (nri-postgresql) esta rodando no cluster EKS"
  value       = "kubectl --context ${var.eks_cluster_name} -n newrelic get pods -l app=nri-postgresql-castor-garage"
}

output "service_db_endpoints" {
  description = "Host:porta do RDS de cada microsservico da Fase 4 (billing, execucao)"
  value       = { for name, db in aws_db_instance.service : name => db.endpoint }
}

output "service_ssm_parameter_names" {
  description = "Nomes dos parametros SSM com a DATABASE_URL (producao e staging) de cada microsservico da Fase 4"
  value = {
    for name in keys(local.service_databases) : name => {
      production = aws_ssm_parameter.service_database_url[name].name
      staging    = aws_ssm_parameter.service_database_url_staging[name].name
    }
  }
}

output "payment_attempts_table_name" {
  description = "Tabela DynamoDB de PaymentAttempt do Billing Service (nome tambem publicado em /castor-garage/billing/payment-attempts-table)"
  value       = aws_dynamodb_table.payment_attempts.name
}
