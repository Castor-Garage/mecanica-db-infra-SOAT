# Castor Garage - DB Infra (RDS PostgreSQL)

Terraform do banco de dados gerenciado do Tech Challenge Fase 3 (SOAT).
Repositório 3 dos 4 exigidos pela entrega ("Infraestrutura do Banco de
Dados Gerenciado (Terraform)"), no lugar do PostgreSQL em cluster usado
até a Fase 2.

## Propósito

Provisiona uma instância **Amazon RDS PostgreSQL 16** (mesma engine já
usada), publica a `DATABASE_URL` completa no **AWS SSM Parameter Store**
(`/castor-garage/database-url`), e é o contrato que a [Lambda de
autenticação](https://github.com/Castor-Garage/mecanica-auth-lambda-SOAT)
e a [API principal](https://github.com/Castor-Garage/mecanica-pos-SOAT)
consomem para se conectar ao banco.

Justificativa completa da escolha (RDS vs banco em cluster) em
[`docs/rfc/0002-banco-de-dados.md`](https://github.com/Castor-Garage/mecanica-pos-SOAT/blob/main/docs/rfc/0002-banco-de-dados.md)
e [`docs/adr/0004-rds-vs-banco-em-cluster.md`](https://github.com/Castor-Garage/mecanica-pos-SOAT/blob/main/docs/adr/0004-rds-vs-banco-em-cluster.md)
no repositório principal.

## Tecnologias

- Terraform (`aws_db_instance`, `aws_db_subnet_group`, `aws_security_group`, `random_password`, `aws_ssm_parameter`)
- AWS Academy (Learner Lab): mesma VPC default usada pelo cluster EKS

## Arquitetura deste repositório

```
aws_db_subnet_group (todas as subnets da VPC default)
        │
aws_db_instance (postgres 16, db.t3.micro, 20GB)
        │
security group: 5432 liberado para a VPC inteira (uso futuro por EKS/Lambda)
        │        + IP do operador, so durante a carga inicial (ver abaixo)
        │
aws_ssm_parameter "/castor-garage/database-url" (SecureString)
```

## Monitoramento (New Relic)

O RDS é um serviço gerenciado da AWS — não há host para instalar um agente
"dentro" dele. Por isso a métrica é coletada por um pod remoto
(`nri-postgresql`, imagem `newrelic/infrastructure-bundle`) rodando no
cluster EKS de
[`mecanica-k8s-infra-SOAT`](https://github.com/Castor-Garage/mecanica-k8s-infra-SOAT),
conectando via rede no endpoint do RDS (já liberado no security group para
toda a VPC). Aplicado por `null_resource.newrelic_postgresql` em `main.tf`,
que cria/atualiza via `kubectl`:

- `manifests/newrelic-postgresql.yaml` — namespace `newrelic` + Deployment (estático, sem segredo).
- `manifests/nri-postgresql-config.yaml` — config do integration nri-postgresql, com placeholders `{{ }}` resolvidos a partir de env vars (estático, sem segredo).
- Secret `nri-postgresql-credentials` — license key + host/usuário/senha do RDS, criado imperativamente com valores do Terraform (nunca commitado).

Verificar depois do apply:

```bash
terraform output -raw newrelic_check_command | bash
```

## Pré-requisitos

- Sessão ativa do AWS Academy Learner Lab (**Start Lab**, credenciais
  temporárias exportadas: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`,
  `AWS_SESSION_TOKEN`).
- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.5
- [kubectl](https://kubernetes.io/docs/tasks/tools/#kubectl) — usado pelo
  `null_resource.newrelic_postgresql` para aplicar o pod de monitoramento no
  cluster de `mecanica-k8s-infra-SOAT` (precisa já estar provisionado).

## Carga inicial (migrate + seed) — só a primeira vez

O RDS nasce **publicamente acessível** (`publicly_accessible = true`, no
`variables.tf`) porque, na primeira aplicação, ainda não existe nenhuma
computação (EKS/Lambda) dentro da VPC para rodar a migração de dentro
dela. Procedimento:

```bash
# 1. descobrir o proprio IP publico
curl -s https://checkip.amazonaws.com

# 2. aplicar liberando esse IP no security group
export TF_VAR_operator_cidr="<seu-ip>/32"
export TF_VAR_new_relic_license_key="<sua-license-key-ingest>"
terraform init
terraform apply

# 3. pegar a DATABASE_URL (ou ler direto do SSM)
terraform output db_endpoint
aws ssm get-parameter --name /castor-garage/database-url --with-decryption --query 'Parameter.Value' --output text

# 4. rodar migrate + seed do laptop, a partir do repo da API principal
cd ../mecanica-pos-SOAT
DATABASE_URL="<url-do-passo-3>" npx prisma migrate deploy
DATABASE_URL="<url-do-passo-3>" npm run db:seed

# 5. fechar o acesso externo de novo
unset TF_VAR_operator_cidr
terraform apply
```

**Quando o cluster EKS e a Lambda já estiverem provisionados dentro da
VPC**, mude `publicly_accessible` para `false` em `variables.tf` (ou passe
`-var="publicly_accessible=false"`) e reaplique — o acesso interno pela
VPC (já liberado por padrão no security group) continua funcionando
normalmente.

## Uso (dia a dia, via CI/CD)

O pipeline (`.github/workflows/pipeline.yml`) roda `terraform plan` em
todo PR e `terraform apply` a cada push em `main`, usando os secrets do
repositório: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`,
`AWS_SESSION_TOKEN` (sessão temporária do AWS Academy — precisa ser
atualizada sempre que a sessão do Lab expirar) e `NEW_RELIC_LICENSE_KEY`
(License key - INGEST - da conta New Relic, usada pelo pod nri-postgresql).

Manualmente:

```bash
export TF_VAR_new_relic_license_key="<sua-license-key-ingest>"
terraform init
terraform plan
terraform apply
```

## Outputs

| Output | Uso |
|---|---|
| `db_endpoint` | host:porta do RDS |
| `ssm_parameter_name` | `/castor-garage/database-url` — lido pela Lambda e pelo deploy da API principal |
| `security_group_id` | para liberar acesso de outro security group (ex.: nós do EKS), se no futuro trocarmos o ingress por CIDR por uma referência direta |
| `newrelic_check_command` | comando `kubectl` para conferir se o pod de monitoramento do RDS está rodando |

## Destruir

```bash
terraform destroy -var="new_relic_license_key=<sua-license-key-ingest>"
```

Sem `deletion_protection` e com `skip_final_snapshot = true` — não deixa
snapshot pra trás, adequado para o ambiente de demonstração acadêmica
(sem dado de produção real a preservar).
