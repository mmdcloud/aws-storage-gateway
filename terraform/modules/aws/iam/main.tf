# IAM Role
resource "aws_iam_role" "role" {
  name               = var.role_name
  description        = var.role_description != "" ? var.role_description : null
  assume_role_policy = var.assume_role_policy
  tags               = var.tags
}

# Custom Policy (only created if var.policy is provided and non-empty)
resource "aws_iam_policy" "policy" {
  count       = var.policy != null && var.policy != "" ? 1 : 0
  name        = var.policy_name
  description = var.policy_description != "" ? var.policy_description : null
  policy      = var.policy
  tags        = var.tags
}

# Custom Role-Policy Attachment (only attached if custom policy is created)
resource "aws_iam_role_policy_attachment" "role-policy-attachment" {
  count      = var.policy != null && var.policy != "" ? 1 : 0
  role       = aws_iam_role.role.name
  policy_arn = aws_iam_policy.policy[0].arn
}

# Managed Policy Attachments (if any ARNs provided)
resource "aws_iam_role_policy_attachment" "managed_policy_attachments" {
  for_each   = toset(var.managed_policy_arns)
  role       = aws_iam_role.role.name
  policy_arn = each.value
}
