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
