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

variable "enable_ipv6" {
  description = "Flag to enable/disable IPv6 configuration"
  type        = bool
  default     = false
}

variable "flow_log_retention_in_days" {
  description = "Flow logs retention in days"
  type        = number
  default     = 0
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