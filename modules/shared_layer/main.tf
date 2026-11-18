# ==============================================================================
# modules/shared_layer/main.tf
# ------------------------------------------------------------------------------
# PURPOSE
#   Packages the shared Python code (qf_common) as a Lambda layer.
#
# DETAILS
#   Several functions need the same helpers (solver, Bedrock client, job record
#   formatting, HTTP responses). Publishing them once as a layer avoids copying
#   the same code into every function.
#   Lambda extracts layers under /opt and adds /opt/python to the import path,
#   which is why the code lives in layer/python/qf_common/.
# ==============================================================================

locals {
  prefix = "${var.project}-${var.environment}"
}

# --- Shared Python code (qf_common) ---
# Bedrock client, exact/greedy solvers, job-record helpers and HTTP helpers are
# used by several functions. Shipping them once as a layer avoids copy-pasted
# code drifting apart between Lambdas.
#
# Lambda extracts layers to /opt and only /opt/python is on sys.path, so the
# zip must contain python/qf_common/... . archive_file zips the *contents* of
# source_dir, hence source_dir points at layer/ (which holds python/).
data "archive_file" "layer_zip" {
  type        = "zip"
  source_dir  = "${path.module}/layer"
  output_path = "${path.module}/build/qf_common_layer.zip"
  excludes    = ["**/__pycache__/**"]
}

resource "aws_lambda_layer_version" "common" {
  layer_name               = "${local.prefix}-common"
  description              = "Shared code for the quantum-finance Lambdas (qf_common)"
  filename                 = data.archive_file.layer_zip.output_path
  source_code_hash         = data.archive_file.layer_zip.output_base64sha256
  compatible_runtimes      = ["python3.12"]
  compatible_architectures = ["arm64"]
}
