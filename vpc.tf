################
#  vpc/vpc.tf  #
################

resource "aws_vpc" "vpc" {
  cidr_block                       = var.cidr_block
  enable_dns_hostnames             = true
  enable_dns_support               = true
  assign_generated_ipv6_cidr_block = var.enable_ipv6
  tags = {
    Name = var.name
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = var.name
  }
}

module "default_subnets" {
  source = "git::https://github.com/TechHoldingLLC/terraform-aws-subnet.git?ref=feat/modifying-subnets-attribute"

  name               = "${var.name}-default"
  vpc_id             = aws_vpc.vpc.id
  availability_zones = local.availability_zones

  private_subnets = local.default_private_cidr_blocks
  public_subnets  = local.default_public_cidr_blocks

  private_route_table_ids = aws_route_table.private_route_table.*.id
  public_route_table_ids  = [aws_route_table.public_route_table.id]

  enable_ipv6                                    = var.enable_ipv6
  assign_ipv6_address_on_creation                = var.enable_ipv6
  enable_dns64                                   = var.enable_ipv6
  enable_resource_name_dns_a_record_on_launch    = var.enable_ipv6
  enable_resource_name_dns_aaaa_record_on_launch = var.enable_ipv6
}

resource "aws_eip" "ngw_eip" {
  count  = var.nat_type == "gateway" ? var.number_of_nat_gw : 0
  domain = "vpc"
  tags = {
    Name = "${var.name}-ngw-eip-${element(data.aws_availability_zones.available.names, count.index)}"
  }
}

resource "aws_nat_gateway" "ngw" {
  count         = var.nat_type == "gateway" ? var.number_of_nat_gw : 0
  allocation_id = element(aws_eip.ngw_eip.*.id, count.index)
  subnet_id     = element(module.default_subnets.public_subnet_ids, count.index)
  tags = {
    Name = "${var.name}-ngw-${element(data.aws_availability_zones.available.names, count.index)}"
  }
}

resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = "${var.name}-public"
  }
}

resource "aws_route" "igw_route" {
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
  route_table_id         = aws_route_table.public_route_table.id
}

resource "aws_route" "igw_route_ipv6" {
  count                       = var.enable_ipv6 ? 1 : 0
  destination_ipv6_cidr_block = "::/0"
  gateway_id                  = aws_internet_gateway.igw.id
  route_table_id              = aws_route_table.public_route_table.id
}

resource "aws_route_table" "private_route_table" {
  count  = var.create_private_subnets || length(var.nat_type) > 0 ? var.number_of_aws_az_use : 0
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = "${var.name}-private-${element(data.aws_availability_zones.available.names, count.index)}"
  }
}

resource "aws_route" "ngw_route" {
  count                  = var.create_private_subnets || length(var.nat_type) > 0 ? var.number_of_aws_az_use : 0
  destination_cidr_block = "0.0.0.0/0"
  network_interface_id   = var.nat_type == "instance" ? module.ec2_nat_instance.0.network_interface_id : null
  nat_gateway_id         = var.nat_type == "gateway" ? element(aws_nat_gateway.ngw.*.id, var.number_of_nat_gw) : null
  route_table_id         = element(aws_route_table.private_route_table.*.id, count.index)
}

resource "aws_route" "ngw_route_ipv6" {
  count                       = var.enable_ipv6 && (var.create_private_subnets || length(var.nat_type) > 0) ? 1 : 0
  destination_ipv6_cidr_block = "64:ff9b::/96"
  network_interface_id        = var.nat_type == "instance" ? module.ec2_nat_instance.0.network_interface_id : null
  nat_gateway_id              = var.nat_type == "gateway" ? element(aws_nat_gateway.ngw.*.id, var.number_of_nat_gw) : null
  route_table_id              = element(aws_route_table.private_route_table.*.id, count.index)
}