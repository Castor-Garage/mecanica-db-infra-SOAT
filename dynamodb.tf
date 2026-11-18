# Banco NoSQL exigido pela Fase 4 (o conjunto dos servicos precisa usar pelo
# menos 1 banco relacional e 1 nao relacional - ver RFC 0004 em
# mecanica-pos-SOAT/docs): tabela DynamoDB do Billing Service para
# PaymentAttempt, isto e, o payload cru de cada notificacao de webhook do
# Mercado Pago e o resultado da consulta de status feita em seguida. O
# formato desses payloads varia por tipo de evento e nao precisa de join com
# nada - por isso fica fora do Postgres do Billing.
#
# DynamoDB em vez de MongoDB (Atlas), decisao que a RFC 0004 deixou em
# aberto: e gerenciado nativo na mesma conta do AWS Academy, nao tem
# servidor/cluster para provisionar nem connection string com senha. Os
# pods acessam pela LabRole dos nodes do EKS via IMDS (hop limit 2 ja
# configurado em mecanica-k8s-infra-SOAT) - o mesmo mecanismo usado para as
# filas SQS. PAY_PER_REQUEST: sem capacidade provisionada, custo praticamente
# zero no volume de demonstracao.

resource "aws_dynamodb_table" "payment_attempts" {
  name         = "castor-garage-billing-payment-attempts"
  billing_mode = "PAY_PER_REQUEST"

  # paymentId = nosso Payment.id (o external_reference que volta na consulta
  # ao Mercado Pago); receivedAt = timestamp ISO-8601 da notificacao. Um
  # mesmo pagamento recebe varias notificacoes (pendente -> aprovado,
  # reenvios do Mercado Pago, cartao recusado e nova tentativa) - cada uma
  # vira um item, ordenado por receivedAt dentro do pagamento.
  hash_key  = "paymentId"
  range_key = "receivedAt"

  attribute {
    name = "paymentId"
    type = "S"
  }

  attribute {
    name = "receivedAt"
    type = "S"
  }

  tags = {
    Name    = "castor-garage-billing-payment-attempts"
    Project = "castor-garage"
    Service = "billing"
  }
}

resource "aws_ssm_parameter" "payment_attempts_table" {
  name        = "/castor-garage/billing/payment-attempts-table"
  description = "Nome da tabela DynamoDB de PaymentAttempt do Billing Service (payloads de webhook do Mercado Pago)"
  type        = "String"
  value       = aws_dynamodb_table.payment_attempts.name
}
