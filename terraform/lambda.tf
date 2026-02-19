# Package all Lambda source files into a zip on each plan/apply.
data "archive_file" "log_click" {
  type        = "zip"
  source_dir  = "${path.module}/lambda_src"
  output_path = "${path.module}/.build/lambda.zip"
}

# --- IAM role for all Lambda functions ---

resource "aws_iam_role" "lambda_exec" {
  name = "${var.project_name}-lambda-exec-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic_logs" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "lambda_dynamo" {
  name = "dynamo-access"
  role = aws_iam_role.lambda_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # Main click-log table
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:Query",
          "dynamodb:Scan",
        ]
        Resource = [
          aws_dynamodb_table.click_log.arn,
          "${aws_dynamodb_table.click_log.arn}/index/*",
        ]
      },
      {
        # Dedup table
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:Query",
        ]
        Resource = [
          aws_dynamodb_table.click_dedup.arn,
        ]
      },
    ]
  })
}

# --- Lambda functions ---

resource "aws_lambda_function" "log_click" {
  function_name    = "${var.project_name}-log-click-${var.environment}"
  role             = aws_iam_role.lambda_exec.arn
  filename         = data.archive_file.log_click.output_path
  source_code_hash = data.archive_file.log_click.output_base64sha256
  handler          = "log_click.handler"
  runtime          = "python3.12"
  timeout          = 10

  environment {
    variables = {
      DYNAMODB_TABLE = aws_dynamodb_table.click_log.name
      DEDUP_TABLE    = aws_dynamodb_table.click_dedup.name
    }
  }
}

resource "aws_lambda_function" "get_click_count" {
  function_name    = "${var.project_name}-get-click-count-${var.environment}"
  role             = aws_iam_role.lambda_exec.arn
  filename         = data.archive_file.log_click.output_path
  source_code_hash = data.archive_file.log_click.output_base64sha256
  handler          = "get_click_count.handler"
  runtime          = "python3.12"
  timeout          = 10

  environment {
    variables = {
      DYNAMODB_TABLE = aws_dynamodb_table.click_log.name
    }
  }
}

resource "aws_lambda_function" "get_user_activity" {
  function_name    = "${var.project_name}-get-user-activity-${var.environment}"
  role             = aws_iam_role.lambda_exec.arn
  filename         = data.archive_file.log_click.output_path
  source_code_hash = data.archive_file.log_click.output_base64sha256
  handler          = "get_user_activity.handler"
  runtime          = "python3.12"
  timeout          = 10

  environment {
    variables = {
      DYNAMODB_TABLE = aws_dynamodb_table.click_log.name
    }
  }
}

resource "aws_lambda_function" "get_user_votes" {
  function_name    = "${var.project_name}-get-user-votes-${var.environment}"
  role             = aws_iam_role.lambda_exec.arn
  filename         = data.archive_file.log_click.output_path
  source_code_hash = data.archive_file.log_click.output_base64sha256
  handler          = "get_user_votes.handler"
  runtime          = "python3.12"
  timeout          = 10

  environment {
    variables = {
      DEDUP_TABLE = aws_dynamodb_table.click_dedup.name
    }
  }
}

# Allow API Gateway to invoke all Lambda functions.
resource "aws_lambda_permission" "apigw_log_click" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.log_click.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.main.execution_arn}/*/*"
}

resource "aws_lambda_permission" "apigw_get_click_count" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.get_click_count.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.main.execution_arn}/*/*"
}

resource "aws_lambda_permission" "apigw_get_user_activity" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.get_user_activity.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.main.execution_arn}/*/*"
}

resource "aws_lambda_permission" "apigw_get_user_votes" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.get_user_votes.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.main.execution_arn}/*/*"
}
