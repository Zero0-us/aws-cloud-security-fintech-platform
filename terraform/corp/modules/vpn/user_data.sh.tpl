#!/bin/bash
set -e

amazon-linux-extras install epel -y
yum install -y strongswan

cat >> /etc/sysctl.conf << 'EOF'
net.ipv4.ip_forward = 1
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
EOF
sysctl -p

cat > /etc/strongswan/ipsec.conf << EOF
config setup
  charondebug="ike 2, knl 2, cfg 2"

conn %default
  keyexchange=ikev2
  ike=aes256-sha256-modp2048!
  esp=aes256-sha256-modp2048!
  dpdaction=restart
  dpddelay=30s
  authby=secret
  left=%defaultroute
  leftid=${corp_eip}
  leftsubnet=${corp_vpc_cidr}
  auto=start

%{ for name, account in target_accounts ~}
conn ${name}
  right=${account.eip}
  rightsubnet=${account.vpc_cidr}

%{ endfor ~}
EOF

cat > /etc/strongswan/ipsec.secrets << EOF
%{ for name, account in target_accounts ~}
${corp_eip} ${account.eip} : PSK "${account.psk}"
%{ endfor ~}
EOF

systemctl enable strongswan
systemctl start strongswan
