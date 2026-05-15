$ErrorActionPreference = "Stop"
$region = "ap-northeast-2"
$secretName = "fin-prod-db-password-v2"
$dbPassword = aws secretsmanager get-secret-value --region $region --secret-id $secretName --query SecretString --output text
kubectl delete secret vuln-bank-secrets -n default --ignore-not-found
kubectl create secret generic vuln-bank-secrets -n default --from-literal=DB_USER=postgres --from-literal=DB_PASSWORD=$dbPassword
