## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 4.5 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 4.5 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_ec2_nat_instance"></a> [ec2\_nat\_instance](#module\_ec2\_nat\_instance) | git::https://github.com/TechHoldingLLC/terraform-aws-ec2.git | v1.0.1 |
| <a name="module_nat_instance_sg"></a> [nat\_instance\_sg](#module\_nat\_instance\_sg) | git::https://github.com/TechHoldingLLC/terraform-aws-security-group.git | v0.0.1 |

## Resources

| Name | Type |
|------|------|
| [aws_cloudwatch_log_group.vpc_flow_log](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_eip.ngw_eip](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eip) | resource |
| [aws_flow_log.vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/flow_log) | resource |
| [aws_iam_role.vpc_flow_log](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.vpc_flow_log](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_internet_gateway.igw](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/internet_gateway) | resource |
| [aws_nat_gateway.ngw](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/nat_gateway) | resource |
| [aws_route.igw_route](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route) | resource |
| [aws_route.ngw_route](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route) | resource |
| [aws_route_table.private_route_table](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table) | resource |
| [aws_route_table.public_route_table](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table) | resource |
| [aws_route_table_association.private_route_table_assoc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association) | resource |
| [aws_route_table_association.public_route_table_assoc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association) | resource |
| [aws_subnet.private_subnet](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [aws_subnet.public_subnet](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [aws_vpc.vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc) | resource |
| [aws_ami.amazon_linux_nat_instance](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ami) | data source |
| [aws_availability_zones.available](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/availability_zones) | data source |
| [aws_iam_policy_document.vpc_flow_log](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.vpc_flow_log_trust_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cidr_block"></a> [cidr\_block](#input\_cidr\_block) | The CIDR block defining the private IP address space used | `string` | n/a | yes |
| <a name="input_create_private_subnets"></a> [create\_private\_subnets](#input\_create\_private\_subnets) | Create private subnets flag | `bool` | `false` | no |
| <a name="input_enable_flow_log"></a> [enable\_flow\_log](#input\_enable\_flow\_log) | Flag to enable/disable vpc flow log | `bool` | `false` | no |
| <a name="input_flow_log_retention_in_days"></a> [flow\_log\_retention\_in\_days](#input\_flow\_log\_retention\_in\_days) | Flow logs retention in days | `number` | `0` | no |
| <a name="input_name"></a> [name](#input\_name) | VPC name | `string` | n/a | yes |
| <a name="input_nat_instance_ami_id"></a> [nat\_instance\_ami\_id](#input\_nat\_instance\_ami\_id) | NAT instance AMI id | `string` | `""` | no |
| <a name="input_nat_instance_key_name"></a> [nat\_instance\_key\_name](#input\_nat\_instance\_key\_name) | NAT instance key pair name | `string` | `""` | no |
| <a name="input_nat_instance_sg_egress"></a> [nat\_instance\_sg\_egress](#input\_nat\_instance\_sg\_egress) | Egress for Nat instance Security Group | `list(any)` | `[]` | no |
| <a name="input_nat_instance_sg_ingress"></a> [nat\_instance\_sg\_ingress](#input\_nat\_instance\_sg\_ingress) | Ingress for Nat instance Security Group | `list(any)` | `[]` | no |
| <a name="input_nat_instance_type"></a> [nat\_instance\_type](#input\_nat\_instance\_type) | NAT instance type | `string` | `"t3.nano"` | no |
| <a name="input_nat_type"></a> [nat\_type](#input\_nat\_type) | NAT type i.e `instance` or `gateway` | `string` | `""` | no |
| <a name="input_number_of_aws_az_use"></a> [number\_of\_aws\_az\_use](#input\_number\_of\_aws\_az\_use) | How many aws avaibility zones use for deployment | `number` | `2` | no |
| <a name="input_number_of_nat_gw"></a> [number\_of\_nat\_gw](#input\_number\_of\_nat\_gw) | Number of nat gateway for private subnets | `number` | `1` | no |
| <a name="input_subnet_mask_bits"></a> [subnet\_mask\_bits](#input\_subnet\_mask\_bits) | Number of bits to use in CIDR subnet mask | `number` | `8` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_availability_zones"></a> [availability\_zones](#output\_availability\_zones) | n/a |
| <a name="output_cidr_block"></a> [cidr\_block](#output\_cidr\_block) | n/a |
| <a name="output_default_nacl_id"></a> [default\_nacl\_id](#output\_default\_nacl\_id) | n/a |
| <a name="output_default_route_table_id"></a> [default\_route\_table\_id](#output\_default\_route\_table\_id) | n/a |
| <a name="output_defaut_security_group_id"></a> [defaut\_security\_group\_id](#output\_defaut\_security\_group\_id) | n/a |
| <a name="output_id"></a> [id](#output\_id) | n/a |
| <a name="output_name"></a> [name](#output\_name) | n/a |
| <a name="output_nat_gateway_id"></a> [nat\_gateway\_id](#output\_nat\_gateway\_id) | n/a |
| <a name="output_nat_instance_ip"></a> [nat\_instance\_ip](#output\_nat\_instance\_ip) | n/a |
| <a name="output_nat_instance_security_group_ids"></a> [nat\_instance\_security\_group\_ids](#output\_nat\_instance\_security\_group\_ids) | n/a |
| <a name="output_private_route_table_ids"></a> [private\_route\_table\_ids](#output\_private\_route\_table\_ids) | n/a |
| <a name="output_private_subnet_ids"></a> [private\_subnet\_ids](#output\_private\_subnet\_ids) | n/a |
| <a name="output_private_subnets_availability_zone"></a> [private\_subnets\_availability\_zone](#output\_private\_subnets\_availability\_zone) | n/a |
| <a name="output_private_subnets_cidr"></a> [private\_subnets\_cidr](#output\_private\_subnets\_cidr) | n/a |
| <a name="output_public_route_table_ids"></a> [public\_route\_table\_ids](#output\_public\_route\_table\_ids) | n/a |
| <a name="output_public_subnet_availability_zones"></a> [public\_subnet\_availability\_zones](#output\_public\_subnet\_availability\_zones) | n/a |
| <a name="output_public_subnet_cidrs"></a> [public\_subnet\_cidrs](#output\_public\_subnet\_cidrs) | n/a |
| <a name="output_public_subnet_ids"></a> [public\_subnet\_ids](#output\_public\_subnet\_ids) | n/a |

## License

Apache 2 Licensed. See [LICENSE](https://github.com/TechHoldingLLC/terraform-aws-vpc/blob/main/LICENSE) for full details.