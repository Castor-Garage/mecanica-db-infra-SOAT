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
