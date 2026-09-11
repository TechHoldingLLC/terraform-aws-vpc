######################
#  vpc/variables.tf  #
######################

variable "create_private_subnets" {
  description = "Create private subnets flag"
  type        = bool
  default     = false
}

variable "cidr_block" {
  description = "The CIDR block defining the private IP address space used"
  type        = string
}

variable "enable_flow_log" {
  description = "Flag to enable/disable vpc flow log"
  type        = bool
  default     = false
}

variable "flow_log_retention_in_days" {
  description = "Flow logs retention in days"
  type        = number
  default     = 0
}

variable "gateway_endpoints" {
  description = "Gateway VPC endpoint service short names, expanded to `com.amazonaws.<region>.<name>` e.g. `[\"s3\", \"dynamodb\"]`. Attached to the private route tables, so `create_private_subnets` or `nat_type` must also be set for these to route anything"
  type        = list(string)
  default     = []
}

variable "gateway_endpoint_policies" {
  description = "Endpoint policy JSON per gateway endpoint, keyed by the same service name given in `gateway_endpoints` e.g. `{ s3 = data.aws_iam_policy_document.s3_endpoint.json }`. Services left out get AWS's default full access policy"
  type        = map(string)
  default     = {}
}

variable "interface_endpoints" {
  description = "Interface VPC endpoint service short names, expanded to `com.amazonaws.<region>.<name>` e.g. `[\"ecr.api\", \"ecr.dkr\", \"logs\", \"ssm\"]`. An ENI is created in each private subnet, so `create_private_subnets` must be true"
  type        = list(string)
  default     = []
}

variable "interface_endpoint_policies" {
  description = "Endpoint policy JSON per interface endpoint, keyed by the same service name given in `interface_endpoints`. Services left out get AWS's default full access policy"
  type        = map(string)
  default     = {}
}

variable "interface_endpoint_private_dns_enabled" {
  description = "Associate a private hosted zone with the VPC so the service's normal DNS name resolves to the interface endpoint, letting unmodified clients use it. Without this an endpoint is created but nothing routes to it. Set to false for the few services that do not support private DNS"
  type        = bool
  default     = true
}

variable "interface_endpoint_security_group_ids" {
  description = "Existing security group ids to attach to the interface endpoints. When empty, a security group is created for them"
  type        = list(string)
  default     = []
}

variable "interface_endpoint_sg_ingress" {
  description = "Ingress for the created interface endpoint Security Group. Defaults to tcp/443 from the VPC CIDR"
  type        = list(any)
  default     = []
}

variable "interface_endpoint_sg_egress" {
  description = "Egress for the created interface endpoint Security Group. Defaults to all traffic to 0.0.0.0/0"
  type        = list(any)
  default     = []
}

variable "name" {
  description = "VPC name"
  type        = string
}

variable "number_of_aws_az_use" {
  description = "How many aws avaibility zones use for deployment"
  type        = number
  default     = 2
}

variable "number_of_nat_gw" {
  description = "Number of nat gateway for private subnets"
  type        = number
  default     = 1
}

variable "nat_instance_type" {
  description = "NAT instance type"
  type        = string
  default     = "t3.nano"
}

variable "nat_instance_key_name" {
  description = "NAT instance key pair name"
  type        = string
  default     = ""
}

variable "nat_instance_ami_id" {
  description = "NAT instance AMI id"
  type        = string
  default     = ""
}

variable "nat_instance_sg_ingress" {
  description = "Ingress for Nat instance Security Group"
  type        = list(any)
  default     = []
}

variable "nat_instance_sg_egress" {
  description = "Egress for Nat instance Security Group"
  type        = list(any)
  default     = []
}

variable "nat_instance_iam_instance_profile" {
  description = "Name of the NAT instance's IAM instance profile"
  type        = string
  default     = null
}

variable "nat_type" {
  description = "NAT type i.e `instance` or `gateway`"
  type        = string
  default     = ""
}

variable "subnet_mask_bits" {
  description = "Number of bits to use in CIDR subnet mask"
  type        = number
  default     = 8
}