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

  default_tags {
    tags = {
      Project     = var.project
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

# --- 1. Storage: DynamoDB jobs table + Braket results bucket ---
module "storage" {
  source      = "../modules/storage"
  project     = var.project
  environment = var.environment
}

# --- 2. IAM: one least-privilege role per Lambda ---
module "iam" {
  source             = "../modules/iam"
  project            = var.project
  environment        = var.environment
  aws_region         = var.aws_region
  jobs_table_arn     = module.storage.jobs_table_arn
  results_bucket_arn = module.storage.results_bucket_arn
  bedrock_model_id   = var.bedrock_model_id
}

# --- 3. Shared Lambda layer (qf_common) ---
module "shared_layer" {
  source      = "../modules/shared_layer"
  project     = var.project
  environment = var.environment
}

# --- 4. Classical solver ---
module "lambda_classical" {
  source              = "../modules/lambda_classical"
  project             = var.project
  environment         = var.environment
  role_arn            = module.iam.classical_role_arn
  layer_arn           = module.shared_layer.layer_arn
  dynamodb_table_name = module.storage.dynamodb_table_name
  bedrock_model_id    = var.bedrock_model_id
}

# --- 5. Quantum solver (QAOA on Braket) ---
module "lambda_braket" {
  source              = "../modules/lambda_braket"
  project             = var.project
  environment         = var.environment
  role_arn            = module.iam.braket_role_arn
  layer_arn           = module.shared_layer.layer_arn
  dynamodb_table_name = module.storage.dynamodb_table_name
  results_bucket_name = module.storage.results_bucket_name
  bedrock_model_id    = var.bedrock_model_id
  braket_device_arn   = var.braket_device_arn
  qaoa_layers         = var.qaoa_layers
  qaoa_shots          = var.qaoa_shots
}

# --- 6. Job status reader ---
module "lambda_get_job" {
  source              = "../modules/lambda_get_job"
  project             = var.project
  environment         = var.environment
  role_arn            = module.iam.get_job_role_arn
  layer_arn           = module.shared_layer.layer_arn
  dynamodb_table_name = module.storage.dynamodb_table_name
}

# --- 7. Orchestrator: validation + routing by problem size ---
module "lambda_orchestrator" {
  source                   = "../modules/lambda_orchestrator"
  project                  = var.project
  environment              = var.environment
  role_arn                 = module.iam.orchestrator_role_arn
  layer_arn                = module.shared_layer.layer_arn
  dynamodb_table_name      = module.storage.dynamodb_table_name
  lambda_classical_name    = module.lambda_classical.function_name
  lambda_braket_name       = module.lambda_braket.function_name
  classical_threshold      = var.classical_threshold
  max_quantum_jobs_per_day = var.max_quantum_jobs_per_day
  qaoa_shots               = var.qaoa_shots
}

# --- 8. EventBridge: Braket task completion -> Braket Lambda ---
module "messaging" {
  source             = "../modules/messaging"
  project            = var.project
  environment        = var.environment
  lambda_braket_arn  = module.lambda_braket.function_arn
  lambda_braket_name = module.lambda_braket.function_name
}

# --- 9. Frontend: private S3 + CloudFront (HTTPS, security headers) ---
module "demo_frontend" {
  source      = "../modules/demo_frontend"
  project     = var.project
  environment = var.environment
  aws_region  = var.aws_region
  api_url     = module.api_gateway.api_url
}

# --- 10. HTTP API: POST /optimize, GET /jobs/{job_id} ---
module "api_gateway" {
  source                   = "../modules/api_gateway"
  project                  = var.project
  environment              = var.environment
  lambda_orchestrator_arn  = module.lambda_orchestrator.function_arn
  lambda_orchestrator_name = module.lambda_orchestrator.function_name
  lambda_get_job_arn       = module.lambda_get_job.function_arn
  lambda_get_job_name      = module.lambda_get_job.function_name
  cors_allowed_origins     = concat([module.demo_frontend.cloudfront_origin], var.extra_cors_origins)
}

# --- 11. Observability: alarms, dashboard, SNS email ---
module "observability" {
  source                   = "../modules/observability"
  project                  = var.project
  environment              = var.environment
  aws_region               = var.aws_region
  alert_email              = var.alert_email
  api_id                   = module.api_gateway.api_id
  lambda_orchestrator_name = module.lambda_orchestrator.function_name
  lambda_classical_name    = module.lambda_classical.function_name
  lambda_braket_name       = module.lambda_braket.function_name
  lambda_get_job_name      = module.lambda_get_job.function_name
}

# --- State refactoring --------------------------------------------------------
# Lambda log groups moved from the observability module into each Lambda
# module. These blocks keep existing deployments from destroying and
# re-creating them (which would fail: the names already exist).
moved {
  from = module.observability.aws_cloudwatch_log_group.orchestrator
  to   = module.lambda_orchestrator.aws_cloudwatch_log_group.this
}

moved {
  from = module.observability.aws_cloudwatch_log_group.classical
  to   = module.lambda_classical.aws_cloudwatch_log_group.this
}

moved {
  from = module.observability.aws_cloudwatch_log_group.braket
  to   = module.lambda_braket.aws_cloudwatch_log_group.this
}

moved {
  from = module.observability.aws_cloudwatch_log_group.get_job
  to   = module.lambda_get_job.aws_cloudwatch_log_group.this
}

moved {
  from = module.observability.aws_cloudwatch_metric_alarm.orchestrator_errors
  to   = module.observability.aws_cloudwatch_metric_alarm.lambda_errors["orchestrator"]
}

# Same S3 key: moving (not replacing) avoids a delete racing the new upload.
moved {
  from = module.demo_frontend.aws_s3_object.index
  to   = module.demo_frontend.aws_s3_object.static["index.html"]
}
