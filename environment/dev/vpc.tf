module "vpc" {
  source = "../../modules/terraform-aws-vpc-master"

  name = "img-dev-vpc"
  cidr = var.cidr_block

  azs             = var.vpc_azs
  private_subnets = var.private_subnets
  public_subnets  = var.public_subnets

  enable_nat_gateway = false
  enable_vpn_gateway = false

  map_public_ip_on_launch = true



  tags = {
    Terraform = "true"
    Environment = "dev"
  }
}

resource "aws_security_group" "public_sg" {
    name        = "public_sg"
    description = "Security group for public access for alb"
    vpc_id      = module.vpc.vpc_id

    ingress {
      from_port = 80
      to_port   = 80
      protocol  = "tcp"
      cidr_blocks = ["0.0.0.0/0"] #Change this to CloudFront ip later when set up
    }
    ingress {
        from_port = 443
        to_port   = 443
        protocol  = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    ingress {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = var.gem_service_ips
    }
    egress {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }
    tags = {
        Name = "public_sg"
        Environment = "dev"
    }
}

resource "aws_security_group" "asg_api_and_fargate" {
    name        = "asg_api_and_fargate"
    description = "Security group for private access of ec2 and fargate asg"
    vpc_id      = module.vpc.vpc_id

    ingress {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = var.gem_service_ips # Change this to Bastion Host ip & Alb later
    }
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id = module.vpc.vpc_id
    service_name = "com.amazonaws.${data.aws_region.current.id}.s3"

    vpc_endpoint_type = "Gateway"

  tags = {
    Name        = "s3-endpoint"
    Environment = "dev"
  }
}

