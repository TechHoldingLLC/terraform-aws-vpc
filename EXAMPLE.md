# VPC
Below is an examples of calling this module.

## Create a Basic VPC with only Public Subnets
```
module "vpc" {
  source = "./vpc"
  name = "test-vpc"
  create_private_subnets = false
  cidr_block = "10.0.0.0/16"       # update the value according to the needs

  providers = {
    aws = aws
  }
}
```

## Create a VPC with Private Subnet and NAT Instance
```
module "vpc" {
  source = "./vpc"
  name = "test-vpc"
  cidr_block = "10.0.0.0/16"
  number_of_aws_az_use = 2
  create_private_subnets = true
  nat_type = "instance" 
  nat_instance_key_name = "test-vpc-nat-instance"
  nat_instance_sg_ingress = [
    {
      protocol    = -1
      from_port   = 0
      to_port     = 0
      cidr_blocks = ["10.0.0.0/16"]
    }
  ]
  nat_instance_sg_egress = [
    {
      protocol    = -1
      from_port   = 0
      to_port     = 0
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]
  nat_instance_iam_instance_profile = aws_iam_instance_profile.ec2.name
  
  providers = {
    aws = aws
  }
}
```


## Create a VPC with Private Subnet and NAT Gateway
```
module "vpc" {
  source = "./vpc"
  name = "test-vpc"
  cidr_block = "10.0.0.0/16"

  create_private_subnets = true
  nat_type = "gateway"

  providers = {
    aws = aws
  }
}
```

## Create a VPC with Flow logs
```
module "vpc" {
  source = "./vpc"
  name = "test-vpc"
  cidr_block = "10.0.0.0/16"

  create_private_subnets = true
  nat_type = "gateway"

  enable_flow_log = true

  providers = {
    aws = aws
  }
}
```

## Create a VPC with Gateway and Interface Endpoints
Service names are given as short names and expanded to `com.amazonaws.<region>.<name>`
using the region of the provider passed to the module.

Both kinds need private networking, so `create_private_subnets = true` is required.
Gateway endpoints attach to the private route tables; interface endpoints get an ENI in
every private subnet.

By default a security group allowing tcp/443 from the VPC CIDR is created for the
interface endpoints, and `private_dns_enabled` is turned on so the usual service
hostnames resolve to the endpoint.
```
module "vpc" {
  source = "./vpc"
  name = "test-vpc"
  cidr_block = "10.0.0.0/16"

  create_private_subnets = true
  nat_type = "gateway"

  gateway_endpoints   = ["s3", "dynamodb"]
  interface_endpoints = ["ecr.api", "ecr.dkr", "logs", "ssm", "ssmmessages", "ec2messages"]

  providers = {
    aws = aws
  }
}
```

## Endpoints with an existing Security Group and a restrictive S3 policy
Pass `interface_endpoint_security_group_ids` to reuse security groups instead of letting
the module create one. Endpoint policies are keyed by the same service name used in
`gateway_endpoints` / `interface_endpoints`; services left out keep AWS's default
full access policy.
```
module "vpc" {
  source = "./vpc"
  name = "test-vpc"
  cidr_block = "10.0.0.0/16"

  create_private_subnets = true
  nat_type = "gateway"

  gateway_endpoints = ["s3"]
  gateway_endpoint_policies = {
    s3 = data.aws_iam_policy_document.s3_endpoint.json
  }

  interface_endpoints                   = ["ecr.api", "ecr.dkr"]
  interface_endpoint_security_group_ids = [aws_security_group.endpoints.id]

  providers = {
    aws = aws
  }
}
```

## Isolated private subnets reached only through endpoints
Leaving `nat_type` unset gives private subnets with no default route at all — no NAT
gateway, no NAT instance, no path to the internet. Workloads there still reach the AWS
services you create endpoints for, and nothing else. This is the cheapest and tightest
shape the module builds, and the reason interface endpoints exist.
```
module "vpc" {
  source = "./vpc"
  name = "test-vpc"
  cidr_block = "10.0.0.0/16"

  create_private_subnets = true

  gateway_endpoints   = ["s3", "dynamodb"]
  interface_endpoints = ["ecr.api", "ecr.dkr", "logs", "sts", "ssm", "ssmmessages"]

  providers = {
    aws = aws
  }
}
```

