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