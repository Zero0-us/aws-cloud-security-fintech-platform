output "group_names" {
  value = {
    for key, group in aws_iam_group.this : key => group.name
  }
}

output "user_names" {
  value = keys(aws_iam_user.this)
}

output "user_arns" {
  value = {
    for key, user in aws_iam_user.this : key => user.arn
  }
}

output "mfa_policy_arn" {
  value = aws_iam_policy.mfa_required.arn
}
