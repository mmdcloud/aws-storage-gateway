resource "aws_vpc_endpoint" "this" {
  vpc_id              = var.vpc_id
  service_name        = var.service_name
  vpc_endpoint_type   = var.vpc_endpoint_type
  auto_accept         = var.auto_accept
  policy              = var.policy
  private_dns_enabled = var.vpc_endpoint_type == "Interface" ? var.private_dns_enabled : null
  route_table_ids     = var.vpc_endpoint_type == "Gateway" ? var.route_table_ids : null
  subnet_ids          = var.vpc_endpoint_type == "Gateway" ? null : var.subnet_ids
  security_group_ids  = var.vpc_endpoint_type == "Gateway" ? null : var.security_group_ids

  tags = merge(
    {
      Name = var.name
    },
    var.tags
  )
}
