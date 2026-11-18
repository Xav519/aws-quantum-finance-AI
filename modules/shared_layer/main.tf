locals {
  prefix = "${var.project}-${var.environment}"
}

# --- Shared Python code (qf_common) ---
# Bedrock client, exact/greedy solvers, job-record helpers and HTTP helpers are
# used by several functions. Shipping them once as a layer avoids copy-pasted
# code drifting apart between Lambdas. Lambda mounts layers under /opt, and
# /opt/python is on sys.path, hence the python/ directory inside the zip.
data "archive_file" "layer_zip" {
  type        = "zip"
  source_dir  = "${path.module}/python"
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
