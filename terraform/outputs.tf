output "api_endpoint" {
  description = "Public HTTP URL of the deployed API Gateway endpoint"
  value       = "${aws_apigatewayv2_api.http_api.api_endpoint}/process"
}
output "cognito_user_pool_id" {
  value       = aws_cognito_user_pool.user_pool.id
  description = "ID of the Cognito User Pool"
}

output "cognito_client_id" {
  value       = aws_cognito_user_pool_client.user_pool_client.id
  description = "ID of the Cognito App Client"
}