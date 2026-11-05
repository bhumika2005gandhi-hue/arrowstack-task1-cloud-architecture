###############################################################################
# ASG module — app tier: launch template, auto scaling group, scaling policies,
# optional bastion host. EC2 user-data bootstraps Node.js app from S3.
###############################################################################

# ---------------- Security group for app instances ----------------
resource "aws_security_group" "app" {
  name        = "${var.name}-app-sg"
  description = "App tier — accepts traffic from ALB only"
  vpc_id      = var.vpc_id
  tags        = merge(var.tags, { Name = "${var.name}-app-sg" })
}

resource "aws_security_group_rule" "app_from_alb" {
  type                     = "ingress"
  from_port                = var.app_port
  to_port                  = var.app_port
  protocol                 = "tcp"
  source_security_group_id = var.alb_sg_id
  security_group_id        = aws_security_group.app.id
}

resource "aws_security_group_rule" "app_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.app.id
}

# ---------------- Launch template ----------------
resource "aws_launch_template" "app" {
  name                   = "${var.name}-lt"
  image_id               = var.ami_id
  instance_type          = var.instance_type
  key_name               = var.ssh_key_name
  vpc_security_group_ids = [aws_security_group.app.id]
  iam_instance_profile {
    name = var.iam_instance_profile
  }

  user_data = base64encode(templatefile("${path.module}/user-data.sh", {
    name          = var.name
    app_port      = var.app_port
    db_secret_arn = var.db_secret_arn
    db_endpoint   = var.db_endpoint
    db_name       = var.db_name
    log_bucket    = var.log_bucket
    s3_app_key    = "app/app.tar.gz"
  }))

  monitoring {
    enabled = true
  }

  tag_specifications {
    resource_type = "instance"
    tags          = merge(var.tags, { Name = "${var.name}-app", Tier = "app" })
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ---------------- Auto Scaling Group ----------------
resource "aws_autoscaling_group" "app" {
  name                = "${var.name}-asg"
  vpc_zone_identifier = var.private_subnets
  min_size            = var.min_size
  max_size            = var.max_size
  desired_capacity    = var.desired_capacity

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  target_group_arns = [var.target_group_arn]

  health_check_type         = "ELB"
  health_check_grace_period = 180

  termination_policies = ["OldestInstance", "ClosestToNextInstanceHour"]

  dynamic "tag" {
    for_each = merge(var.tags, { Name = "${var.name}-app-asg", Tier = "app" })
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ---------------- Target tracking — CPU utilisation ----------------
resource "aws_autoscaling_policy" "scale_up_cpu" {
  name                   = "${var.name}-cpu-scaleup"
  autoscaling_group_name = aws_autoscaling_group.app.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value     = 60.0
    disable_scale_in = false
  }
}

# ---------------- Target tracking — ALB request count per target ----------------
resource "aws_autoscaling_policy" "scale_up_requests" {
  name                   = "${var.name}-req-scaleup"
  autoscaling_group_name = aws_autoscaling_group.app.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    customized_metric_specification {
      metric_name = "RequestCountPerTarget"
      namespace   = "AWS/ApplicationELB"
      statistic   = "Sum"
      metric_dimension {
        name  = "LoadBalancer"
        value = var.alb_arn_suffix_for_metric
      }
      metric_dimension {
        name  = "TargetGroup"
        value = var.target_group_arn_suffix_for_metric
      }
    }
    target_value = 100.0
  }
}

# ---------------- Optional Bastion host ----------------
resource "aws_security_group" "bastion" {
  count       = var.enable_bastion ? 1 : 0
  name        = "${var.name}-bastion-sg"
  description = "Bastion SSH access"
  vpc_id      = var.vpc_id
  tags        = merge(var.tags, { Name = "${var.name}-bastion-sg" })
}

resource "aws_security_group_rule" "bastion_ssh" {
  count             = var.enable_bastion ? 1 : 0
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = var.allowed_bastion_cidr
  security_group_id = aws_security_group.bastion[0].id
}

resource "aws_security_group_rule" "bastion_egress" {
  count             = var.enable_bastion ? 1 : 0
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.bastion[0].id
}

resource "aws_instance" "bastion" {
  count                       = var.enable_bastion ? 1 : 0
  ami                         = var.ami_id
  instance_type               = "t3.micro"
  subnet_id                   = var.public_subnets[0]
  vpc_security_group_ids      = [aws_security_group.bastion[0].id]
  associate_public_ip_address = true
  key_name                    = var.ssh_key_name
  tags                        = merge(var.tags, { Name = "${var.name}-bastion", Tier = "bastion" })
}
