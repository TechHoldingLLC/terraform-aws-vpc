#################
#  vpc/data.tf  #
#################

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  availability_zones = data.aws_availability_zones.available.names

  default_public_cidr_blocks = var.enable_ipv6 ? flatten([
    for index in range(var.number_of_aws_az_use) : {
      cidr_block      = cidrsubnet(aws_vpc.vpc.cidr_block, var.subnet_mask_bits, index)
      ipv6_cidr_block = cidrsubnet(aws_vpc.vpc.ipv6_cidr_block, var.subnet_mask_bits, index)
    }
  ]) : flatten([
    for index in range(var.number_of_aws_az_use) : {
      cidr_block      = cidrsubnet(aws_vpc.vpc.cidr_block, var.subnet_mask_bits, index)
    }
  ])

  default_private_cidr_blocks = var.enable_ipv6 ? flatten([
    for index in range(var.number_of_aws_az_use) : {
      cidr_block      = cidrsubnet(aws_vpc.vpc.cidr_block, var.subnet_mask_bits, index + 100)
      ipv6_cidr_block = cidrsubnet(aws_vpc.vpc.ipv6_cidr_block, var.subnet_mask_bits, index + 100)
    }
  ]) : flatten([
    for index in range(var.number_of_aws_az_use) : {
      cidr_block      = cidrsubnet(aws_vpc.vpc.cidr_block, var.subnet_mask_bits, index + 100)
    }
  ])
}