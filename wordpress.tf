# Generate random password for database
resource "random_password" "db_password" {
  length  = 16
  special = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# Launch Template for Auto Scaling
resource "aws_launch_template" "wordpress_template" {
  name_prefix   = "wordpress-template-${var.environment}-"
  image_id      = data.aws_ssm_parameter.al2023.value
  instance_type = "t3.micro"
  key_name      = aws_key_pair.generated_key.key_name
  
  vpc_security_group_ids = [aws_security_group.wordpress_sg.id]
  
  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "optional"
  }
  
  user_data = base64encode(templatefile(
    "user_data.sh", {
      DB_NAME = aws_db_instance.wordpress_db.db_name
      DB_USER = aws_db_instance.wordpress_db.username
      DB_PASSWORD = random_password.db_password.result
      DB_HOST = aws_db_instance.wordpress_db.endpoint
      EFS_ID = aws_efs_file_system.wordpress_efs.id
    }
  ))

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name        = "WordPress-ASG-${var.environment}"
      Environment = var.environment
      Terraform   = "true"
    }
  }
}

# Auto Scaling Group
resource "aws_autoscaling_group" "wordpress_asg" {
  name                = "wordpress-asg-${var.environment}"
  vpc_zone_identifier = [aws_subnet.privateSubnet.id, aws_subnet.privateSubnet2.id]
  target_group_arns   = [aws_lb_target_group.wordpress_tg.arn]
  health_check_type   = "ELB"
  health_check_grace_period = 300

  min_size         = 2
  max_size         = 4
  desired_capacity = 2

  launch_template {
    id      = aws_launch_template.wordpress_template.id
    version = "$Latest"
  }

  depends_on = [
    aws_db_instance.wordpress_db,
    time_sleep.wait_for_nat_gateway
  ]

  tag {
    key                 = "Name"
    value               = "WordPress-ASG-${var.environment}"
    propagate_at_launch = true
  }
  
  tag {
    key                 = "Environment"
    value               = var.environment
    propagate_at_launch = true
  }
}

# Auto Scaling Policies
resource "aws_autoscaling_policy" "scale_up" {
  name                   = "wordpress-scale-up-${var.environment}"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown              = 300
  autoscaling_group_name = aws_autoscaling_group.wordpress_asg.name
}

resource "aws_autoscaling_policy" "scale_down" {
  name                   = "wordpress-scale-down-${var.environment}"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown              = 300
  autoscaling_group_name = aws_autoscaling_group.wordpress_asg.name
}

# CloudWatch Alarms
resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "wordpress-cpu-high-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "70"
  alarm_description   = "This metric monitors ec2 cpu utilization"
  alarm_actions       = [aws_autoscaling_policy.scale_up.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.wordpress_asg.name
  }
}

resource "aws_cloudwatch_metric_alarm" "cpu_low" {
  alarm_name          = "wordpress-cpu-low-${var.environment}"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "30"
  alarm_description   = "This metric monitors ec2 cpu utilization"
  alarm_actions       = [aws_autoscaling_policy.scale_down.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.wordpress_asg.name
  }
}

# Create Application Load Balancer
resource "aws_lb" "wordpress_alb" {
  name               = "wordpress-alb-${var.environment}"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.publicSubnet.id, aws_subnet.publicSubnet2.id]

  tags = {
    Name        = "WordPress-ALB-${var.environment}"
    Environment = var.environment
    Terraform   = "true"
  }
}

# Create target group
resource "aws_lb_target_group" "wordpress_tg" {
  name     = "wordpress-tg-${var.environment}"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.myVPC.id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 10
    interval            = 30
    path                = "/health.html"
    matcher             = "200"
  }

  tags = {
    Name        = "WordPress-TG-${var.environment}"
    Environment = var.environment
    Terraform   = "true"
  }
}



# Create ALB listener
resource "aws_lb_listener" "wordpress_listener" {
  load_balancer_arn = aws_lb.wordpress_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.wordpress_tg.arn
  }
}