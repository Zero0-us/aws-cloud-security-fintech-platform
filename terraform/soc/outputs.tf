output "s3_vpc_endpoint_id" {
  description = "S3 VPC Endpoint ID"
  value       = aws_vpc_endpoint.s3.id
}
