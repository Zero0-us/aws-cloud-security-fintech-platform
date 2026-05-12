# VPN EC2 고정 IP (Corp에 전달 필요)
output "vpn_fixed_ip" {
  description = "VPN EC2 EIP - Corp에 전달 필요"
  value       = aws_eip.vpn_fixed.public_ip
}