#============================================================
# VPN Outputs
#============================================================
output "vpn_fixed_ip" {
  description = "VPN Instance Elastic IP - Corp에 전달"
  value       = aws_eip.vpn.public_ip
}

output "vpn_instance_id" {
  description = "VPN Instance ID for SSM access"
  value       = aws_instance.vpn.id
}

output "vpn_private_ip" {
  description = "VPN Instance Private IP"
  value       = aws_instance.vpn.private_ip
}

output "s3_vpc_endpoint_id" {
  description = "S3 VPC Endpoint ID"
  value       = aws_vpc_endpoint.s3.id
}