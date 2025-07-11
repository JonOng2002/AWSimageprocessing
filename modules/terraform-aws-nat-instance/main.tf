data "aws_ec2_instance_type" "this" {
  for_each      = toset(var.instance_types)
  instance_type = each.value
}

locals {
  instance_type_architectures    = { for f in var.instance_types : f => data.aws_ec2_instance_type.this[f].supported_architectures[0] }
  architectures                  = distinct([for k, v in local.instance_type_architectures : v])
  instance_type_launch_templates = { for f in var.instance_types : f => aws_launch_template.this[local.instance_type_architectures[f]].id }
}

resource "aws_security_group" "this" {
  name        = "${var.name}-nat-instance"
  vpc_id      = var.vpc_id
  description = "Security group for NAT instance ${var.name}"
  tags        = local.common_tags
}

resource "aws_security_group_rule" "egress" {
  security_group_id = aws_security_group.this.id
  type              = "egress"
  cidr_blocks       = ["0.0.0.0/0"]
  from_port         = 0
  to_port           = 65535
  protocol          = "tcp"
}

resource "aws_security_group_rule" "ingress_any" {
  security_group_id = aws_security_group.this.id
  type              = "ingress"
  cidr_blocks       = var.private_subnets_cidr_blocks
  from_port         = 0
  to_port           = 65535
  protocol          = "all"
}

resource "aws_network_interface" "this" {
  security_groups   = [aws_security_group.this.id]
  subnet_id         = var.public_subnet
  source_dest_check = false
  description       = "ENI for NAT instance ${var.name}"
  tags              = local.common_tags
}

resource "aws_route" "this" {
  count                  = length(var.private_route_table_ids)
  route_table_id         = var.private_route_table_ids[count.index]
  destination_cidr_block = "0.0.0.0/0"
  network_interface_id   = aws_network_interface.this.id
  lifecycle {
    ignore_changes = all
  }
}

# AMI of the latest Amazon Linux 2 
data "aws_ami" "this" {
  for_each = toset(local.architectures)

  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "architecture"
    values = [each.value]
  }
  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
  filter {
    name   = "name"
    values = ["al2023-ami-2*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_eip" "nat" {
  domain   = "vpc"
}

resource "aws_launch_template" "this" {
  for_each = toset(local.architectures)

  name     = "${var.name}-${each.value}-nat-instance"
  image_id = var.image_id != "" ? var.image_id : data.aws_ami.this[each.value].id
  key_name = var.key_name

  update_default_version = true

  iam_instance_profile {
    arn = aws_iam_instance_profile.this.arn
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.this.id]
    delete_on_termination       = true
  }

  tag_specifications {
    resource_type = "instance"
    tags          = local.common_tags
  }

  user_data = base64encode(join("\n", [
    templatefile("${path.module}/runonce.sh", {
      eip_id = aws_eip.nat.id,
      private_route_table_ids = var.private_route_table_ids
    }),
      var.enable_cw_agent_monitoring ? join("\n", [var.cloudwatch_agent_installation_user_data, var.user_data]) : var.user_data
  ]))


  description = "Launch template for NAT instance ${var.name}"
  tags        = local.common_tags
}

resource "aws_autoscaling_group" "this" {
  name                = "${var.name}-nat-instance"
  desired_capacity    = var.enabled ? 1 : 0
  min_size            = var.enabled ? 1 : 0
  max_size            = 1
  vpc_zone_identifier = [var.public_subnet]

  mixed_instances_policy {
    instances_distribution {
      on_demand_base_capacity                  = var.use_spot_instance ? 0 : 1
      on_demand_percentage_above_base_capacity = var.use_spot_instance ? 0 : 100
    }
    launch_template {
      launch_template_specification {
        launch_template_id = local.instance_type_launch_templates[var.instance_types[0]]
        version            = "$Latest"
      }
      dynamic "override" {
        for_each = var.instance_types
        content {
          instance_type = override.value
          launch_template_specification {
            launch_template_id = local.instance_type_launch_templates[override.value]
            version            = "$Latest"
          }
        }
      }
    }
  }

  dynamic "tag" {
    for_each = local.common_tags
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = false
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_iam_instance_profile" "this" {
  name = "${var.name}-nat-instance"
  role = aws_iam_role.this.name

  tags = local.common_tags
}

resource "aws_iam_role" "this" {
  name               = "${var.name}-nat-instance"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "ssm" {
  policy_arn = var.ssm_policy_arn
  role       = aws_iam_role.this.name
}

resource "aws_iam_role_policy" "eni" {
  role   = aws_iam_role.this.name
  name   = "${var.name}-nat-instance"
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ec2:AttachNetworkInterface",
                "ec2:ModifyInstanceAttribute",
                "ec2:AssociateAddress",
                "ec2:DescribeNetworkInterfaces",
                "ec2:ReplaceRoute"
            ],
            "Resource": "*"
        }
    ]
}
EOF
}

resource "aws_iam_role_policy" "ec2_describe_tags" {
  count  = var.enable_cw_agent_monitoring ? 1 : 0
  role   = aws_iam_role.this.name
  name   = "${var.name}-nat-describe-tags"
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ec2:DescribeTags",
                "ec2:DescribeInstances"
            ],
            "Resource": "*"
        }
    ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "cloudwatch_agent" {
  count      = var.enable_cw_agent_monitoring ? 1 : 0
  policy_arn = var.cloudwatch_agent_policy_arn
  role       = aws_iam_role.this.name
}


