data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

resource "aws_db_subnet_group" "this" {
  name       = "castor-garage-db"
  subnet_ids = data.aws_subnets.default.ids

  tags = {
    Name = "castor-garage-db"
  }
}

resource "aws_security_group" "rds" {
  name        = "castor-garage-rds"
  description = "Ingress ao RDS PostgreSQL do Castor Garage"
  vpc_id      = data.aws_vpc.default.id

  # dentro da VPC (futuro EKS/Lambda) - ver ADR-0004 no repo da aplicacao principal
  ingress {
    description = "Postgres a partir de qualquer host na VPC default"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.default.cidr_block]
  }

  dynamic "ingress" {
    for_each = var.publicly_accessible && var.operator_cidr != "" ? [var.operator_cidr] : []
    content {
      description = "Acesso temporario do operador para migrate/seed inicial"
      from_port   = 5432
      to_port     = 5432
      protocol    = "tcp"
      cidr_blocks = [ingress.value]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "castor-garage-rds"
  }
}

resource "random_password" "master" {
  length  = 20
  special = false # evita caracteres que precisariam de URL-encoding no DATABASE_URL
}

resource "aws_db_instance" "this" {
  identifier     = "castor-garage-db"
  engine         = "postgres"
  engine_version = var.engine_version
  instance_class = var.instance_class

  allocated_storage = var.allocated_storage
  storage_encrypted = true

  db_name  = var.db_name
  username = var.db_username
  password = random_password.master.result
  port     = 5432

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = var.publicly_accessible

  multi_az                = false
  backup_retention_period = 1
  skip_final_snapshot     = true
  deletion_protection     = false
  apply_immediately       = true

  tags = {
    Name    = "castor-garage-db"
    Project = "castor-garage"
  }
}

locals {
  database_url = "postgresql://${var.db_username}:${random_password.master.result}@${aws_db_instance.this.address}:5432/${var.db_name}?sslmode=require"
}

resource "aws_ssm_parameter" "database_url" {
  name        = "/castor-garage/database-url"
  description = "Connection string do RDS PostgreSQL, consumida pela Lambda de auth e pelo deploy da API principal"
  type        = "SecureString"
  value       = local.database_url
  overwrite   = true
}
