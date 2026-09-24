################
#  vpc/vpc.tf  #
################

resource "aws_vpc" "vpc" {
  cidr_block                       = var.cidr_block
  assign_generated_ipv6_cidr_block = true # IPv6 is mandatory for every VPC created by this module
  enable_dns_hostnames             = true
  enable_dns_support               = true
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

resource "aws_subnet" "public_subnet" {
  count                           = var.number_of_aws_az_use
  vpc_id                          = aws_vpc.vpc.id
  cidr_block                      = cidrsubnet(var.cidr_block, var.subnet_mask_bits, count.index) ## public subnets from 0 to 99
  ipv6_cidr_block                 = cidrsubnet(aws_vpc.vpc.ipv6_cidr_block, 8, count.index)       # IPv6 is mandatory for public subnets
  assign_ipv6_address_on_creation = true
  availability_zone               = element(data.aws_availability_zones.available.names, count.index)
  map_public_ip_on_launch         = true
  tags = {
    Name = "${var.name}-default-public-${element(data.aws_availability_zones.available.names, count.index)}"
  }
}

resource "aws_subnet" "private_subnet" {
  count                           = var.create_private_subnets ? var.number_of_aws_az_use : 0
  vpc_id                          = aws_vpc.vpc.id
  cidr_block                      = cidrsubnet(var.cidr_block, var.subnet_mask_bits, count.index + 100)
  ipv6_cidr_block                 = var.enable_private_subnet_ipv6 ? cidrsubnet(aws_vpc.vpc.ipv6_cidr_block, 8, count.index + 100) : null
  assign_ipv6_address_on_creation = var.enable_private_subnet_ipv6
  availability_zone               = element(data.aws_availability_zones.available.names, count.index)
  map_public_ip_on_launch         = false
  tags = {
    Name = "${var.name}-default-private-${element(data.aws_availability_zones.available.names, count.index)}"
  }
}

locals {
  nat_gateway_azs = var.nat_type == "gateway" ? slice(data.aws_availability_zones.available.names, 0, var.number_of_nat_gw) : []
}

# Egress Only Internet Gateway used for private subnets to access the internet via IPv6
resource "aws_egress_only_internet_gateway" "eigw" {
  count  = var.create_private_subnets && var.enable_private_subnet_ipv6 ? 1 : 0
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = "${var.name}-eigw"
  }
}

resource "aws_eip" "ngw_eip" {
  for_each = toset(local.nat_gateway_azs)
  domain   = "vpc"
  tags = {
    Name = "${var.name}-ngw-eip-${each.key}"
  }
}

# Regional NAT gateway in manual mode
resource "aws_nat_gateway" "ngw" {
  count             = var.nat_type == "gateway" ? 1 : 0
  vpc_id            = aws_vpc.vpc.id
  availability_mode = "regional"

  dynamic "availability_zone_address" {
    for_each = aws_eip.ngw_eip
    content {
      availability_zone = availability_zone_address.key
      allocation_ids    = [availability_zone_address.value.id]
    }
  }

  tags = {
    Name = "${var.name}-ngw"
  }
  depends_on = [
    aws_internet_gateway.igw
  ]
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
  destination_ipv6_cidr_block = "::/0"
  gateway_id                  = aws_internet_gateway.igw.id
  route_table_id              = aws_route_table.public_route_table.id
}

resource "aws_route_table_association" "public_route_table_assoc" {
  count          = var.number_of_aws_az_use
  subnet_id      = element(aws_subnet.public_subnet.*.id, count.index)
  route_table_id = element(aws_route_table.public_route_table.*.id, count.index)
  depends_on = [
    aws_route.igw_route
  ]
}

resource "aws_route_table" "private_route_table" {
  count  = var.create_private_subnets || length(var.nat_type) > 0 ? var.number_of_aws_az_use : 0
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = "${var.name}-private-${element(data.aws_availability_zones.available.names, count.index)}"
  }
}

resource "aws_route" "ngw_route" {
  count                  = length(var.nat_type) > 0 ? var.number_of_aws_az_use : 0
  destination_cidr_block = "0.0.0.0/0"
  network_interface_id   = var.nat_type == "instance" ? module.ec2_nat_instance.0.network_interface_id : null
  nat_gateway_id         = var.nat_type == "gateway" ? aws_nat_gateway.ngw[0].id : null
  route_table_id         = element(aws_route_table.private_route_table.*.id, count.index)
}

resource "aws_route" "eigw_route_ipv6" {
  count                       = var.create_private_subnets && var.enable_private_subnet_ipv6 ? var.number_of_aws_az_use : 0
  destination_ipv6_cidr_block = "::/0"
  egress_only_gateway_id      = aws_egress_only_internet_gateway.eigw[0].id
  route_table_id              = element(aws_route_table.private_route_table.*.id, count.index)
}

resource "aws_route_table_association" "private_route_table_assoc" {
  count          = var.create_private_subnets ? var.number_of_aws_az_use : 0
  subnet_id      = element(aws_subnet.private_subnet.*.id, count.index)
  route_table_id = element(aws_route_table.private_route_table.*.id, count.index)
}