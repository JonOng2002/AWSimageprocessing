variable "cidr_block" {
    description = "CIDR block for the VPC"
    type        = string
    default     = "10.28.0.0/16"
}

variable "vpc_azs" {
    description = "List of availability zones for the VPC"
    type        = list(string)
    default     = ["ap-southeast-1a", "ap-southeast-1b"]
}

variable "private_subnets" {
    description = "List of private subnet CIDR blocks"
    type        = list(string)
    default     = ["10.28.1.0/24", "10.28.2.0/24"]
}

variable "public_subnets" {
    description = "List of public subnet CIDR blocks"
    type        = list(string)
    default     = ["10.28.55.0/24", "10.28.56.0/24"]
}

variable "gem_service_ips" {
    description = "List of IP addresses for GEM services"
    type        = list(string)
    default     =  ["118.70.171.220/32", "14.177.235.12/32"]
}