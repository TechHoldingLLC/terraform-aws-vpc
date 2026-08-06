#####################
#  vpc/provider.tf  #
#####################

terraform {
  # Needed for lifecycle condition defined in vpc_endpoints.tf
  required_version = ">= 1.2"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.5"
    }
  }
}