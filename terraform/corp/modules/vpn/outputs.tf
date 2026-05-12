output "vpn_ec2_id" {
  description = "VPN EC2 인스턴스 ID"
  value       = aws_instance.vpn.id
}

output "corp_eip" {
  description = "Corp VPN 고정 EIP (Dev팀에 전달할 IP)"
  value       = data.aws_eip.corp_vpn.public_ip
}
