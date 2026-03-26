terraform {
  required_version = ">= 1.7"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# ── 1. IAM ────────────────────────────────────────────────────────────────────
module "iam" {
  source      = "./modules/iam"
  project     = var.project
  environment = var.environment
}

# ── 2. Storage ────────────────────────────────────────────────────────────────
module "storage" {
  source      = "./modules/storage"
  project     = var.project
  environment = var.environment
}

# ── 3. Lambda Classical ───────────────────────────────────────────────────────
module "lambda_classical" {
  source              = "./modules/lambda_classical"
  project             = var.project
  environment         = var.environment
  lambda_role_arn     = module.iam.lambda_role_arn
  dynamodb_table_name = module.storage.dynamodb_table_name
}

# ── 4. Lambda Braket ──────────────────────────────────────────────────────────
module "lambda_braket" {
  source                 = "./modules/lambda_braket"
  project                = var.project
  environment            = var.environment
  lambda_braket_role_arn = module.iam.lambda_braket_role_arn
  dynamodb_table_name    = module.storage.dynamodb_table_name
  results_bucket_name    = module.storage.results_bucket_name
}

# ── 5. Lambda Get Job ─────────────────────────────────────────────────────────
module "lambda_get_job" {
  source              = "./modules/lambda_get_job"
  project             = var.project
  environment         = var.environment
  lambda_role_arn     = module.iam.lambda_role_arn
  dynamodb_table_name = module.storage.dynamodb_table_name
}

# ── 6. Lambda Orchestrator ────────────────────────────────────────────────────
module "lambda_orchestrator" {
  source                = "./modules/lambda_orchestrator"
  project               = var.project
  environment           = var.environment
  lambda_role_arn       = module.iam.lambda_role_arn
  lambda_classical_name = module.lambda_classical.function_name
  lambda_braket_name    = module.lambda_braket.function_name
  dynamodb_table_name   = module.storage.dynamodb_table_name
}

# ── 7. Messaging (EventBridge) — depends on Lambda Braket ─────────────────────
module "messaging" {
  source             = "./modules/messaging"
  project            = var.project
  environment        = var.environment
  lambda_braket_arn  = module.lambda_braket.function_arn
  lambda_braket_name = module.lambda_braket.function_name
}

# ── 8. API Gateway ────────────────────────────────────────────────────────────
module "api_gateway" {
  source                   = "./modules/api_gateway"
  project                  = var.project
  environment              = var.environment
  lambda_orchestrator_arn  = module.lambda_orchestrator.function_arn
  lambda_orchestrator_name = module.lambda_orchestrator.function_name
  lambda_get_job_arn       = module.lambda_get_job.function_arn
  lambda_get_job_name      = module.lambda_get_job.function_name
}

# ── 9. Observability ──────────────────────────────────────────────────────────
module "observability" {
  source                   = "./modules/observability"
  project                  = var.project
  environment              = var.environment
  alert_email              = var.alert_email
  lambda_orchestrator_name = module.lambda_orchestrator.function_name
  lambda_classical_name    = module.lambda_classical.function_name
  lambda_braket_name       = module.lambda_braket.function_name
  lambda_get_job_name      = module.lambda_get_job.function_name
}

# ── 10. Demo Frontend ─────────────────────────────────────────────────────────
module "demo_frontend" {
  source      = "./modules/demo_frontend"
  project     = var.project
  environment = var.environment
  api_url     = module.api_gateway.api_url
}