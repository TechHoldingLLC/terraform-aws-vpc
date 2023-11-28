################
#  vpc/vpc.tf  #
################

resource "aws_vpc" "vpc" {
  cidr_block           = var.cidr_block
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    Name = var.name
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = var.name
  }
  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_subnet" "public_subnet" {
  count                   = var.number_of_aws_az_use
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = cidrsubnet(var.cidr_block, var.subnet_mask_bits, count.index) ## public subnets from 0 to 99
  availability_zone       = element(data.aws_availability_zones.available.names, count.index)
  map_public_ip_on_launch = true
  tags = {
    Name = "${var.name}-default-public-${element(data.aws_availability_zones.available.names, count.index)}"
  }
}

resource "aws_subnet" "private_subnet" {
  count                   = var.create_private_subnets ? var.number_of_aws_az_use : 0
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = cidrsubnet(var.cidr_block, var.subnet_mask_bits, count.index + 100) ## private subnets start from 100
  availability_zone       = element(data.aws_availability_zones.available.names, count.index)
  map_public_ip_on_launch = false
  tags = {
    Name = "${var.name}-default-private-${element(data.aws_availability_zones.available.names, count.index)}"
  }
  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_eip" "ngw_eip" {
  count  = var.nat_type == "gateway" ? var.number_of_nat_gw : 0
  domain = "vpc"
  tags = {
    Name = "${var.name}-ngw-eip-${element(data.aws_availability_zones.available.names, count.index)}"
  }
  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_nat_gateway" "ngw" {
  count         = var.nat_type == "gateway" ? var.number_of_nat_gw : 0
  allocation_id = element(aws_eip.ngw_eip.*.id, count.index)
  subnet_id     = element(aws_subnet.public_subnet.*.id, count.index)
  tags = {
    Name = "${var.name}-ngw-${element(data.aws_availability_zones.available.names, count.index)}"
  }
  lifecycle {
    prevent_destroy = true
  }
  depends_on = [
    aws_route_table_association.public_route_table_assoc
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
  lifecycle {
    prevent_destroy = true
  }
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
  count                  = var.create_private_subnets || length(var.nat_type) > 0 ? var.number_of_aws_az_use : 0
  destination_cidr_block = "0.0.0.0/0"
  network_interface_id   = var.nat_type == "instance" ? module.ec2_nat_instance.0.network_interface_id : null
  nat_gateway_id         = var.nat_type == "gateway" ? element(aws_nat_gateway.ngw.*.id, var.number_of_nat_gw) : null
  route_table_id         = element(aws_route_table.private_route_table.*.id, count.index)
}

resource "aws_route_table_association" "private_route_table_assoc" {
  count          = var.create_private_subnets ? var.number_of_aws_az_use : 0
  subnet_id      = element(aws_subnet.private_subnet.*.id, count.index)
  route_table_id = element(aws_route_table.private_route_table.*.id, count.index)
}