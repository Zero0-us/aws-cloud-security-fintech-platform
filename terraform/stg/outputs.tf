#============================================================
# VPN Outputs
#============================================================
output "vpn_instance_id" {
  description = "VPN Instance ID for SSM access"
  value       = aws_instance.vpn.id
}

output "vpn_private_ip" {
  description = "VPN Instance Private IP"
  value       = aws_instance.vpn.private_ip
}

# VPN EC2 고정 IP (Corp에 전달 필요)
output "vpn_fixed_ip" {
  description = "VPN EC2 EIP - Corp에 전달 필요"
  value       = aws_eip.vpn.public_ip
}