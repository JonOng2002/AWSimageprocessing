terraform {
  required_version = ">= 1.0.0" # Ensure that the Terraform version is 1.0.0 or higher

  required_providers {
    aws = {
      source = "hashicorp/aws" # Specify the source of the AWS provider
      version = "6.0.0"        # Use a version of the AWS provider that is compatible with version
    }
  }
}

provider "aws" {
  region = "ap-southeast-1"
  profile = "default" # Use the default AWS profile for authentication
  skip_metadata_api_check     = true  # Skip metadata API checks for faster execution

}

data "aws_region" "current" {
   region = "ap-southeast-1" # Specify the AWS region to use
}

data "aws_availability_zones" "available" {
    state = "available" # Fetch available availability zones in the specified region
}