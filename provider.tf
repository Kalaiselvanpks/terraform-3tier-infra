terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "3.50.0"
    }
  }
}

# Provider-1 for ap-south-1 (Default Provider)
provider "aws" {
  region = "ap-south-1"
  profile = "default"
}
