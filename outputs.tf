####################
#  vpc/outputs.tf  #
####################

output "availability_zones" {
  value = slice(data.aws_availability_zones.available.names, 0, var.number_of_aws_az_use)
}

output "cidr_block" {
  value = aws_vpc.vpc.cidr_block
}

output "ipv6_cidr_block" {
  value = var.enable_ipv6 ? aws_vpc.vpc.ipv6_cidr_block : null
}

output "id" {
  value = aws_vpc.vpc.id
}

output "name" {
  value = aws_vpc.vpc.tags.Name
}

output "nat_instance_security_group_ids" {
  value = var.nat_type == "instance" ? module.nat_instance_sg.0.id : null
}

output "nat_instance_ip" {
  value = var.nat_type == "instance" ? module.ec2_nat_instance.0.public_ip : null
}

output "nat_gateway_id" {
  value = var.nat_type == "gateway" ? aws_nat_gateway.ngw.*.id : null
}

output "nat_gateway_private_ip" {
  value = var.nat_type == "gateway" ? aws_nat_gateway.ngw.*.private_ip : null
}

output "public_route_table_ids" {
  value = aws_route_table.public_route_table.*.id
}

output "default_public_subnet_ids" {
  value = module.default_subnets.public_subnet_ids
}

output "default_public_subnet_availability_zones" {
  value = module.default_subnets.public_subnet_availability_zones
}

output "default_public_subnet_cidr_blocks" {
  value = module.default_subnets.public_subnet_cidr_blocks
}

output "default_public_subnet_ipv6_cidr_blocks" {
  value = var.enable_ipv6 ? module.default_subnets.public_subnet_ipv6_cidr_blocks : null
}

output "default_private_subnet_ids" {
  value = var.create_private_subnets ? module.default_subnets.private_subnet_ids : null
}

output "private_route_table_ids" {
  value = aws_route_table.private_route_table.*.id
}

output "default_private_subnets_availability_zone" {
  value = var.create_private_subnets ? module.default_subnets.private_subnet_availability_zones : null
}

output "default_private_subnets_cidr" {
  value = var.create_private_subnets ? module.default_subnets.private_subnet_cidr_blocks : null
}

output "default_private_subnets_ipv6_cidrs" {
  value = var.enable_ipv6 && var.create_private_subnets ? module.default_subnets.private_subnet_ipv6_cidr_blocks : null
}