#########################
#  vpc/nat-instance.tf  #
#########################


data "aws_ami" "amazon_linux_nat_instance" {
  most_recent = true

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["amazon"] # Canonical
}

module "ec2_nat_instance" {
  count                   = var.nat_type == "instance" ? 1 : 0
  source                  = "git::https://github.com/TechHoldingLLC/terraform-aws-ec2.git?ref=feat/adding-ipv6-config"
  name                    = "${var.name}-nat-instance"
  ami_id                  = var.nat_instance_ami_id == "" ? data.aws_ami.amazon_linux_nat_instance.id : var.nat_instance_ami_id
  instance_type           = var.nat_instance_type
  subnet                  = element(aws_subnet.public_subnet.*.id, 1)
  vpc_id                  = aws_vpc.vpc.id
  eip                     = true
  source_dest_check       = false
  key_name                = var.nat_instance_key_name
  disable_api_termination = false
  ipv6_address_count      = var.enable_ipv6 ? 1 : 0

  user_data = <<END
#!/bin/bash
sudo echo "net.ipv4.ip_forward=1" > /etc/sysctl.conf
sudo sysctl -p
sudo /sbin/iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
sudo yum install -y iptables-services
sudo service iptables save
sudo chkconfig iptables on
sudo service iptables start
END

  security_group_ids = [module.nat_instance_sg.0.id]

  providers = {
    aws = aws
  }
}

module "nat_instance_sg" {
  count  = var.nat_type == "instance" ? 1 : 0
  source = "git::https://github.com/TechHoldingLLC/terraform-aws-security-group.git?ref=v0.0.1"
  name   = "${var.name}-nat-instance"
  vpc_id = aws_vpc.vpc.id
  egress = length(var.nat_instance_sg_egress) > 0 ? var.nat_instance_sg_egress : [
    {
      protocol    = -1
      from_port   = 0
      to_port     = 0
      cidr_blocks = ["0.0.0.0/0"]
    },
    {
      protocol    = -1
      from_port   = 0
      to_port     = 0
      ipv6_cidr_blocks = ["::/0"]
    }
  ]
  ingress = length(var.nat_instance_sg_ingress) > 0 ? var.nat_instance_sg_ingress : var.enable_ipv6 ? [
    {
      protocol    = -1
      from_port   = 0
      to_port     = 0
      cidr_blocks = [aws_vpc.vpc.cidr_block]
    },
    {
      protocol    = -1
      from_port   = 0
      to_port     = 0
      cidr_blocks = [aws_vpc.vpc.ipv6_cidr_block]
    }
  ] : [
    {
      protocol    = -1
      from_port   = 0
      to_port     = 0
      cidr_blocks = [aws_vpc.vpc.cidr_block]
    }
  ]
  providers = {
    aws = aws
  }
}