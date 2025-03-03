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

