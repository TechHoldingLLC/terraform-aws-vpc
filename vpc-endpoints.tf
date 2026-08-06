##########################
#  vpc/vpc-endpoints.tf  #
##########################

locals {
  endpoint_service_prefix = "com.amazonaws.${data.aws_region.current.name}"
  ## Splat instead of an index so this stays valid when the security group module is not created.
  interface_endpoint_security_group_ids = length(var.interface_endpoint_security_group_ids) > 0 ? var.interface_endpoint_security_group_ids : module.interface_endpoint_sg.*.id
}

resource "aws_vpc_endpoint" "gateway" {
  for_each          = toset(var.gateway_endpoints)
  vpc_id            = aws_vpc.vpc.id
  service_name      = "${local.endpoint_service_prefix}.${each.value}"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = aws_route_table.private_route_table.*.id
  policy            = lookup(var.gateway_endpoint_policies, each.key, null)

  lifecycle {
    ## Without private route tables the endpoint is created but nothing routes to it.
    ## Checked against the route tables themselves so this tracks their count expression.
    precondition {
      condition     = length(aws_route_table.private_route_table) > 0
      error_message = "gateway_endpoints needs private route tables to attach to. Set create_private_subnets = true, or set nat_type."
    }
  }
}

resource "aws_vpc_endpoint" "interface" {
  for_each            = toset(var.interface_endpoints)
  vpc_id              = aws_vpc.vpc.id
  service_name        = "${local.endpoint_service_prefix}.${each.value}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private_subnet.*.id
  security_group_ids  = local.interface_endpoint_security_group_ids
  private_dns_enabled = var.interface_endpoint_private_dns_enabled
  policy              = lookup(var.interface_endpoint_policies, each.key, null)

  lifecycle {
    precondition {
      condition     = var.create_private_subnets
      error_message = "interface_endpoints needs private subnets to put its ENIs in. Set create_private_subnets = true."
    }
  }
}

module "interface_endpoint_sg" {
  count  = length(var.interface_endpoints) > 0 && length(var.interface_endpoint_security_group_ids) == 0 ? 1 : 0
  source = "git::https://github.com/TechHoldingLLC/terraform-aws-security-group.git?ref=v0.0.1"
  name   = "${var.name}-vpc-endpoint"
  vpc_id = aws_vpc.vpc.id
  ingress = length(var.interface_endpoint_sg_ingress) > 0 ? var.interface_endpoint_sg_ingress : [
    {
      protocol    = "tcp"
      from_port   = 443
      to_port     = 443
      cidr_blocks = [aws_vpc.vpc.cidr_block]
    }
  ]
  egress = length(var.interface_endpoint_sg_egress) > 0 ? var.interface_endpoint_sg_egress : [
    {
      protocol    = -1
      from_port   = 0
      to_port     = 0
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]
  providers = {
    aws = aws
  }
}
