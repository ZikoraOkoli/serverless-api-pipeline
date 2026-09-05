# 1. IAM Execution Role for Lambda
resource "aws_iam_role" "lambda_exec_role" {
  name = "proj2_lambda_execution_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# 2. Least-Privilege IAM Policy for S3, DynamoDB, and CloudWatch Logging
resource "aws_iam_policy" "lambda_policy" {
  name        = "proj2_lambda_permissions_policy"
  description = "Allows Lambda to write to S3 bucket, write to DynamoDB table, and manage logs."

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # CloudWatch Logging Permissions
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      # S3 PutObject Permission (Scoped directly to our bucket)
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject"
        ]
        Resource = "${aws_s3_bucket.payload_bucket.arn}/*"
      },
      # DynamoDB PutItem Permission (Scoped directly to our table)
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem"
        ]
        Resource = aws_dynamodb_table.metadata_table.arn
      }
    ]
  })
}

# 3. Attach Policy to the Lambda Execution Role
resource "aws_iam_role_policy_attachment" "lambda_policy_attach" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}