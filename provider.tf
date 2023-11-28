#####################
#  vpc/provider.tf  #
#####################

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.5"
    }
  }
}