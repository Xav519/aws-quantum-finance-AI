locals {
  prefix = "${var.project}-${var.environment}"
}

# --- EventBridge Rule ---
# This rule watches the AWS event bus specifically for Amazon Braket events.
# Since Quantum tasks take time, we don't wait on the line; we wait for this "State Change".
resource "aws_cloudwatch_event_rule" "braket_task_complete" {
  name        = "${local.prefix}-braket-task-complete"
  description = "Triggers Lambda Braket when a Braket quantum TASK reaches a terminal state"

  # The filter: only trigger when a task is finished (successfully or otherwise).
  # Terminal states ensure we don't trigger while the task is still 'QUEUED' or 'RUNNING'.
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

# --- EventBridge Target ---
# This resource connects the "Rule" above to your specific Lambda function.
# It tells EventBridge: "When the rule matches, send the event data to this ARN."
resource "aws_cloudwatch_event_target" "braket_to_lambda" {
  rule      = aws_cloudwatch_event_rule.braket_task_complete.name
  target_id = "LambdaBraketTarget"
  arn       = var.lambda_braket_arn
}

# --- Lambda Permission ---
# CRITICAL: By default, EventBridge is not allowed to trigger Lambda functions.
# This explicit permission "opens the door" for the events service (principal) 
# to execute your specific Braket Lambda.
resource "aws_lambda_permission" "eventbridge_invoke_braket" {
  statement_id  = "AllowEventBridgeInvokeBraket"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_braket_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.braket_task_complete.arn
}