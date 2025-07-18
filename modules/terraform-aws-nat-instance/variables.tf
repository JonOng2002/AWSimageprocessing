variable "enabled" {
  description = "Enable or not costly resources"
  type        = bool
  default     = true
}

variable "name" {
  description = "Name for all the resources as identifier"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "public_subnet" {
  description = "ID of the public subnet to place the NAT instance"
  type        = string
}

variable "private_subnets_cidr_blocks" {
  description = "List of CIDR blocks of the private subnets. The NAT instance accepts connections from this subnets"
  type        = list(string)
}

variable "private_route_table_ids" {
  description = "List of ID of the route tables for the private subnets. You can set this to assign the each default route to the NAT instance"
  type        = list(string)
  default     = []
}

variable "image_id" {
  description = "AMI of the NAT instance. Default to the latest Amazon Linux 2"
  type        = string
  default     = ""
}

variable "instance_types" {
  description = "Candidates of spot instance type for the NAT instance. This is used in the mixed instances policy"
  type        = list(string)
  default     = ["t4g.nano", "t3.nano", "t3a.nano"]
}

variable "use_spot_instance" {
  description = "Whether to use spot or on-demand EC2 instance"
  type        = bool
  default     = true
}

variable "key_name" {
  description = "Name of the key pair for the NAT instance. You can set this to assign the key pair to the NAT instance"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags applied to resources created with this module"
  type        = map(string)
  default     = {}
}

variable "user_data_write_files" {
  description = "Additional write_files section of cloud-init"
  type        = list(any)
  default     = []
}

variable "user_data_runcmd" {
  description = "Additional runcmd section of cloud-init"
  type        = list(list(string))
  default     = []
}

locals {
  // Merge the default tags and user-specified tags.
  // User-specified tags take precedence over the default.
  common_tags = merge(
    {
      Name = "${var.name}-nat-instance"
    },
    var.tags,
  )
}

variable "ssm_policy_arn" {
  description = "SSM Policy to be attached to instance profile"
  type        = string
  default     = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

variable "user_data" {
  description = "User data script to run on instance launch"
  type        = string
  default     = ""
}

variable "cloudwatch_agent_policy_arn" {
  description = "CloudWatch Agent Policy to be attached to instance profile"
  type        = string
  default     = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

variable "cloudwatch_agent_installation_user_data" {
  description = "User data script to install and configure the CloudWatch Agent on the NAT instance"
  default = <<-EOT
    #!/bin/bash
    # Install Cloudwatch Agent
    sudo yum update -y
    sudo yum install -y amazon-cloudwatch-agent
    sudo tee /opt/aws/amazon-cloudwatch-agent/bin/config.json > /dev/null << 'EOF'
    {
      "agent": {
        "run_as_user": "root"
      },
      "metrics": {
        "namespace": "AWS/EC2",
        "append_dimensions": {
          "AutoScalingGroupName": "$${aws:AutoScalingGroupName}"
        },
        "metrics_collected": {
          "mem": {
            "measurement": [
              {"name": "used_percent", "rename": "MemoryUtilization", "unit": "Percent"}
            ],
            "metrics_collection_interval": 60
          },
          "disk": {
            "measurement": [
              {"name": "used_percent", "rename": "DiskUtilization", "unit": "Percent"}
            ],
            "metrics_collection_interval": 60,
            "resources": [
              "/"
            ]
          }
        }
      }
    }
    EOF
    sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -c file:/opt/aws/amazon-cloudwatch-agent/bin/config.json -s
  EOT
}

variable "enable_cw_agent_monitoring" {
  type =  bool
  description = "Enable or disable CloudWatch monitoring for the bastion host"
  default = false
}