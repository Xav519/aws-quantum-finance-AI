locals {
  prefix = "${var.project}-${var.environment}"
}

# Braket fires "Braket Task State Change" (not Job) when using create_quantum_task
resource "aws_cloudwatch_event_rule" "braket_task_complete" {
  name        = "${local.prefix}-braket-task-complete"
  description = "Triggers Lambda Braket when a Braket quantum TASK reaches a terminal state"

  event_pattern = jsonencode({
    source      = ["aws.braket"]
    detail-type = ["Braket Task State Change"]
    detail = {
      status = ["COMPLETED", "FAILED", "CANCELLED"]
    }
  })

  tags = {
    Project     = var.project
    Environment = var.environment
  }
}

resource "aws_cloudwatch_event_target" "braket_to_lambda" {
  rule      = aws_cloudwatch_event_rule.braket_task_complete.name
  target_id = "LambdaBraketTarget"
  arn       = var.lambda_braket_arn
}

resource "aws_lambda_permission" "eventbridge_invoke_braket" {
  statement_id  = "AllowEventBridgeInvokeBraket"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_braket_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.braket_task_complete.arn
}