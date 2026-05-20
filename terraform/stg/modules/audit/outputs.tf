output "cloudtrail_name" {
  value = aws_cloudtrail.this.name
}

output "cloudtrail_s3_bucket" {
  value = aws_s3_bucket.cloudtrail.bucket
}

output "cloudtrail_log_group" {
  value = aws_cloudwatch_log_group.cloudtrail.name
}
