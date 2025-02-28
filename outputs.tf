####################
#  vpc/outputs.tf  #
####################

output "availability_zones" {
  value = slice(data.aws_availability_zones.available.names, 0, var.number_of_aws_az_use)
}

output "default_nacl_id" {
  value = aws_vpc.vpc.default_network_acl_id
}

output "default_route_table_id" {
  value = aws_vpc.vpc.default_route_table_id
}

output "default_security_group_id" {
  value = aws_vpc.vpc.default_security_group_id
}

output "cidr_block" {
  value = aws_vpc.vpc.cidr_block
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

output "public_route_table_ids" {
  value = aws_route_table.public_route_table.*.id
}

output "public_subnet_ids" {
  value = aws_subnet.public_subnet.*.id
}

output "public_subnet_availability_zones" {
  value = aws_subnet.public_subnet.*.availability_zone
}

output "public_subnet_cidrs" {
  value = aws_subnet.public_subnet.*.cidr_block
}

output "private_subnet_ids" {
  value = var.create_private_subnets ? aws_subnet.private_subnet.*.id : null
}

output "private_route_table_ids" {
  value = aws_route_table.private_route_table.*.id
}

output "private_subnets_availability_zone" {
  value = var.create_private_subnets ? aws_subnet.private_subnet.*.availability_zone : null
}

output "private_subnets_cidr" {
  value = var.create_private_subnets ? aws_subnet.private_subnet.*.cidr_block : null
}