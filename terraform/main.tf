# Random suffix to guarantee unique S3 bucket naming across AWS
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# 1. Amazon S3 Bucket for Raw Payloads (12-Month Free Tier)
resource "aws_s3_bucket" "payload_bucket" {
  bucket        = "proj2-api-payloads-${random_id.bucket_suffix.hex}"
  force_destroy = true
}

# Block all public access to S3 for security best practices
resource "aws_s3_bucket_public_access_block" "s3_privacy" {
  bucket = aws_s3_bucket.payload_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# 2. Amazon DynamoDB Table for Metadata Records (Always Free Tier)
resource "aws_dynamodb_table" "metadata_table" {
  name         = "proj2-api-metadata"
  billing_mode = "PAY_PER_REQUEST" # Zero cost when idle
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }
}

# 3. Zip the Lambda Source Code Automatically
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../src"
  output_path = "${path.module}/lambda_function.zip"
}

# 4. AWS Lambda Function (Serverless Compute)
resource "aws_lambda_function" "api_processor" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "proj2-payload-processor"
  role             = aws_iam_role.lambda_exec_role.arn
  handler          = "app.lambda_handler"
  runtime          = "python3.12"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  environment {
    variables = {
      S3_BUCKET_NAME      = aws_s3_bucket.payload_bucket.id
      DYNAMODB_TABLE_NAME = aws_dynamodb_table.metadata_table.name
    }
  }
}

# CloudWatch Log Group with 3-Day Retention (Minimizes log storage charges)
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${aws_lambda_function.api_processor.function_name}"
  retention_in_days = 3
}

# 5. Amazon API Gateway (HTTP API Endpoint)
resource "aws_apigatewayv2_api" "http_api" {
  name          = "proj2-http-api"
  protocol_type = "HTTP"
}

# API Gateway Integration with Lambda
resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id                 = aws_apigatewayv2_api.http_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.api_processor.invoke_arn
  payload_format_version = "2.0"
}

# Route for POST /process Requests
resource "aws_apigatewayv2_route" "post_route" {
  api_id             = aws_apigatewayv2_api.http_api.id
  route_key          = "POST /process"
  target             = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito_auth.id
}
# 6. Amazon Cognito User Pool (User Directory)
resource "aws_cognito_user_pool" "user_pool" {
  name = "proj2-user-pool"

  password_policy {
    minimum_length    = 8
    require_lowercase = true
    require_numbers   = true
    require_symbols   = false
    require_uppercase = true
  }
}

# Cognito User Pool Client (App credentials for client auth)
resource "aws_cognito_user_pool_client" "user_pool_client" {
  name         = "proj2-app-client"
  user_pool_id = aws_cognito_user_pool.user_pool.id

  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH"
  ]
}

# API Gateway JWT Authorizer linked to Cognito
resource "aws_apigatewayv2_authorizer" "cognito_auth" {
  api_id           = aws_apigatewayv2_api.http_api.id
  authorizer_type  = "JWT"
  identity_sources = ["$request.header.Authorization"]
  name             = "cognito-jwt-authorizer"

  jwt_configuration {
    audience = [aws_cognito_user_pool_client.user_pool_client.id]
    issuer   = "https://cognito-idp.us-east-1.amazonaws.com/${aws_cognito_user_pool.user_pool.id}"
  }
}

# Default Deployment Stage with Auto-Deploy Enabled
resource "aws_apigatewayv2_stage" "api_stage" {
  api_id      = aws_apigatewayv2_api.http_api.id
  name        = "$default"
  auto_deploy = true
}

# Permission for API Gateway to Invoke Lambda
resource "aws_lambda_permission" "api_gw_permission" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api_processor.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http_api.execution_arn}/*/*"
}
